// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBotTokenFactory.sol";
import "@openzeppelin/contracts//utils/math/Math.sol";
import "./BotToken.sol";

contract BotTokenFactory is IBotTokenFactory, Ownable {
    address public magnetAI;

    event Initialized(address magnetAI);

    error Uninitialized();
    error NotMagnetAI(address caller, address magnetAI);
    error InvalidDecimals(uint256 decimals);
    error InvalidMaxSupply(uint256 maxSupply, uint256 minimum);
    error InvalidAuctionStartTime(uint256 inputTimestamp, uint256 currentTimestamp);
    error InvalidChatToEarnRatio(uint256 ratio);
    error InvalidAirdropPercentagePerRound(uint256 ratio);

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

    function initialize(address _magnetAI) external onlyOwner {
        magnetAI = _magnetAI;
        emit Initialized(_magnetAI);
    }

    function createToken(string[3] calldata stringData, uint256[6] calldata uintData, address bidTokenAddress)
        external
        onlyMagnetAI
        returns (address tokenAddress)
    {
        _checkUintDataOfBotToken(uintData[0], uintData[1], uintData[2], uintData[3], uintData[4]);
        BotToken botToken = new BotToken(
            stringData,
            uintData,
            _calculateBidIncrement(uintData[5]), // bidIncrement
            bidTokenAddress
        );
        tokenAddress = address(botToken);
    }

    function _checkUintDataOfBotToken(
        uint256 decimals,
        uint256 maxSupply,
        uint256 auctionStartTime,
        uint256 chatToEarnRatio,
        uint256 airdropPercentagePerRound
    ) internal view {
        if (decimals > 18) {
            revert InvalidDecimals(decimals);
        }
        // Check `maxSupply`: not allowed to be less than 100000.
        if (maxSupply < 100000) {
            revert InvalidMaxSupply(maxSupply, 100000);
        }
        // Check `auctionStartTime`: Not allow to be less than the current block timestamp.
        if (auctionStartTime < uint64(block.timestamp)) {
            revert InvalidAuctionStartTime(auctionStartTime, uint64(block.timestamp));
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

    function _calculateBidIncrement(uint256 pricePerThousandTokens) internal pure returns (uint256 bidIncrement) {
        // Check `pricePerThousandTokens`: not allowed to be between 1 to 9, inclusive.
        // When the bot token is "free", its `bidIncrement` will be specified with a constant value.
        if (pricePerThousandTokens < 10) {
            // Note the value of `bidIncrement` is undetermined currently. 1 is set only for the temporary test.
            bidIncrement = 1;
        } else {
            (, bidIncrement) = Math.tryDiv(pricePerThousandTokens, 10); // pricePerThousandTokens is floor-divided by 10
        }
    }
}
