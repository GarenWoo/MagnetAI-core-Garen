// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IOrderSystem.sol";

contract RevenueSharing {
    address public orderSystemAddr;
    mapping(uint256 subnetId => uint256 balance) public subnetOwnersReward;

    constructor(address _orderSystemAddr) {
        orderSystemAddr = _orderSystemAddr;
    }

    function submitServiceProof(uint256 botHandle, uint256 workload, uint256 callNumber) external {
        address orderSystemAddress = orderSystemAddr;
        IOrderSystem.Bot memory bot = IOrderSystem(orderSystemAddress).getBotInfo(botHandle);
        uint256 botPrice = bot.price;
        address botOwner = bot.owner;
        uint256 modelManagerId = bot.modelManagerId;
        IOrderSystem.ModelManager memory modelManager = IOrderSystem(orderSystemAddress).getModelManagerInfo(modelManagerId);
        uint256 modelId = modelManager.modelId;
        IOrderSystem.AIModel memory AIModel = IOrderSystem(orderSystemAddress).getModelInfo(modelId);
        uint256 modelPrice = AIModel.price;
        (bool networkReward_success, uint256 networkReward) = Math.tryMul(callNumber, modelPrice);
        if (!networkReward_success) {
            revert MathFailure();
        }
        (bool botReward_success, uint256 botReward) = Math.tryMul(callNumber, botPrice);
        if (!botReward_success) {
            revert MathFailure();
        }
        subnetOwnersReward[] += networkReward;
        emit ServiceProofSubmitted(botHandle, workload, callNumber);
    }
}