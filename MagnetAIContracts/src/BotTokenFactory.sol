// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {BotToken} from "./BotToken.sol";

/**
 * @title A factory contract that deploys the instances of the contract {BotToken} based on the logics in the token implementation contract.
 */
contract BotTokenFactory is Ownable {
    using Clones for address;

    // This is the address of the implement contract(template of ERC20Token contract)
    address public implementation;
    address public routerAddress;

    struct BotTokenStruct {
        string name;
        string symbol;
        uint256 maxSupply;
        uint256 perMint;
        uint256 mintFeeInETH;
    }

    mapping(address botTokenAddr => BotTokenStruct info) public botTokenInfo;
    uint256 private LPAmount_AddingLiquidity;       // the amount of LP token which come from adding liquidity only
    uint256 private profitOfMint;                   // the amount of ETH from the account which mints bot token
    uint256 private profitOfLP;                     // the amount of ETH from providing liquidity(the pair of the bot token and WETH)
    
    /**
     * @notice BotTokenContractsMax is a deterministic number that limits the maximum amount of bot token.
     * This parameter set a cap to avoid transaction failure which results from over-high gas.
     * This state variable can be modified by owner of this factory.
     */
    uint256 public BotTokenContractsMax = 10 ** 8;

    event BotTokenIssued(address indexed botTokenAddr);
    event BotTokenMinted(address indexed botTokenAddr, uint256 indexed mintedAmount, uint256 liquidityAdd);
    event LiquidityProfitWithdrawn(
        address indexed botTokenAddr, uint256 LPAmount, uint256 indexed tokenAmount, uint256 indexed ETHAmount
    );
    event MintingProfitWithdrawn(address owner, uint256 withdrawnAmount);

    error InsufficientETHGiven(address user, uint256 valueSent);
    error InvalidAmountMintedBack(address botTokenAddr, uint256 mintedAmount, uint256 expectedAmount);
    error ReachMaxSupply(address botTokenAddr, uint256 currentSupply, uint256 mintedAmount, uint256 maxSupply);
    error InsufficientProfitOfMint(uint256 balance, uint256 withdrawnAmount);

    constructor(address _implementation, address _routerAddress) Ownable(msg.sender) {
        implementation = _implementation;
        routerAddress = _routerAddress;
    }

    receive() external payable {
        if (msg.sender == routerAddress) {
            profitOfLP += msg.value;
        }
    }

    /**
     * @dev Using the implement contract of implementation, deploy its contract instance.
     *
     * @param _tokenName the name of the ERC20 token contract that will be deployed
     * @param _tokenSymbol the symbol of the ERC20 token contract that will be deployed
     * @param _tokenTotalSupply the maximum of the token supply(if this maximum is reached, token cannot been minted any more)
     * @param _perMint the fixed amount of token that can be minted once
     * @param _mintFeeInETH the fee count in ETH when minting bot token
     */
    function issueBotToken(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _tokenTotalSupply,
        uint256 _perMint,
        uint256 _mintFeeInETH
    ) public returns (address) {
        require(_tokenTotalSupply != 0 && _tokenTotalSupply % 2 == 0, "Total Supply should be an even non-zero number");
        require(_perMint != 0 && _perMint % 2 == 0, "Minted amount should be an even non-zero number");
        address clonedImpleInstance = implementation.clone();
        BotTokenStruct memory botTokenStruct = BotTokenStruct({
            name: _tokenName,
            symbol: _tokenSymbol,
            maxSupply: _tokenTotalSupply,
            perMint: _perMint,
            mintFeeInETH: _mintFeeInETH
        });
        botTokenInfo[clonedImpleInstance] = botTokenStruct;
        BotToken(clonedImpleInstance).init(address(this), _tokenName, _tokenSymbol);
        emit BotTokenIssued(clonedImpleInstance);
        return clonedImpleInstance;
    }

    /**
     * @dev Mint fixed amount of token in the contract of '_tokenAddr'.
     *
     * @param _tokenAddr the address of the contract instance which is cloned from the implement contract
     */
    function mintBotToken(address _tokenAddr) public payable {
        _beforeMintBotToken(_tokenAddr);
        uint256 halfMintedToken = botTokenInfo[_tokenAddr].perMint / 2;
        uint256 halfFee = msg.value / 2;
        uint256 balanceBefore = BotToken(_tokenAddr).balanceOf(address(this));
        BotToken(_tokenAddr).mint(address(this), halfMintedToken);
        BotToken(_tokenAddr).mint(msg.sender, halfMintedToken);
        uint256 balanceAfter = BotToken(_tokenAddr).balanceOf(address(this));
        if (balanceAfter <= balanceBefore || balanceAfter - balanceBefore != halfMintedToken) {
            uint256 balanceDelta = balanceAfter <= balanceBefore ? 0 : balanceAfter - balanceBefore;
            revert InvalidAmountMintedBack(_tokenAddr, balanceDelta, halfMintedToken);
        }
        // Approve DEX router
        bool isApproved = BotToken(_tokenAddr).approve(routerAddress, halfMintedToken);
        require(isApproved, "Fail to approve");
        // Add liquidity
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = UniswapV2Router02_Customized(
            payable(routerAddress)
        ).addLiquidityETH{value: halfFee}(_tokenAddr, halfMintedToken, 0, 0, address(this), block.timestamp + 600);
        uint256 tokenToBeRefunded = halfMintedToken - amountToken;
        if (tokenToBeRefunded > 0) {
            bool _ok = BotToken(_tokenAddr).transfer(msg.sender, halfMintedToken - amountToken);
            require(_ok, "Fail to refund bot token");
        }
        uint256 ETHToBeRefunded = halfFee - amountETH;
        if (ETHToBeRefunded > 0) {
            (bool _success,) = payable(msg.sender).call{value: halfFee - amountETH}("");
            require(_success, "Fail to refund ETH");
        }
        LPAmount_AddingLiquidity += liquidity;
        profitOfMint += halfFee;
        emit BotTokenMinted(_tokenAddr, botTokenInfo[_tokenAddr].perMint, liquidity);
    }

    /**
     * @dev Withdraw the profit from bot token minting
     */
    function withdrawProfitFromMinting(uint256 _amount) external onlyOwner {
        address owner = owner();
        if (_amount > address(this).balance) {
            revert InsufficientProfitOfMint(profitOfMint, _amount);
        }
        profitOfMint -= _amount;
        payable(owner).call{value: _amount}("");
        emit MintingProfitWithdrawn(owner, _amount);
    }

    /**
     * @dev Withdraw the profit from the earned LP tokens
     *
     * @param _tokenAddr the address of the specific bot token
     * @param _LPAmountWithdrawn the amount of the LP tokens which are used for the withdrawn
     * @param _tokenMin the minimum amount of the bot token withdrawn from the DEX
     * @param _ETHMin the minimum amount of ETH withdrawn from the DEX
     */
    function withdrawProfitFromLiquidity(
        address _tokenAddr,
        uint256 _LPAmountWithdrawn,
        uint256 _tokenMin,
        uint256 _ETHMin
    ) external onlyOwner returns (uint256 tokenAmount, uint256 ETHAmount) {
        address owner = owner();
        address pair = getPairAddress(_tokenAddr);
        bool isApproved = UniswapV2Pair_Customized(pair).approve(routerAddress, _LPAmountWithdrawn);
        require(isApproved, "Fail to approve router");
        (tokenAmount, ETHAmount) = UniswapV2Router02_Customized(payable(routerAddress)).withdrawProfitFromLiquidityETH(
            _tokenAddr, _LPAmountWithdrawn, _tokenMin, _ETHMin, address(this), block.timestamp + 600
        );
        bool _ok = BotToken(_tokenAddr).transfer(owner, tokenAmount);
        require(_ok, "Fail to withdraw token");
        (bool _success,) = payable(owner).call{value: ETHAmount}("");
        require(_success, "Fail to withdraw ETH");
        emit LiquidityProfitWithdrawn(_tokenAddr, _LPAmountWithdrawn, tokenAmount, ETHAmount);
    }

    /**
     * @dev Replace the address of the implement contract with a new one.
     * This function can only be called by the owner of this factory contract.
     */
    function setImplementation(address _implementation) public onlyOwner {
        implementation = _implementation;
    }

    /**
     * @dev Update the max amount of the bot token contract instances
     */
    function setBotTokenContractsMax(uint256 _newMaximum) external onlyOwner {
        BotTokenContractsMax = _newMaximum;
    }

    // ------------------------------------------------------ ** Functions with View-modifier ** ------------------------------------------------------

    /**
     * @notice This function is used to get the current total amount of minted token. It's for the convenience of knowing
     * if the current total amount has reached the maximum.
     *
     * @param _tokenAddr the address of the contract instance which is cloned from the implement contract
     */
    function getBotTokenCurrentSupply(address _tokenAddr) public view returns (uint256) {
        return BotToken(_tokenAddr).totalSupply();
    }

    /**
     * @dev Get the amount of LP token which come from adding liquidity only.(i.e. the LP token corresponding to the staked bot token and WETH in DEX)
     */
    function getLPTokenAmountOnlyAddingLiquidity() external view onlyOwner returns (uint256) {
        return LPAmount_AddingLiquidity;
    }

    /**
     * @dev Get the earned profit from providing liquidity.
     */
    function getLPProfitAmount(address _botTokenAddr) public view onlyOwner returns (uint256) {
        address pair = getPairAddress(_botTokenAddr);
        uint256 liquidityAdded = UniswapV2Pair_Customized(pair).estimateFee();
        return liquidityAdded;
    }

    function getPairAddress(address _botTokenAddr) public view returns (address) {
        address factory = UniswapV2Router02_Customized(payable(routerAddress)).factory();
        address WETHAddress = UniswapV2Router02_Customized(payable(routerAddress)).WETH();
        address pairAddress = UniswapV2Library_Customized.pairFor(factory, _botTokenAddr, WETHAddress);
        return pairAddress;
    }

    /**
     * @dev Get the current amount of profit(in ETH) from minting bot token.
     */
    function getProfitFromMinting() public view onlyOwner returns (uint256) {
        return profitOfMint;
    }

    /**
     * @dev Get the current amount of profit(in ETH) from minting bot token.
     */
    function getProfitFromProvidingLiquidity() public view onlyOwner returns (uint256) {
        return profitOfLP;
    }

    // ------------------------------------------------------ ** Internal Functions ** ------------------------------------------------------

    function _beforeMintBotToken(address _tokenAddr) internal view {
        uint256 currentTotalSupply = BotToken(_tokenAddr).totalSupply();
        uint256 amountPerMint = botTokenInfo[_tokenAddr].perMint;
        uint256 maxSupply = botTokenInfo[_tokenAddr].maxSupply;
        if (currentTotalSupply + amountPerMint > maxSupply) {
            revert ReachMaxSupply(_tokenAddr, currentTotalSupply, amountPerMint, maxSupply);
        }
        if (msg.value < botTokenInfo[_tokenAddr].mintFeeInETH) {
            revert InsufficientETHGiven(msg.sender, msg.value);
        }
    }
}
