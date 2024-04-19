// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract BotToken is ERC20, ERC20Permit, ReentrancyGuard, Initializable {
    using SafeERC20 for BotToken;
    using Address for address;

    address public factory;
    string private _name;
    string private _symbol;

    error NotFactory(address caller);
    error NoTokenReceived();
    error TransferTokenFail();
    error NotContract();

    event TokenMinted(address user, uint256 totalMinted);
    event TransferedWithCallback(address target, uint256 amount);
    event TransferedWithCallbackForNFT(address target, uint256 amount, bytes data);

    constructor() ERC20("Garen Fair Token", "GFT") ERC20Permit("Garen Fair Token") {
        factory = msg.sender;
    }

    modifier onlyFactory() {
        if (msg.sender != factory) {
            revert NotFactory(msg.sender);
        }
        _;
    }

    function init(
        address _factory,
        string calldata _initName,
        string calldata _initSymbol
    ) external initializer {
        factory = _factory;
        _name = _initName;
        _symbol = _initSymbol;
    }

    function mint(address _recipient, uint256 _amount) external onlyFactory {
        _mint(_recipient, _amount);
        emit TokenMinted(_recipient, _amount);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function getBytesOfNFTInfo(address _NFTAddr, uint256 _tokenId) public pure returns (bytes memory) {
        bytes memory NFTInfo = abi.encode(_NFTAddr, _tokenId);
        return NFTInfo;
    }
}
