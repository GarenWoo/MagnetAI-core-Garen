// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

/**
 * @title The interface of {BotTokenFactory}.
 */
interface IBotTokenFactory {
    // event(s)
    event Initialized(address magnetAI);
    // errors
    error Uninitialized();
    error FailToGetTokenDecimals(address paymentToken);
    error Reinitialization(address magnetAI);
    error NotMagnetAI(address caller, address magnetAI);
    error InvalidTokenName(string name);
    error InvalidTokenSymbol(string symbol);
    error InvalidMaxSupply(uint256 inputMaxSupply);
    error InvalidIssuanceStartTime(uint256 inputTimestamp, uint256 currentTimestamp);
    error InvalidDropTime(uint256 dropTime);
    error InvalidAirdropRatio(uint256 Percentage);

    function initialize(address _magnetAI) external;
    function createToken(
        string[3] calldata stringData,
        uint256[5] calldata uintData,
        address botOwner,
        address paymentToken
    ) external returns (address tokenAddress);
}
