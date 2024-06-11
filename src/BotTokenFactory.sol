// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBotTokenFactory.sol";
import "./BotToken.sol";

contract BotTokenFactory is IBotTokenFactory, Ownable {
    address public magnetAI;

    constructor() Ownable(msg.sender) {}

    modifier onlyMagnetAI() {
        if (magnetAI == address(0)) {
            revert Uninitialized();
        }
        if (msg.sender != magnetAI) {
            revert NotMagnetAI(msg.sender, magnetAI);
        }
        _;
    }

    modifier initializer() {
        if (magnetAI != address(0)) {
            revert Reinitialization(magnetAI);
        }
        _;
    }

    function initialize(address _magnetAI) external onlyOwner initializer {
        magnetAI = _magnetAI;
        emit Initialized(_magnetAI);
    }

    /**
     * @param stringData the array consist of the string parameters for {createToken}
     * @param uintData the array consist of the uint parameters for {createToken}
     * @param botOwner the address of the bot creator(i.e. the owner of the bot)
     * @param paymentToken the address of token which is used in bot token minting(address(0) means payment by ETH)
     *
     * @dev The specific values of the parameters `stringData` and `uintData` are shown as follows:
     * `stringData[0]` == `botHandle`;
     * `stringData[1]` == `name`;
     * `stringData[2]` == `symbol`;
     * `uintData[0]` == `maxSupply`;
     * `uintData[1]` == `issuanceStartTime`;
     * `uintData[2]` == `dropTime`;
     * `uintData[3]` == `airdropRatio`;
     * `uintData[4]` == `totalFund`;
     */
    function createToken(
        string[3] calldata stringData,
        uint256[5] calldata uintData,
        address botOwner,
        address paymentToken
    ) external onlyMagnetAI returns (address tokenAddress) {
        _checkStringData(stringData[1], stringData[2]);
        _checkUintData(uintData[0], uintData[1], uintData[2], uintData[3]);
        (uint256 pricePerKToken, uint256 mintPriceIncrement) = _calculateMintPriceAndIncrement(uintData[0], uintData[4], paymentToken);
        // `uintData[4]` is offered but useless to the constructor of the contract {BotToken}
        BotToken botToken = new BotToken(
            stringData,
            uintData,
            pricePerKToken,
            mintPriceIncrement,
            magnetAI,
            botOwner,
            paymentToken
        );
        tokenAddress = address(botToken);
    }

    function _checkStringData(string memory name, string memory symbol) private pure {
        bytes memory nameBytes = bytes(name);
        bytes memory symbolBytes = bytes(symbol);
        uint256 nameBytesLength = nameBytes.length;
        uint256 symbolBytesLength = symbolBytes.length;
        // Check string length
        if (!(nameBytesLength != 0 && nameBytesLength <= 32)) {
            revert InvalidTokenName(name);
        }
        if (!(nameBytesLength != 0 && nameBytesLength <= 10)) {
            revert InvalidTokenSymbol(symbol);
        }
        // Check character validity
        for (uint256 i = 0; i < nameBytesLength; i++) {
            bytes1 singleByte = nameBytes[i];
            if (
                !(
                    singleByte == " " || singleByte == "-" || singleByte == "."
                        || (singleByte >= "0" && singleByte <= "9") || (singleByte >= "A" && singleByte <= "Z")
                        || singleByte == "_" || (singleByte >= "a" && singleByte <= "z")
                )
            ) {
                revert InvalidTokenName(name);
            }
        }
        for (uint256 i = 0; i < symbolBytesLength; i++) {
            bytes1 singleByte = symbolBytes[i];
            if (
                !(
                    (singleByte >= "0" && singleByte <= "9") || (singleByte >= "A" && singleByte <= "Z")
                        || (singleByte >= "a" && singleByte <= "z")
                )
            ) {
                revert InvalidTokenSymbol(symbol);
            }
        }
    }

    function _checkUintData(uint256 maxSupply, uint256 issuanceStartTime, uint256 dropTime, uint256 airdropRatio)
        private
        view
    {
        // Check `maxSupply`: not allowed to be less than 100000.
        if (maxSupply == 0 || maxSupply % 100000 != 0) {
            revert InvalidMaxSupply(maxSupply, 100000);
        }
        // Check `issuanceStartTime`: No later than 1 year later
        if (issuanceStartTime > block.timestamp + 31536000) {
            revert InvalidIssuanceStartTime(issuanceStartTime, block.timestamp);
        }
        // Check `dropTime`(unit: days): range from 1 to 10000(inclusive)
        if (dropTime == 0 || dropTime > 1000) {
            revert InvalidDropTime(dropTime);
        }
        // Check `airdropRatio`: not allowed to exceed 99.
        if (airdropRatio > 99) {
            revert InvalidAirdropRatio(airdropRatio);
        }
    }

    function _calculateMintPriceAndIncrement(uint256 maxSupply, uint256 totalFund, address paymentToken)
        private
        view
        returns (uint256 pricePerKToken, uint256 mintPriceIncrement)
    {
        uint256 decimals;
        if (paymentToken == address(0)) {
            decimals = 18;
        } else {
            // Get ERC20 token decimals
            (bool success, bytes memory data) = paymentToken.staticcall(abi.encodeWithSelector(0x313ce567));
            if (!success) {
                revert FailToGetTokenDecimals(paymentToken);
            }
            decimals = abi.decode(data, (uint8));
        }
        // Calculate the price per 1000 tokens. The base price is 1(basic unit) token
        pricePerKToken = (totalFund + 1) * 1000 * 10 ** decimals / maxSupply;
        // Note the following value is set only for the temporary use.
        uint256 minPriceThousandTokens = 1 * 10 ** (decimals / 2);
        if (pricePerKToken < minPriceThousandTokens) {
            pricePerKToken = minPriceThousandTokens;
        }
        // `mintPriceIncrement` equals 1 when `totalFund` equals 0 and `minPriceThousandTokens` equals 1
        mintPriceIncrement = pricePerKToken < 10 ? 1 : pricePerKToken / 10;
    }
}
