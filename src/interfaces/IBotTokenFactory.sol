// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

/**
 * @title The interface of {BotTokenFactory}.
 */
interface IBotTokenFactory {
    event Initialized(address magnetAI);

    error Uninitialized();
    error Reinitialization(address magnetAI);
    error NotMagnetAI(address caller, address magnetAI);
    error InvalidMaxSupply(uint256 maxSupply, uint256 minimum);
    error InvalidIssuanceStartTime(uint256 inputTimestamp, uint256 currentTimestamp);
    error InvalidChatToEarnRatio(uint256 ratio);
    error InvalidAirdropPercentagePerRound(uint256 ratio);

    function initialize(address _magnetAI) external;
    function createToken(string[3] calldata stringData, uint256[5] calldata uintData, address botOwner, address paymentToken)
        external
        returns (address tokenAddress);
}
