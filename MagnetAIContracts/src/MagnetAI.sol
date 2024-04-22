// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IMagnetAI.sol";

contract MagnetAI is IMagnetAI, Ownable, ReentrancyGuard {
    uint256 private _modelIdNonce;
    uint256 private _subnetIdNounce;
    uint256 private _modelManagerIdNounce;
    // State Variables for Order System
    mapping(uint256 modelId => AIModel model) public models;
    mapping(uint256 subnetId => Subnet subnet) public subnets;
    mapping(uint256 modelManagerId => ModelManager modelManager) public modelManagers;
    mapping(uint256 botHandle => Bot bot) public bots;
    mapping(uint256 botHandle => bool isRegistered) public botHandleRegistry;
    mapping(address user => uint256 balanceAmount) public userBalance;
    // State Variables for Revenue Sharing
    mapping(uint256 botHandle => address tokenAddr) public issuance;
    mapping(address account => uint256 rewardAmount) public reward;
    mapping(uint256 botHandle => uint256 botRewardAmount) public botReward;
    
    constructor() Ownable(msg.sender) {}

    // receive() external payable {}

    modifier onlyModelOwner(uint256 modelId) {
        address modelOwner = models[modelId].owner;
        if (msg.sender != modelOwner) {
            revert NotModelOwner(msg.sender, modelOwner);
        }
        _;
    }

    modifier onlySubnetOwner(uint256 subnetId) {
        address subnetOwner = subnets[subnetId].owner;
        if (msg.sender != subnetOwner) {
            revert NotSubnetOwner(msg.sender, subnetOwner);
        }
        _;
    }

    modifier onlyModelManagerOwner(uint256 modelManagerId) {
        address modelManagerOwner = modelManagers[modelManagerId].owner;
        if (msg.sender != modelManagerOwner) {
            revert NotModelManagerOwner(msg.sender, modelManagerOwner);
        }
        _;
    }

    modifier onlyBotOwner(uint256 botHandle) {
        address botOwner = bots[botHandle].owner;
        if (msg.sender != botOwner) {
            revert NotBotOwner(msg.sender, botOwner);
        }
        _;
    }

// ———————————————————————————————————————— AI Model ————————————————————————————————————————
    function registerModel(string calldata _metadata, uint256 _price) external onlyOwner {
        AIModel memory model = AIModel({
            modelId: _modelIdNonce,
            owner: msg.sender,
            metadata: _metadata,
            price: _price
        });
        models[model.modelId] = model;
        _modelIdNonce++;
        emit ModelRegistered(model.modelId, model.owner);
    }

    function setModelPrice(uint256 _modelId, uint256 _price) external onlyModelOwner(_modelId) {
        _checkModelId(_modelId);
        models[_modelId].price = _price;
        emit ModelPriceModified(_modelId, _price);
    }

    // function setModelOwner(uint256 _modelId, address _newOwner) public onlyOwner returns (bool) {
    //     models[_modelId].owner = _newOwner;
    //     return true;
    // }

    function getModelInfo(uint256 _modelId) public view returns (AIModel memory) {
        _checkModelId(_modelId);
        return models[_modelId];
    }

    function getModelPrice(uint256 _modelId) public view returns (uint256) {
        _checkModelId(_modelId);
        return models[_modelId].price;
    }

    function _checkModelId(uint256 _modelId) internal view {
        if (models[_modelId].owner == address(0)) {
            revert NonexistentModel(_modelId);
        }
    }

// ———————————————————————————————————————— Subnet ————————————————————————————————————————
    function registerSubnet() external onlyOwner {
        Subnet memory subnet = Subnet({
            subnetId: _subnetIdNounce,
            owner: msg.sender
        });
        subnets[subnet.subnetId] = subnet;
        _subnetIdNounce++;
        emit SubnetRegistered(subnet.subnetId, subnet.owner);
    }

    // function setSubnetOwner(uint256 _subnetId, address _newOwner) public onlyOwner returns (bool) {
    //     subnets[_subnetId].owner = _newOwner;
    //     return true;
    // }

    function getSubnetInfo(uint256 _subnetId) public view returns (Subnet memory) {
        _checkSubnetId(_subnetId);
        return subnets[_subnetId];
    }

    function getSubnetOwner(uint256 _subnetId) public view returns (address) {
        _checkSubnetId(_subnetId);
        return subnets[_subnetId].owner;
    }

    function _checkSubnetId(uint256 _subnetId) internal view {
        if (subnets[_subnetId].owner == address(0)) {
            revert NonexistentSubnet(_subnetId);
        }
    }

// ———————————————————————————————————————— Model Manager ————————————————————————————————————————
    function registerModelManager(uint256 _modelId, uint256 _subnetId, string calldata _url) external onlyOwner {
        _checkModelId(_modelId);
        _checkSubnetId(_subnetId);
        ModelManager memory modelManager = ModelManager({
            modelManagerId: _modelManagerIdNounce,
            subnetId: _subnetId,
            modelId: _modelId,
            owner: msg.sender,
            url: _url
        });
        modelManagers[modelManager.modelManagerId] = modelManager;
        _modelManagerIdNounce++;
        emit ModelManagerRegistered(modelManager.modelManagerId, modelManager.owner);
    }

    function setModelManagerUrl(uint256 _modelManagerId, string memory _newUrl) external onlyModelManagerOwner(_modelManagerId) {
        _checkModelManagerId(_modelManagerId);
        modelManagers[_modelManagerId].url = _newUrl;
        emit ModelManagerUrlModified(_modelManagerId, _newUrl);
    }

    // function setModelManagerOwner(uint256 _modelManagerId, address _newOwner) public onlyOwner returns (bool) {
    //     modelManagers[_modelManagerId].owner = _newOwner;
    //     return true;
    // }

    function submitServiceProof(uint256[] calldata _botHandleArray, uint256[] calldata _workloadArray, uint256[] calldata _callNumberArray) external {
        _checkServiceProof(_botHandleArray, _workloadArray, _callNumberArray);
        for (uint256 i = 0; i < _botHandleArray.length; i++) {
            _checkBotHandle(_botHandleArray[i]);
            _handleReward(i, _botHandleArray[i], _callNumberArray[i]);
        }
        // emit ServiceProofSubmitted(_botHandleArray, _workloadArray, _callNumberArray);
    }

    function getModelManagerInfo(uint256 _modelManagerId) public view returns (ModelManager memory) {
        _checkModelManagerId(_modelManagerId);
        return modelManagers[_modelManagerId];
    }

    function getSubnetIdByModelManager(uint256 _modelManagerId) public view returns (uint256) {
        return modelManagers[_modelManagerId].subnetId;
    }

    function getModelIdByModelManager(uint256 _modelManagerId) public view returns (uint256) {
        return modelManagers[_modelManagerId].modelId;
    }

    function _checkModelManagerId(uint256 _modelManagerId) internal view {
        if (modelManagers[_modelManagerId].owner == address(0)) {
            revert NonexistentModelManager(_modelManagerId);
        }
    }

    function _checkServiceProof(uint256[] memory _botHandle, uint256[] memory _workload, uint256[] memory _callNumber) internal pure {
        uint256 proofAmountMax = 100;
        if (_botHandle.length != _workload.length || _botHandle.length != _callNumber.length) {
            revert UnmatchedProof(_botHandle.length, _workload.length, _callNumber.length);
        }
        if (_botHandle.length > proofAmountMax) {
            revert ExceedProofMaxAmount(_botHandle.length, proofAmountMax);
        }
    }

    function _handleReward(uint256 _index, uint256 _botHandle, uint256 _callNumber) internal {
        address botOwner = getBotOwner(_botHandle);
        uint256 modelManagerId = getModelManagerByBotHandle(_botHandle);
        uint256 modelId = getModelIdByModelManager(modelManagerId);
        address subnetOwner = getSubnetOwner(getSubnetIdByModelManager(modelManagerId));
        (bool networkReward_success, uint256 networkFee) = Math.tryMul(_callNumber, getModelPrice(modelId));
        if (!networkReward_success) {
            revert RewardCalculationFailed(_index);
        }
        (bool botReward_success, uint256 botFee) = Math.tryMul(_callNumber, getBotPrice(_botHandle));
        if (!botReward_success) {
            revert RewardCalculationFailed(_index);
        }
        reward[subnetOwner] += networkFee;
        issuance[_botHandle] == address(0) ? reward[botOwner] += botFee : botReward[_botHandle] += botFee;
    }

// ———————————————————————————————————————— Bot ————————————————————————————————————————
    function createBot(uint256 _botHandle, uint256 _modelManagerId, string memory _metadata, uint256 _price) public nonReentrant {
        if (botHandleRegistry[_botHandle]) {
            revert BotHandleHasExisted(_botHandle);
        }
        _checkModelManagerId(_modelManagerId);
        Bot memory bot = Bot({
            botHandle: _botHandle,
            modelManagerId: _modelManagerId,
            owner: msg.sender,
            metadata: _metadata,
            price: _price
        });
        bots[bot.botHandle] = bot;
        botHandleRegistry[_botHandle] = true;
        emit BotCreated(bot.owner, bot.botHandle, bot.modelManagerId);
    }

    function setBotPrice(uint256 _botHandle, uint256 _price) external onlyBotOwner(_botHandle) {
        // No need to check the existence of `_botHandle` due to access control
        bots[_botHandle].price = _price;
        emit BotPriceModified(_botHandle, _price);
    }

    function followBot(uint256 _botHandle) external {
        _checkBotHandle(_botHandle);
        emit BotFollowed(_botHandle, msg.sender);
    }

    function payForBot(uint256 _botHandle) external payable {
        _checkBotHandle(_botHandle);
        userBalance[msg.sender] += msg.value;
        emit BotPayment(msg.sender, msg.value);
    }

    function getBotInfo(uint256 _botHandle) public view returns (Bot memory) {
        _checkBotHandle(_botHandle);
        return bots[_botHandle];
    }

    function getModelManagerByBotHandle(uint256 _botHandle) public view returns (uint256) {
        _checkBotHandle(_botHandle);
        return bots[_botHandle].modelManagerId;
    }

    function getBotOwner(uint256 _botHandle) public view returns (address) {
        _checkBotHandle(_botHandle);
        return bots[_botHandle].owner;
    }

    function getBotPrice(uint256 _botHandle) public view returns (uint256) {
        _checkBotHandle(_botHandle);
        return bots[_botHandle].price;
    }

    function _checkBotHandle(uint256 _botHandle) internal view {
        if (!botHandleRegistry[_botHandle]) {
            revert NonexistentBotHandle(_botHandle);
        }
    }

// ———————————————————————————————————————— General Business ————————————————————————————————————————
    function claimReward() public {
        uint256 rewardValue = reward[msg.sender];
        if (rewardValue == 0) {
            revert InsufficientReward(msg.sender);
        }
        reward[msg.sender] = 0;
        (bool claimSuccess,) = payable(msg.sender).call{value: rewardValue}("");
        if (!claimSuccess) {
            revert ETHTransferFailed(msg.sender, rewardValue);
        }
    }

    function updateUserBalance(address[] calldata _user, uint256[] calldata _balance) external onlyOwner {
        if (_user.length != _balance.length) {
            revert UnmatchedUserBalance(_user.length, _balance.length);
        }
        for (uint256 i = 0; i < _user.length; i++) {
            userBalance[_user[i]] = _balance[i];
        }
    }
    
}