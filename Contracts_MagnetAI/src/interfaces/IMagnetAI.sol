// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

/**
 * @title The interface of MagnetAI.
 */
interface IMagnetAI {
    struct AIModel {
        string modelHandle;
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
        string modelHandle;
        address owner;
        string url;
    }

    struct Bot {
        string botHandle;
        uint256 modelManagerId;
        address owner;
        string metadata;
        uint256 price;
    }

    struct BotUsage {
        uint256 workload;
        uint256 callNumber;
    }

    event ModelRegistered(string modelHandle, address owner, string metadata, uint256 price);
    event ModelPriceModified(string modelHandle, uint256 newPrice);
    event SubnetRegistered(uint256 subnetId, address owner);
    event ModelManagerRegistered(uint256 modelManagerId, uint256 subnetId, string modelHandle, address owner, string url);
    event ModelManagerUrlModified(uint256 modelManagerId, string url);
    event BotCreated(string botHandle, uint256 indexed modelManagerId, address owner, string metadata, uint256 price);
    event BotPriceModified(string botHandle, uint256 newPrice);
    event BotFollowed(string botHandle, address user);
    event BotPayment(address user, uint256 value);
    event RewardClaimed(address user, uint256 value);
    
    error NotModelOwner(address caller, address owner);
    error NotSubnetOwner(address caller, address owner);
    error NotModelManagerOwner(address caller, address owner);
    error NotBotOwner(address caller, address owner);
    error NonexistentModel(string modelHandle);
    error NonexistentSubnet(uint256 subnetId);
    error NonexistentModelManager(uint256 subnetId);
    error NonexistentBot(string botHandle);
    error ModelHandleHasExisted(string botHandle);
    error BotHandleHasExisted(string botHandle);
    error ExceedProofMaxAmount(uint256 inputAmount, uint256 maxAmount);
    error InvalidProof(uint256 botHandleAmount, uint256 workloadAmount, uint256 callNumberAmount, uint256 valueLength);
    error InvalidBotHandleOfProof(string botHandle, address validModelManagerOwner, address caller);
    error InsufficientReward(address claimant);
    error ETHTransferFailed(address claimant, uint256 value);
    error InvalidUpdateOfUserBalance(uint256 userAmount, uint256 balanceAmount);
    error invalidModelHandle();
    error invalidBotHandle();

// ———————————————————————————————————————— AI Model ————————————————————————————————————————
    function registerModel(string calldata modelHandle, string calldata metadata, uint256 price) external;

    function setModelPrice(string calldata modelHandle, uint256 price) external;

// ———————————————————————————————————————— Subnet ————————————————————————————————————————
    function registerSubnet() external;

    function getSubnetOwner(uint256 subnetId) external view returns (address);

// ———————————————————————————————————————— Model Manager ————————————————————————————————————————
    function registerModelManager(string calldata modelHandle, uint256 subnetId, string calldata url) external;

    function setModelManagerUrl(uint256 modelManagerId, string calldata newUrl) external;

    function submitServiceProof(uint256 modelManagerId, string[] calldata botHandleArray, uint256[] calldata workloadArray, uint256[] calldata callNumberArray, uint256[][] calldata value) external;

    function getSubnetIdByModelManager(uint256 modelManagerId) external view returns (uint256);

// ———————————————————————————————————————— Bot ————————————————————————————————————————
    function createBot(string calldata botHandle, uint256 modelManagerId, string calldata metadata, uint256 price) external;

    function setBotPrice(string calldata botHandle, uint256 price) external;

    function followBot(string calldata botHandle) external;

    function payForBot() external payable;

    function getBotOwner(string calldata botHandle) external view returns (address);

    function getModelManagerOwnerByBotHandle(string memory botHandle) external view returns (address);

// ———————————————————————————————————————— General Business ————————————————————————————————————————
    function claimReward() external;

    function updateUserBalance(address[] calldata user, uint256[] calldata balance) external;

}