// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IMagnetAI.sol";

// TODO: Consider the functionality of the bot deletion in the future.
contract MagnetAI is IMagnetAI, Ownable, ReentrancyGuard {
    uint256 private _modelIdNonce;
    uint256 private _subnetIdNounce;
    uint256 private _modelManagerIdNounce;
    // State Variables for Order System
    mapping(uint256 modelId => AIModel model) public models;
    mapping(uint256 subnetId => Subnet subnet) public subnets;
    mapping(uint256 modelManagerId => ModelManager modelManager) public modelManagers;
    mapping(string botHandle => Bot bot) public bots;
    mapping(address user => uint256 balanceAmount) public userBalance;
    // State Variables for Revenue Sharing
    mapping(string botHandle => address tokenAddr) public issuance;
    mapping(string botHandle => BotUsage usage) public botUsage;
    mapping(address account => uint256 rewardAmount) public reward;
    mapping(string botHandle => uint256 botRewardAmount) public botReward;

    constructor() Ownable(msg.sender) {}

    // receive() external payable {}

    modifier onlyModelOwner(uint256 modelId) {
        address modelOwner = models[modelId].owner;
        if (msg.sender != modelOwner) {
            revert NotModelOwner(msg.sender, modelOwner);
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
    function registerModel(string calldata metadata, uint256 price) external onlyOwner {
        AIModel memory model = AIModel({
            modelId: _modelIdNonce,
            owner: msg.sender,
            metadata: metadata,
            price: price
        });
        models[model.modelId] = model;
        _modelIdNonce++;
        emit ModelRegistered(model.modelId, model.owner);
    }

    function setModelPrice(uint256 modelId, uint256 price) external onlyModelOwner(modelId) {
        models[modelId].price = price;
        emit ModelPriceModified(modelId, price);
    }

    // function setModelOwner(uint256 modelId, address newOwner) external onlyOwner returns (bool) {
    //     models[modelId].owner = newOwner;
    //     return true;
    // }

    function getModelPrice(uint256 modelId) public view returns (uint256) {
        _checkModelId(modelId);
        return models[modelId].price;
    }

    function _checkModelId(uint256 modelId) internal view {
        if (models[modelId].owner == address(0)) {
            revert NonexistentModel(modelId);
        }
    }

    // ———————————————————————————————————————— Subnet ————————————————————————————————————————
    function registerSubnet() external onlyOwner {
        Subnet memory subnet = Subnet({subnetId: _subnetIdNounce, owner: msg.sender});
        subnets[subnet.subnetId] = subnet;
        _subnetIdNounce++;
        emit SubnetRegistered(subnet.subnetId, subnet.owner);
    }

    // function setSubnetOwner(uint256 subnetId, address newOwner) external onlyOwner returns (bool) {
    //     subnets[subnetId].owner = newOwner;
    //     return true;
    // }

    function getSubnetOwner(uint256 subnetId) public view returns (address) {
        _checkSubnetId(subnetId);
        return subnets[subnetId].owner;
    }

    function _checkSubnetId(uint256 subnetId) internal view {
        if (subnets[subnetId].owner == address(0)) {
            revert NonexistentSubnet(subnetId);
        }
    }

    // ———————————————————————————————————————— Model Manager ————————————————————————————————————————
    function registerModelManager(uint256 modelId, uint256 subnetId, string calldata url) external onlyOwner {
        _checkModelId(modelId);
        _checkSubnetId(subnetId);
        ModelManager memory modelManager = ModelManager({
            modelManagerId: _modelManagerIdNounce,
            subnetId: subnetId,
            modelId: modelId,
            owner: msg.sender,
            url: url
        });
        modelManagers[modelManager.modelManagerId] = modelManager;
        _modelManagerIdNounce++;
        emit ModelManagerRegistered(modelManager.modelManagerId, modelManager.owner);
    }

    function setModelManagerUrl(uint256 modelManagerId, string calldata newUrl)
        external
        onlyModelManagerOwner(modelManagerId)
    {
        modelManagers[modelManagerId].url = newUrl;
        emit ModelManagerUrlModified(modelManagerId, newUrl);
    }

    // function setModelManagerOwner(uint256 modelManagerId, address newOwner) external onlyOwner returns (bool) {
    //     modelManagers[modelManagerId].owner = newOwner;
    //     return true;
    // }

    function submitServiceProof(
        string[] calldata botHandleArray,
        uint256[] calldata workloadArray,
        uint256[] calldata callNumberArray,
        uint256[][] calldata value
    ) external {
        _checkServiceProof(botHandleArray, workloadArray, callNumberArray, value);
        for (uint256 i = 0; i < botHandleArray.length; i++) {
            string memory botHandle = botHandleArray[i];
            _checkBotHandle(botHandle);
            botUsage[botHandle].workload += workloadArray[i];
            botUsage[botHandle].callNumber += callNumberArray[i];
            address botOwner = getBotOwner(botHandle);
            uint256 modelManagerId = getModelManagerByBotHandle(botHandle);
            address subnetOwner = getSubnetOwner(getSubnetIdByModelManager(modelManagerId));
            reward[subnetOwner] += value[i][0];
            issuance[botHandle] == address(0) ? reward[botOwner] += value[i][1] : botReward[botHandle] += value[i][1];
        }
        // emit ServiceProofSubmitted(botHandleArray, workloadArray, callNumberArray);
    }

    function getSubnetIdByModelManager(uint256 modelManagerId) public view returns (uint256) {
        return modelManagers[modelManagerId].subnetId;
    }

    function getModelIdByModelManager(uint256 modelManagerId) public view returns (uint256) {
        return modelManagers[modelManagerId].modelId;
    }

    function _checkModelManagerId(uint256 modelManagerId) internal view {
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
        if (botHandleArray.length != workloadArray.length || botHandleArray.length != callNumberArray.length || botHandleArray.length != value.length) {
            revert UnmatchedProof(botHandleArray.length, workloadArray.length, callNumberArray.length, value.length);
        }
    }

    // ———————————————————————————————————————— Bot ————————————————————————————————————————
    function createBot(string calldata botHandle, uint256 modelManagerId, string calldata metadata, uint256 price)
        external
    {
        _isValidBotHandle(botHandle);
        _checkModelManagerId(modelManagerId);
        Bot memory bot = Bot({
            botHandle: botHandle,
            modelManagerId: modelManagerId,
            owner: msg.sender,
            metadata: metadata,
            price: price
        });
        bots[bot.botHandle] = bot;
        emit BotCreated(bot.owner, bot.botHandle, bot.modelManagerId);
    }

    function setBotPrice(string calldata botHandle, uint256 price) external onlyBotOwner(botHandle) {
        // No need to check the existence of `botHandle` due to access control
        bots[botHandle].price = price;
        emit BotPriceModified(botHandle, price);
    }

    function followBot(string calldata botHandle) external {
        _checkBotHandle(botHandle);
        emit BotFollowed(botHandle, msg.sender);
    }

    function payForBot() external payable {
        userBalance[msg.sender] += msg.value;
        emit BotPayment(msg.sender, msg.value);
    }

    function getModelManagerByBotHandle(string memory botHandle) public view returns (uint256) {
        _checkBotHandle(botHandle);
        return bots[botHandle].modelManagerId;
    }

    function getBotOwner(string memory botHandle) public view returns (address) {
        _checkBotHandle(botHandle);
        return bots[botHandle].owner;
    }

    function getBotPrice(string memory botHandle) public view returns (uint256) {
        _checkBotHandle(botHandle);
        return bots[botHandle].price;
    }

    function _checkBotHandle(string memory botHandle) internal view {
        if (bots[botHandle].owner == address(0)) {
            revert NonexistentBotHandle(botHandle);
        }
    }

    function _isValidBotHandle(string memory botHandle) internal view {
        if (bots[botHandle].owner != address(0)) {
            revert BotHandleHasExisted(botHandle);
        }
        bytes memory botHandle_Bytes = bytes(botHandle);
        uint256 botHandle_BytesLength = botHandle_Bytes.length;
        if (botHandle_BytesLength > 18) {
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
    }

    function updateUserBalance(address[] calldata user, uint256[] calldata balance) external onlyOwner {
        if (user.length != balance.length) {
            revert UnmatchedUserBalance(user.length, balance.length);
        }
        for (uint256 i = 0; i < user.length; i++) {
            userBalance[user[i]] = balance[i];
        }
    }
}
