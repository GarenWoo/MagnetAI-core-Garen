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

    event ModelRegistered(uint256 modelId, address account);
    event ModelPriceModified(uint256 modelId, uint256 newPrice);
    event SubnetRegistered(uint256 subnetId, address account);
    event ModelManagerRegistered(uint256 modelManagerId, address account);
    event ModelManagerUrlModified(uint256 modelManagerId, string url);
    event BotCreated(address account, string botHandle, uint256 modelManagerId);
    event BotPriceModified(string botHandle, uint256 newPrice);
    event BotFollowed(string botHandle, address user);
    event BotPayment(address user, uint256 value);
    event ServiceProofSubmitted(string[] botHandleArray, uint256[] workloadArray, uint256[] callNumberArray);
    
    error NotModelOwner(address caller, address owner);
    error NotSubnetOwner(address caller, address owner);
    error NotModelManagerOwner(address caller, address owner);
    error NotBotOwner(address caller, address owner);
    error NonexistentModel(uint256 modelId);
    error NonexistentSubnet(uint256 subnetId);
    error NonexistentModelManager(uint256 subnetId);
    error NonexistentBotHandle(string botHandle);
    error BotHandleHasExisted(string botHandle);
    error ExceedProofMaxAmount(uint256 inputAmount, uint256 maxAmount);
    error UnmatchedProof(uint256 botHandleAmount, uint256 workloadAmount, uint256 callNumberAmount, uint256 valueLength);
    error InsufficientReward(address account);
    error ETHTransferFailed(address account, uint256 value);
    error UnmatchedUserBalance(uint256 userAmount, uint256 balanceAmount);
    error invalidBotHandle();

// ———————————————————————————————————————— AI Model ————————————————————————————————————————
    function registerModel(string calldata metadata, uint256 price) external;

    function setModelPrice(uint256 modelId, uint256 price) external;

    function getModelPrice(uint256 modelId) external view returns (uint256);

// ———————————————————————————————————————— Subnet ————————————————————————————————————————
    function registerSubnet() external;

    function getSubnetOwner(uint256 subnetId) external view returns (address);

// ———————————————————————————————————————— Model Manager ————————————————————————————————————————
    function registerModelManager(uint256 modelId, uint256 subnetId, string calldata url) external;

    function setModelManagerUrl(uint256 modelManagerId, string calldata newUrl) external;

    function submitServiceProof(string[] calldata botHandleArray, uint256[] calldata workloadArray, uint256[] calldata callNumberArray, uint256[][] calldata value) external;

    function getSubnetIdByModelManager(uint256 modelManagerId) external view returns (uint256);

    function getModelIdByModelManager(uint256 modelManagerId) external view returns (uint256);

// ———————————————————————————————————————— Bot ————————————————————————————————————————
    function createBot(string calldata botHandle, uint256 modelManagerId, string calldata metadata, uint256 price) external;

    function setBotPrice(string calldata botHandle, uint256 price) external;

    function followBot(string calldata botHandle) external;

    function payForBot() external payable;

    function getModelManagerByBotHandle(string calldata botHandle) external view returns (uint256);

    function getBotOwner(string calldata botHandle) external view returns (address);

    function getBotPrice(string calldata botHandle) external view returns (uint256);

// ———————————————————————————————————————— General Business ————————————————————————————————————————
    function claimReward() external;

    function updateUserBalance(address[] calldata user, uint256[] calldata balance) external;
    
}