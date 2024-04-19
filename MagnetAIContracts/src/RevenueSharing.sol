// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IMagnetAI.sol";

contract RevenueSharing {
    address public orderSystemAddr;
    mapping(address account => uint256 balance) public reward;
    mapping(uint256 botHandle => address tokenAddr) public issuance;
    event ServiceProofSubmitted(uint256[] botHandleArray, uint256[] workloadArray, uint256[] callNumberArray);

    error RewardCalculationFailed(uint256 indexOfArray);
    error ExceedProofMaxAmount(uint256 inputAmount, uint256 maxAmount);
    error InvalidProof(uint256 botHandleLength, uint256 workloadLength, uint256 callNumberLength);

    constructor(address _orderSystemAddr) {
        orderSystemAddr = _orderSystemAddr;
    }

    function submitServiceProof(uint256[] calldata _botHandleArray, uint256[] calldata _workloadArray, uint256[] calldata _callNumberArray) external {
        _checkServiceProof(_botHandleArray, _workloadArray, _callNumberArray);
        for (uint256 i = 0; i < _botHandleArray.length; i++) {
            address orderSystemAddress = orderSystemAddr;
            IMagnetAI.Bot memory bot = IMagnetAI(orderSystemAddress).getBotInfo(_botHandleArray[i]);
            uint256 botPrice = bot.price;
            address botOwner = bot.owner;
            uint256 modelManagerId = bot.modelManagerId;
            IMagnetAI.ModelManager memory modelManager = IMagnetAI(orderSystemAddress).getModelManagerInfo(modelManagerId);
            uint256 modelId = modelManager.modelId;
            IMagnetAI.AIModel memory AIModel = IMagnetAI(orderSystemAddress).getModelInfo(modelId);
            uint256 modelPrice = AIModel.price;
            (bool networkReward_success, uint256 networkReward) = Math.tryMul(_callNumberArray[i], modelPrice);
            if (!networkReward_success) {
                revert RewardCalculationFailed(i);
            }
            (bool botReward_success, uint256 botReward) = Math.tryMul(_callNumberArray[i], botPrice);
            if (!botReward_success) {
                revert RewardCalculationFailed(i);
            }
            reward[_botHandleArray[i]] += networkReward;
        }
        emit ServiceProofSubmitted(_botHandleArray, _workloadArray, _callNumberArray);
    }

    function checkIfBotTokenIssued(uint256 _botHandle) public view returns (bool) {
        return (issuance[_botHandle] != address(0));
    }

// --------------------------------------------------- Internal Functions 
    function _checkServiceProof(uint256[] memory _botHandle, uint256[] memory _workload, uint256[] memory _callNumber) internal {
        uint256 proofAmountMax = 100;
        if (_botHandle.length == _workload.length && _botHandle.length == _callNumber.length) {
            revert InvalidProof(_botHandle.length, _workload.length, _callNumber.length);
        }
        if (_botHandle.length > proofAmountMax) {
            revert ExceedProofMaxAmount(_botHandle.length, proofAmountMax);
        }
    }
}