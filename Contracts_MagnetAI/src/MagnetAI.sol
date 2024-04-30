// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IMagnetAI.sol";

// TODO: Consider the functionality of the bot deletion in the future.
contract MagnetAI is IMagnetAI, Ownable {
    uint256 private _subnetIdNounce;
    uint256 private _modelManagerIdNounce;
    // State Variables for Order System
    mapping(string modelHandle => AIModel model) public models;
    mapping(uint256 subnetId => Subnet subnet) public subnets;
    mapping(uint256 modelManagerId => ModelManager modelManager) public modelManagers;
    mapping(string botHandle => Bot bot) public bots;
    mapping(address user => uint256 balanceAmount) public userBalance;
    // State Variables for Revenue Sharing
    mapping(string botHandle => address tokenAddr) public issuance;
    mapping(string botHandle => BotUsage usage) public botUsage;
    mapping(address account => uint256 rewardAmount) public reward;
    mapping(string botHandle => uint256 botRewardAmount) public botReward;

    constructor() Ownable(msg.sender) {
        _subnetIdNounce = 1;
        _modelManagerIdNounce = 1;
    }

    // receive() external payable {}

    modifier onlyModelOwner(string calldata modelHandle) {
        address modelOwner = models[modelHandle].owner;
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

    modifier onlyBotOwner(string memory botHandle) {
        address botOwner = bots[botHandle].owner;
        if (msg.sender != botOwner) {
            revert NotBotOwner(msg.sender, botOwner);
        }
        _;
    }

    // ———————————————————————————————————————— AI Model ————————————————————————————————————————
    function registerModel(string calldata modelHandle, string calldata metadata, uint256 price) external onlyOwner {
        _isValidModelHandle(modelHandle);
        AIModel memory model = AIModel({
            modelHandle: modelHandle,
            owner: msg.sender,
            metadata: metadata,
            price: price
        });
        models[model.modelHandle] = model;
        emit ModelRegistered(model.modelHandle, model.owner, model.metadata, model.price);
    }

    function setModelPrice(string calldata modelHandle, uint256 price) external onlyModelOwner(modelHandle) {
        models[modelHandle].price = price;
        emit ModelPriceModified(modelHandle, price);
    }

    function _checkExistenceOfModel(string memory modelHandle) internal view {
        if (models[modelHandle].owner == address(0)) {
            revert NonexistentModel(modelHandle);
        }
    }
    
    function _isValidModelHandle(string memory modelHandle) internal view {
        if (models[modelHandle].owner != address(0)) {
            revert ModelHandleHasExisted(modelHandle);
        }
        bytes memory modelHandle_Bytes = bytes(modelHandle);
        uint256 modelHandle_BytesLength = modelHandle_Bytes.length;
        if (modelHandle_BytesLength > 64 || modelHandle_BytesLength == 0) {
            revert invalidModelHandle();
        }
    }

    // ———————————————————————————————————————— Subnet ————————————————————————————————————————
    function registerSubnet() external onlyOwner {
        Subnet memory subnet = Subnet({subnetId: _subnetIdNounce, owner: msg.sender});
        subnets[subnet.subnetId] = subnet;
        _subnetIdNounce++;
        emit SubnetRegistered(subnet.subnetId, subnet.owner);
    }

    function getSubnetOwner(uint256 subnetId) public view returns (address) {
        _checkExistenceOfSubnet(subnetId);
        return subnets[subnetId].owner;
    }

    function _checkExistenceOfSubnet(uint256 subnetId) internal view {
        if (subnets[subnetId].owner == address(0)) {
            revert NonexistentSubnet(subnetId);
        }
    }

    // ———————————————————————————————————————— Model Manager ————————————————————————————————————————
    function registerModelManager(string calldata modelHandle, uint256 subnetId, string calldata url) external onlySubnetOwner(subnetId) {
        _checkExistenceOfModel(modelHandle);
        ModelManager memory modelManager = ModelManager({
            modelManagerId: _modelManagerIdNounce,
            subnetId: subnetId,
            modelHandle: modelHandle,
            owner: msg.sender,
            url: url
        });
        modelManagers[modelManager.modelManagerId] = modelManager;
        _modelManagerIdNounce++;
        emit ModelManagerRegistered(modelManager.modelManagerId, modelManager.subnetId, modelManager.modelHandle, modelManager.owner, modelManager.url);
    }

    function setModelManagerUrl(uint256 modelManagerId, string calldata newUrl)
        external
        onlyModelManagerOwner(modelManagerId)
    {
        modelManagers[modelManagerId].url = newUrl;
        emit ModelManagerUrlModified(modelManagerId, newUrl);
    }

    function submitServiceProof(
        uint256 modelManagerId,
        string[] calldata botHandleArray,
        uint256[] calldata workloadArray,
        uint256[] calldata callNumberArray,
        uint256[][] calldata value
    ) external onlyModelManagerOwner(modelManagerId) {
        _checkServiceProof(botHandleArray, workloadArray, callNumberArray, value);
        for (uint256 i = 0; i < botHandleArray.length; i++) {
            string memory botHandle = botHandleArray[i];
            _checkProofSubmitter(botHandle);
            botUsage[botHandle].workload += workloadArray[i];
            botUsage[botHandle].callNumber += callNumberArray[i];
            address subnetOwner = getSubnetOwner(getSubnetIdByModelManager(modelManagerId));
            reward[subnetOwner] += value[i][0];
            issuance[botHandle] == address(0) ? reward[getBotOwner(botHandle)] += value[i][1] : botReward[botHandle] += value[i][1];
        }
    }

    function getSubnetIdByModelManager(uint256 modelManagerId) public view returns (uint256) {
        return modelManagers[modelManagerId].subnetId;
    }

    function _checkExistenceOfModelManager(uint256 modelManagerId) internal view {
        if (modelManagers[modelManagerId].owner == address(0)) {
            revert NonexistentModelManager(modelManagerId);
        }
    }

    function _checkServiceProof(
        string[] memory botHandleArray,
        uint256[] memory workloadArray,
        uint256[] memory callNumberArray,
        uint256[][] memory value
    ) internal pure {
        if (botHandleArray.length == 0 || botHandleArray.length != workloadArray.length || botHandleArray.length != callNumberArray.length || botHandleArray.length != value.length) {
            revert InvalidProof(botHandleArray.length, workloadArray.length, callNumberArray.length, value.length);
        }
    }

    function _checkProofSubmitter(string memory botHandle) internal view {
        address validModelManagerOwner = getModelManagerOwnerByBotHandle(botHandle);
        if (msg.sender != validModelManagerOwner) {
            revert InvalidBotHandleOfProof(botHandle, validModelManagerOwner, msg.sender);
        }
    }

    // ———————————————————————————————————————— Bot ————————————————————————————————————————
    function createBot(string calldata botHandle, uint256 modelManagerId, string calldata metadata, uint256 price)
        external
    {
        _isValidBotHandle(botHandle);
        _checkExistenceOfModelManager(modelManagerId);
        Bot memory bot = Bot({
            botHandle: botHandle,
            modelManagerId: modelManagerId,
            owner: msg.sender,
            metadata: metadata,
            price: price
        });
        bots[bot.botHandle] = bot;
        emit BotCreated(bot.botHandle, bot.modelManagerId, bot.owner, bot.metadata, bot.price);
    }

    function setBotPrice(string calldata botHandle, uint256 price) external onlyBotOwner(botHandle) {
        // No need to check the existence of `botHandle` due to access control
        bots[botHandle].price = price;
        emit BotPriceModified(botHandle, price);
    }

    function followBot(string calldata botHandle) external {
        _checkExistenceOfBot(botHandle);
        emit BotFollowed(botHandle, msg.sender);
    }

    function payForBot() external payable {
        userBalance[msg.sender] += msg.value;
        emit BotPayment(msg.sender, msg.value);
    }

    function getBotOwner(string memory botHandle) public view returns (address) {
        _checkExistenceOfBot(botHandle);
        return bots[botHandle].owner;
    }

    function getModelManagerOwnerByBotHandle(string memory botHandle) public view returns (address) {
        _checkExistenceOfBot(botHandle);
        uint256 modelManagerId = bots[botHandle].modelManagerId;
        ModelManager memory modelManager = modelManagers[modelManagerId];
        return modelManager.owner;
    }

    function _checkExistenceOfBot(string memory botHandle) internal view {
        if (bots[botHandle].owner == address(0)) {
            revert NonexistentBot(botHandle);
        }
    }

    function _isValidBotHandle(string memory botHandle) internal view {
        if (bots[botHandle].owner != address(0)) {
            revert BotHandleHasExisted(botHandle);
        }
        bytes memory botHandle_Bytes = bytes(botHandle);
        uint256 botHandle_BytesLength = botHandle_Bytes.length;
        if (botHandle_BytesLength > 32 || botHandle_BytesLength == 0) {
            revert invalidBotHandle();
        }
        for (uint256 i = 0; i < botHandle_BytesLength; i++) {
            bytes1 singleByte = botHandle_Bytes[i];
            if (
                !((singleByte >= "0" && singleByte <= "9") ||
                (singleByte >= "A" && singleByte <= "Z") ||
                singleByte == "_" ||
                (singleByte >= "a" && singleByte <= "z"))
            ) {
                revert invalidBotHandle();
            }
        }
    }

    // ———————————————————————————————————————— General Business ————————————————————————————————————————
    function claimReward() external {
        uint256 rewardValue = reward[msg.sender];
        if (rewardValue == 0) {
            revert InsufficientReward(msg.sender);
        }
        reward[msg.sender] = 0;
        (bool claimSuccess,) = payable(msg.sender).call{value: rewardValue}("");
        if (!claimSuccess) {
            revert ETHTransferFailed(msg.sender, rewardValue);
        }
        emit RewardClaimed(msg.sender, rewardValue);
    }

    function updateUserBalance(address[] calldata user, uint256[] calldata balance) external onlyOwner {
        if (user.length != balance.length) {
            revert InvalidUpdateOfUserBalance(user.length, balance.length);
        }
        for (uint256 i = 0; i < user.length; i++) {
            userBalance[user[i]] = balance[i];
        }
    }
}
