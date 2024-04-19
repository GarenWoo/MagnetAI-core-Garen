// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title The interface of MagnetAI.
 */
interface IMagnetAI {
    struct AIModel {
        uint256 modelId;
        address owner;
        string metadata;
        uint256 price;
    }

    struct Subnet {
        uint256 subnetId;
        address owner;
    }

    struct ModelManager {
        uint256 modelManagerId;
        uint256 subnetId;
        uint256 modelId;
        address owner;
        string url;
    }

    struct Bot {
        uint256 botHandle;
        uint256 modelManagerId;
        address owner;
        string metadata;
        uint256 price;
    }

    event ModelRegistered(uint256 modelId, address account);
    event ModelPriceModified(uint256 modelId, uint256 newPrice);
    event SubnetRegistered(uint256 subnetId, address account);
    event ModelManagerRegistered(uint256 modelManagerId, address account);
    event ModelManagerUrlModified(uint256 modelManagerId, string url);
    event BotCreated(address account, uint256 botHandle, uint256 modelManagerId);
    event BotPriceModified(uint256 botHandle, uint256 newPrice);
    event BotFollowed(uint256 botHandle, address user);
    event BotPayment(address user, uint256 value);
    event ServiceProofSubmitted(uint256[] botHandle, uint256[] workload, uint256[] callNumber);
    
    error NotModelOwner(address caller, address owner);
    error NotSubnetOwner(address caller, address owner);
    error NotModelManagerOwner(address caller, address owner);
    error NotBotOwner(address caller, address owner);
    error NonexistentModel(uint256 modelId);
    error NonexistentSubnet(uint256 subnetId);
    error NonexistentModelManager(uint256 subnetId);
    error NonexistentBotHandle(uint256 botHandle);
    error BotHandleHasExisted(uint256 botHandle);
    error RewardCalculationFailed(uint256 indexOfArray);
    error ExceedProofMaxAmount(uint256 inputAmount, uint256 maxAmount);
    error InvalidProof(uint256 botHandleLength, uint256 workloadLength, uint256 callNumberLength);

// ———————————————————————————————————————— AI Model ————————————————————————————————————————
    function registerModel(string calldata _metadata, uint256 _price) external;

    function setModelPrice(uint256 _modelId, uint256 _price) external;

    function getModelInfo(uint256 _modelId) external view returns (AIModel memory);

// ———————————————————————————————————————— Subnet ————————————————————————————————————————
    function registerSubnet() external;

    function getSubnetInfo(uint256 _subnetId) external view returns (Subnet memory);

// ———————————————————————————————————————— Model Manager ————————————————————————————————————————
    function registerModelManager(uint256 _modelId, uint256 _subnetId, string calldata _url) external;

    function setModelManagerUrl(uint256 _modelManagerId, string memory _newUrl) external;

    function getModelManagerInfo(uint256 _modelManagerId) external view returns (ModelManager memory);

// ———————————————————————————————————————— Bot ————————————————————————————————————————
    function createBot(uint256 _botHandle, uint256 _modelManagerId, string memory _metadata, uint256 _price) external;

    function setBotPrice(uint256 _botHandle, uint256 _price) external;

    function followBot(uint256 _botHandle) external;

    function payForBot(uint256 _botHandle) external payable;

    function getBotInfo(uint256 _botHandle) external view returns (Bot memory);
}