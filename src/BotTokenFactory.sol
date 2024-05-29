// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBotTokenFactory.sol";
import "@openzeppelin/contracts//utils/math/Math.sol";
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

    function createToken(string[3] calldata stringData, uint256[5] calldata uintData, address botOwner, address paymentToken)
        external
        onlyMagnetAI
        returns (address tokenAddress)
    {
        _checkUintDataOfBotToken(uintData[0], uintData[1], uintData[2], uintData[3]);
        BotToken botToken = new BotToken(
            stringData,
            uintData,
            _calculateMintPriceIncrement(uintData[4]), // mintPriceIncrement
            magnetAI,
            botOwner,
            paymentToken
        );
        tokenAddress = address(botToken);
    }

    function _checkUintDataOfBotToken(
        uint256 maxSupply,
        uint256 issuanceStartTime,
        uint256 chatToEarnRatio,
        uint256 airdropPercentagePerRound
    ) internal view {
        // Check `maxSupply`: not allowed to be less than 100000.
        if (maxSupply == 0 || maxSupply % 100000 != 0) {
            revert InvalidMaxSupply(maxSupply, 100000);
        }
        // Check `issuanceStartTime`: Not allow to be less than the current block timestamp.
        if (issuanceStartTime < uint64(block.timestamp)) {
            revert InvalidIssuanceStartTime(issuanceStartTime, uint64(block.timestamp));
        }
        // Check `chatToEarnRatio`: not allowed to exceed 99.
        if (chatToEarnRatio > 99) {
            revert InvalidChatToEarnRatio(chatToEarnRatio);
        }
        // Check `airdropPercentagePerRound`: not allowed to equal 0 or exceed 100.
        if (airdropPercentagePerRound == 0 || airdropPercentagePerRound > 100) {
            revert InvalidAirdropPercentagePerRound(airdropPercentagePerRound);
        }
    }

    function _calculateMintPriceIncrement(uint256 pricePerThousandTokens)
        internal
        pure
        returns (uint256 mintPriceIncrement)
    {
        // Check `pricePerThousandTokens`: not allowed to be between 1 to 9, inclusive.
        // When the bot token is "free", its `mintPriceIncrement` will be specified with a constant value.
        if (pricePerThousandTokens < 10) {
            // Note the value of `mintPriceIncrement` is undetermined currently. 1 is set only for the temporary test.
            mintPriceIncrement = 1;
        } else {
            (, mintPriceIncrement) = Math.tryDiv(pricePerThousandTokens, 10); // pricePerThousandTokens is floor-divided by 10
        }
    }
}
