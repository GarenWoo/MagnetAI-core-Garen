// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

/**
 * @title The interface of {BotTokenFactory}.
 */
interface IBotTokenFactory {
    function initialize(address _magnetAI) external;
    function createToken(string[3] calldata stringData, uint256[6] calldata uintData, address bidTokenAddress)
        external
        returns (address tokenAddress);
}
