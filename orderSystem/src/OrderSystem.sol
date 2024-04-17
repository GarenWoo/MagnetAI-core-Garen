// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IOrderSystem.sol";

contract OrderSystem is IOrderSystem, Ownable, ReentrancyGuard {
    uint256 private _modelIdNonce;
    uint256 private _subnetIdNounce;
    uint256 private _modelManagerIdNounce;

    mapping(uint256 modelId => AIModel model) public models;
    mapping(uint256 subnetId => Subnet subnet) public subnets;
    mapping(uint256 modelManagerId => ModelManager modelManager) public modelManagers;
    mapping(uint256 botHandle => Bot bot) public bots;
    mapping(uint256 botHandle => bool isRegistered) public botHandleRegistry;
    mapping(address user => uint256 balance) public usersBalance;

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
        models[_modelId].price = _price;
        emit ModelPriceModified(_modelId, _price);
    }

    // function setModelOwner(uint256 _modelId, address _newOwner) public onlyOwner returns (bool) {
    //     models[_modelId].owner = _newOwner;
    //     return true;
    // }

    function getModelInfo(uint256 _modelId) public view returns (AIModel memory) {
        return models[_modelId];
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
        return subnets[_subnetId];
    }

// ———————————————————————————————————————— Model Manager ————————————————————————————————————————
    function registerModelManager(uint256 _subnetId, uint256 _modelId, string calldata _url) external onlyOwner {
        if (subnets[_subnetId].owner == address(0)) {
            revert NonexistentSubnet(_subnetId);
        }
        if (models[_modelId].owner == address(0)) {
            revert NonexistentModel(_subnetId);
        }
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
        modelManagers[_modelManagerId].url = _newUrl;
        emit ModelManagerUrlModified(_modelManagerId, _newUrl);
    }

    // function setModelManagerOwner(uint256 _modelManagerId, address _newOwner) public onlyOwner returns (bool) {
    //     modelManagers[_modelManagerId].owner = _newOwner;
    //     return true;
    // }

    function getModelManagerInfo(uint256 _modelManagerId) public view returns (ModelManager memory) {
        return modelManagers[_modelManagerId];
    }

// ———————————————————————————————————————— Bot ————————————————————————————————————————
    function createBot(uint256 _botHandle, uint256 _modelManagerId, string memory _metadata, uint256 _price) public nonReentrant {
        if (botHandleRegistry[_botHandle]) {
            revert BotHandleHasExisted(_botHandle);
        }
        if (modelManagers[_modelManagerId].owner == address(0)) {
            revert NonexistentModelManager(_modelManagerId);
        }
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
        bots[_botHandle].price = _price;
        emit BotPriceModified(_botHandle, _price);
    }

    function followBot(uint256 _botHandle) external {
        emit BotFollowed(_botHandle, msg.sender);
    }

    function payForBot() external payable {
        usersBalance[msg.sender] += msg.value;
        emit BotPayment(msg.sender, msg.value);
    }

    function getBotInfo(uint256 _subnetId) public view returns (Bot memory) {
        return bots[_subnetId];
    }
}