// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

/**
 * @title The interface of {MagnetAI}.
 */
interface IMagnetAI {
    struct AIModel {
        string modelHandle;
        address owner;
        string metadata;
        uint256 price;
    }

    struct Subnet {
        string subnetHandle;
        address owner;
        string metadata;
    }

    struct ModelManager {
        string modelManagerId;
        string subnetHandle;
        string modelHandle;
        address owner;
        string url;
    }

    struct Bot {
        string botHandle;
        string modelManagerId;
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
    event SubnetRegistered(string subnetHandle, address owner, string metadata);
    event ModelManagerRegistered(string modelManagerId, string subnetHandle, string modelHandle, address owner, string url);
    event ModelManagerUrlModified(string modelManagerId, string url);
    event BotCreated(string botHandle, string modelManagerId, address owner, string metadata, uint256 price);
    event BotPriceModified(string botHandle, uint256 newPrice);
    event BotFollowed(string botHandle, address user);
    event BotPayment(address user, uint256 value);
    event RewardClaimed(address user, uint256 value);
    event SupportedTokenAdded(address tokenAddress);
    event SupportedTokenRemoved(address tokenAddress);
    event BotTokenCreated(string botHandle, address botTokenAddress);

    error NotModelOwner(address caller, address owner);
    error NotSubnetOwner(address caller, address owner);
    error NotModelManagerOwner(address caller, address owner);
    error NotBotOwner(address caller, address owner);
    error NonexistentModel(string modelHandle);
    error NonexistentModelManager(string modelManagerId);
    error NonexistentBot(string botHandle);
    error ModelHandleHasExisted(string modelHandle);
    error SubnetHandleHasExisted(string subnetHandle);
    error ModelManagerIdHasExisted(string modelManagerId);
    error BotHandleHasExisted(string botHandle);
    error InvalidProof(uint256 botHandleAmount, uint256 workloadAmount, uint256 callNumberAmount, uint256 valueLength);
    error InvalidBotHandleOfProof(string botHandle, address validModelManagerOwner, address caller);
    error InsufficientReward(address claimant);
    error ETHTransferFailed(address claimant, uint256 value);
    error InvalidUpdateOfUserData(uint256 userAmount, uint256 balanceAmount);
    error InvalidModelHandle();
    error InvalidSubnetHandle();
    error InvalidModelManagerId();
    error InvalidBotHandle();
    error ExcessiveBotPrice(uint256 botPrice, uint256 maxPrice);
    error TokenTransferFailed(uint256 amount);
    error InvalidPayment();
    error UnsupportedToken(address tokenAddress);
    error DuplicateTokenAdded(address tokenAddress, uint64 index);
    error NotAuthorizedBySubnet(address registrant, string modelHandle);
    error BotTokenHasCreated(string botHandle, address botTokenAddress);
    error NotAuthorizedByOwner(address caller);

// ———————————————————————————————————————— AI Model ————————————————————————————————————————
    function registerModel(string calldata modelHandle, string calldata metadata, uint256 price) external;

    function setModelPrice(string calldata modelHandle, uint256 price) external;

    function checkExistenceOfModel(string memory modelHandle) external view returns (bool);

    function checkModelHandleForRegistry(string memory modelHandle) external view returns (bool isAvailable, bool isValidInput);

// ———————————————————————————————————————— Subnet ————————————————————————————————————————
    function registerSubnet(string calldata subnetHandle, string calldata metadata) external;

    function authorizeModelManager(address registrant, string calldata subnetHandle) external;

    function checkExistenceOfSubnet(string memory subnetHandle) external view returns (bool);

    function checkSubnetHandleForRegistry(string memory subnetHandle) external view returns (bool isAvailable, bool isValidInput);

// ———————————————————————————————————————— Model Manager ————————————————————————————————————————
    function registerModelManager(string calldata modelManagerId, string calldata modelHandle, string calldata subnetHandle, string calldata url) external;

    function setModelManagerUrl(string calldata modelManagerId, string calldata newUrl) external;

    function submitServiceProof(string calldata modelManagerId, string[] calldata botHandleArray, uint256[] calldata workloadArray, uint256[] calldata callNumberArray, uint256[][] calldata value) external;

    function getModelManagerOwner(string calldata modelManagerId) external view returns (address);

    function checkExistenceOfModelManager(string memory modelManagerId) external view returns (bool);

    function checkModelManagerIdForRegistry(string memory modelManagerId) external view returns (bool isAvailable, bool isValidInput);

// ———————————————————————————————————————— Bot ————————————————————————————————————————
    function createBot(string calldata botHandle, string calldata modelManagerId, string calldata metadata, uint256 price) external;

    function setBotPrice(string calldata botHandle, uint256 price) external;

    function followBot(string calldata botHandle) external;

    function payForBot(uint256 amount) external;

    function createToken(string[3] calldata stringData, uint256[5] calldata uintData, address paymentToken) external;

    function getBotOwner(string memory botHandle) external view returns (address);

    function checkExistenceOfBot(string memory botHandle) external view returns (bool);

    function checkBotHandleForBotCreation(string memory botHandle) external view returns (bool isAvailable, bool isValidInput);

// ———————————————————————————————————————— General Business ————————————————————————————————————————
    function claimReward() external;

    function updateUserData(address[] calldata user, uint256[] calldata data) external;

    function manageReporter(address account, bool isAuthorized) external;

    function addSupportedToken(address addedToken) external;

    function removeSupportedToken(address removedToken) external;

    function checkSupportOfToken(address tokenAddress) external view returns (bool isSupported);
}