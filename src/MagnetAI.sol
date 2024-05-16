// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IMagnetAI.sol";
import "./interfaces/IBotTokenFactory.sol";

// TODO: Consider the functionality of the bot deletion in the future.
contract MagnetAI is IMagnetAI, Ownable {
    address public immutable botTokenFactory;
    // State Variables for Order System
    mapping(string modelHandle => AIModel model) public models;
    mapping(string subnetHandle => Subnet subnet) public subnets;
    mapping(string modelManagerId => ModelManager modelManager) public modelManagers;
    mapping(string botHandle => Bot bot) public bots;
    mapping(address user => uint256 balanceAmount) public userBalance;
    mapping(address registrant => mapping(string subnetHandle => bool isAuthorized)) public isAuthedModelManager;
    // State Variables for Revenue Sharing
    mapping(string botHandle => address tokenAddr) public createdBotTokens;
    mapping(string botHandle => BotUsage usage) public botUsage;
    mapping(address account => uint256 rewardAmount) public reward;
    mapping(string botHandle => uint256 botRewardAmount) public botReward;
    mapping(address tokenAddress => uint64 index) public indexOfSupportedToken;
    address[] public supportedTokens;
    mapping(address account => bool isAuthorized) public isReporter;

    constructor(address _botTokenFactory) Ownable(msg.sender) {
        supportedTokens.push(address(0));
        botTokenFactory = _botTokenFactory;
    }

    // receive() external payable {}

    modifier onlyModelOwner(string calldata modelHandle) {
        address modelOwner = models[modelHandle].owner;
        if (msg.sender != modelOwner) {
            revert NotModelOwner(msg.sender, modelOwner);
        }
        _;
    }

    modifier onlySubnetOwner(string calldata subnetHandle) {
        address subnetOwner = subnets[subnetHandle].owner;
        if (msg.sender != subnetOwner) {
            revert NotSubnetOwner(msg.sender, subnetOwner);
        }
        _;
    }

    modifier onlyModelManagerOwner(string calldata modelManagerId) {
        address modelManagerOwner = modelManagers[modelManagerId].owner;
        if (msg.sender != modelManagerOwner) {
            revert NotModelManagerOwner(msg.sender, modelManagerOwner);
        }
        _;
    }

    modifier onlyBotOwner(string calldata botHandle) {
        address botOwner = bots[botHandle].owner;
        if (msg.sender != botOwner) {
            revert NotBotOwner(msg.sender, botOwner);
        }
        _;
    }

    modifier authorizedBySubnet(string calldata subnetHandle) {
        if (!isAuthedModelManager[msg.sender][subnetHandle]) {
            revert NotAuthorizedBySubnet(msg.sender, subnetHandle);
        }
        _;
    }

    modifier authorizedByOwner() {
        if (isReporter[msg.sender] == false) {
            revert NotAuthorizedByOwner(msg.sender);
        }
        _;
    }

    // ———————————————————————————————————————— AI Model ————————————————————————————————————————
    function registerModel(string calldata modelHandle, string calldata metadata, uint256 price) external onlyOwner {
        (bool isAvailable, bool isValidInput) = checkModelHandleForRegistry(modelHandle);
        if (!isAvailable) {
            revert ModelHandleHasExisted(modelHandle);
        }
        if (!isValidInput) {
            revert InvalidModelHandle();
        }
        AIModel memory model = AIModel({modelHandle: modelHandle, owner: msg.sender, metadata: metadata, price: price});
        models[model.modelHandle] = model;
        emit ModelRegistered(model.modelHandle, model.owner, model.metadata, model.price);
    }

    function setModelPrice(string calldata modelHandle, uint256 price) external onlyModelOwner(modelHandle) {
        // No need to check the existence of `modelHandle` due to the access control {onlyModelOwner}
        models[modelHandle].price = price;
        emit ModelPriceModified(modelHandle, price);
    }

    function checkExistenceOfModel(string memory modelHandle) public view returns (bool) {
        return models[modelHandle].owner != address(0);
    }

    function checkModelHandleForRegistry(string memory modelHandle)
        public
        view
        returns (bool isAvailable, bool isValidInput)
    {
        isAvailable = models[modelHandle].owner == address(0);
        bytes memory modelHandleBytes = bytes(modelHandle);
        uint256 modelHandleBytesLength = modelHandleBytes.length;
        isValidInput = modelHandleBytesLength != 0 && modelHandleBytesLength <= 64;
    }

    function _checkExistenceOfModel(string memory modelHandle) internal view {
        if (models[modelHandle].owner == address(0)) {
            revert NonexistentModel(modelHandle);
        }
    }

    // ———————————————————————————————————————— Subnet ————————————————————————————————————————
    function registerSubnet(string calldata subnetHandle, string calldata metadata) external onlyOwner {
        (bool isAvailable, bool isValidInput) = checkSubnetHandleForRegistry(subnetHandle);
        if (!isAvailable) {
            revert SubnetHandleHasExisted(subnetHandle);
        }
        if (!isValidInput) {
            revert InvalidSubnetHandle();
        }
        Subnet memory subnet = Subnet({subnetHandle: subnetHandle, owner: msg.sender, metadata: metadata});
        subnets[subnet.subnetHandle] = subnet;
        emit SubnetRegistered(subnet.subnetHandle, subnet.owner, subnet.metadata);
    }

    function authorizeModelManager(address registrant, string calldata subnetHandle)
        external
        onlySubnetOwner(subnetHandle)
    {
        // No need to check the existence of `subnetHandle` due to the access control {onlySubnetOwner}
        isAuthedModelManager[registrant][subnetHandle] = true;
    }

    function checkExistenceOfSubnet(string memory subnetHandle) public view returns (bool) {
        return subnets[subnetHandle].owner != address(0);
    }

    function checkSubnetHandleForRegistry(string memory subnetHandle)
        public
        view
        returns (bool isAvailable, bool isValidInput)
    {
        isAvailable = subnets[subnetHandle].owner == address(0);
        bytes memory subnetHandleBytes = bytes(subnetHandle);
        uint256 subnetHandleBytesLength = subnetHandleBytes.length;
        isValidInput = subnetHandleBytesLength != 0 && subnetHandleBytesLength <= 64;
    }

    // ———————————————————————————————————————— Model Manager ————————————————————————————————————————
    function registerModelManager(
        string calldata modelManagerId,
        string calldata modelHandle,
        string calldata subnetHandle,
        string calldata url
    ) external authorizedBySubnet(subnetHandle) {
        // No need to check the existence of `subnetHandle` due to the access control {authorizedBySubnet}
        (bool isAvailable, bool isValidInput) = checkModelManagerIdForRegistry(modelManagerId);
        if (!isAvailable) {
            revert ModelManagerIdHasExisted(modelManagerId);
        }
        if (!isValidInput) {
            revert InvalidModelManagerId();
        }
        _checkExistenceOfModel(modelHandle);
        ModelManager memory modelManager = ModelManager({
            modelManagerId: modelManagerId,
            subnetHandle: subnetHandle,
            modelHandle: modelHandle,
            owner: msg.sender,
            url: url
        });
        modelManagers[modelManager.modelManagerId] = modelManager;
        emit ModelManagerRegistered(
            modelManager.modelManagerId,
            modelManager.subnetHandle,
            modelManager.modelHandle,
            modelManager.owner,
            modelManager.url
        );
    }

    function setModelManagerUrl(string calldata modelManagerId, string calldata newUrl)
        external
        onlyModelManagerOwner(modelManagerId)
    {
        // No need to check the existence of `modelManagerId` due to the access control {onlyModelManagerOwner}
        modelManagers[modelManagerId].url = newUrl;
        emit ModelManagerUrlModified(modelManagerId, newUrl);
    }

    function submitServiceProof(
        string calldata modelManagerId,
        string[] calldata botHandleArray,
        uint256[] calldata workloadArray,
        uint256[] calldata callNumberArray,
        uint256[][] calldata value
    ) external onlyModelManagerOwner(modelManagerId) {
        // No need to check the existence of `modelManagerId` due to the access control {onlyModelManagerOwner}
        _checkServiceProofLength(botHandleArray, workloadArray, callNumberArray, value);
        for (uint256 i = 0; i < botHandleArray.length; i++) {
            _executeSubmitServiceProof(
                modelManagerId, botHandleArray[i], workloadArray[i], callNumberArray[i], value[i][0], value[i][1]
            );
        }
    }

    function getModelManagerOwner(string calldata modelManagerId) external view returns (address) {
        return modelManagers[modelManagerId].owner;
    }

    function checkExistenceOfModelManager(string memory modelManagerId) public view returns (bool) {
        return modelManagers[modelManagerId].owner != address(0);
    }

    function checkModelManagerIdForRegistry(string memory modelManagerId)
        public
        view
        returns (bool isAvailable, bool isValidInput)
    {
        isAvailable = modelManagers[modelManagerId].owner == address(0);
        bytes memory modelManagerIdBytes = bytes(modelManagerId);
        uint256 modelManagerIdBytesLength = modelManagerIdBytes.length;
        bool isValidLengthOfInput = modelManagerIdBytesLength == 16;
        bool isValidCharOfInput = true;
        for (uint256 i = 0; i < modelManagerIdBytesLength; i++) {
            bytes1 singleByte = modelManagerIdBytes[i];
            if (!((singleByte >= "0" && singleByte <= "9") || (singleByte >= "A" && singleByte <= "Z"))) {
                isValidCharOfInput = false;
                break;
            }
        }
        isValidInput = isValidLengthOfInput && isValidCharOfInput;
    }

    function _checkServiceProofLength(
        string[] memory botHandleArray,
        uint256[] memory workloadArray,
        uint256[] memory callNumberArray,
        uint256[][] memory value
    ) internal pure {
        if (
            botHandleArray.length == 0 || botHandleArray.length != workloadArray.length
                || botHandleArray.length != callNumberArray.length || botHandleArray.length != value.length
        ) {
            revert InvalidProof(botHandleArray.length, workloadArray.length, callNumberArray.length, value.length);
        }
    }

    function _validateBotHandleOfServiceProof(string memory botHandle) internal view {
        // Check the existence of the given `botHandle`
        _checkExistenceOfBot(botHandle);
        // Check the ownership of the `botHandle`(i.e. check if the model manager owns the bot)
        string memory modelManagerId = bots[botHandle].modelManagerId;
        ModelManager memory modelManager = modelManagers[modelManagerId];
        address validModelManagerOwner = modelManager.owner;
        if (msg.sender != validModelManagerOwner) {
            revert InvalidBotHandleOfProof(botHandle, validModelManagerOwner, msg.sender);
        }
    }

    function _executeSubmitServiceProof(
        string memory modelManagerId,
        string memory botHandle,
        uint256 workload,
        uint256 callNumber,
        uint256 valueOfSubnet,
        uint256 valueOfBot
    ) internal {
        _validateBotHandleOfServiceProof(botHandle);
        botUsage[botHandle].workload += workload;
        botUsage[botHandle].callNumber += callNumber;
        string memory subnetHandle = modelManagers[modelManagerId].subnetHandle;
        address subnetOwner = subnets[subnetHandle].owner;
        reward[subnetOwner] += valueOfSubnet;
        createdBotTokens[botHandle] == address(0)
            ? reward[getBotOwner(botHandle)] += valueOfBot
            : botReward[botHandle] += valueOfBot;
    }

    function _checkExistenceOfModelManager(string memory modelManagerId) internal view {
        if (modelManagers[modelManagerId].owner == address(0)) {
            revert NonexistentModelManager(modelManagerId);
        }
    }

    // ———————————————————————————————————————— Bot ————————————————————————————————————————
    function createBot(
        string calldata botHandle,
        string calldata modelManagerId,
        string calldata metadata,
        uint256 price
    ) external {
        (bool isAvailable, bool isValidInput) = checkBotHandleForBotCreation(botHandle);
        if (!isAvailable) {
            revert BotHandleHasExisted(botHandle);
        }
        if (!isValidInput) {
            revert InvalidBotHandle();
        }
        _checkExistenceOfModelManager(modelManagerId);
        // The bot price should not exceed 100 for per message of chat
        if (price > 100) {
            revert ExcessiveBotPrice(price, 100);
        }
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
        // No need to check the existence of `botHandle` due to the access control {onlyBotOwner}
        bots[botHandle].price = price;
        emit BotPriceModified(botHandle, price);
    }

    function followBot(string calldata botHandle) external {
        _checkExistenceOfBot(botHandle);
        emit BotFollowed(botHandle, msg.sender);
    }

    function payForBot(address tokenAddress, uint256 amount) external {
        if (indexOfSupportedToken[tokenAddress] == 0) {
            revert UnsupportedToken(tokenAddress);
        }
        if (amount == 0) {
            revert InvalidPayment();
        }
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)'))) == 0x23b872dd;
        (bool success, bytes memory data) =
            tokenAddress.call(abi.encodeWithSelector(0x23b872dd, msg.sender, address(this), amount));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) {
            revert TokenTransferFailed(amount);
        }
        userBalance[msg.sender] += amount;
        emit BotPayment(msg.sender, amount);
    }

    /**
     * @param stringData the array consist of the string parameters for {createToken}
     * @param uintData the array consist of the uint parameters for {createToken}
     * @dev The specific values of the parameters `stringData` and `uintData` are shown as follows:
     * `stringData[0]` == `botHandle`;
     * `stringData[1]` == `name`;
     * `stringData[2]` == `symbol`;
     * `uintData[0]` == `decimals`;
     * `uintData[1]` == `maxSupply`;
     * `uintData[2]` == `auctionStartTime`;
     * `uintData[3]` == `chatToEarnRatio`;
     * `uintData[4]` == `airdropPercentagePerRound`;
     * `uintData[5]` == `pricePerThousandTokens`;
     */
    function createToken(string[3] calldata stringData, uint256[6] calldata uintData, address bidTokenAddress)
        external
        onlyBotOwner(stringData[0])
    {
        string memory botHandle = stringData[0];
        // No need to check the existence of `botHandle` due to the access control {onlyBotOwner}
        if (createdBotTokens[botHandle] != address(0)) {
            revert BotTokenHasCreated(botHandle, createdBotTokens[botHandle]);
        }
        address botTokenAddress = IBotTokenFactory(botTokenFactory).createToken(stringData, uintData, bidTokenAddress);
        createdBotTokens[botHandle] = botTokenAddress;
        emit BotTokenCreated(botHandle, botTokenAddress);
    }

    function getBotOwner(string memory botHandle) public view returns (address) {
        _checkExistenceOfBot(botHandle);
        return bots[botHandle].owner;
    }

    function checkExistenceOfBot(string memory botHandle) public view returns (bool) {
        return bots[botHandle].owner != address(0);
    }

    function checkBotHandleForBotCreation(string memory botHandle)
        public
        view
        returns (bool isAvailable, bool isValidInput)
    {
        isAvailable = bots[botHandle].owner == address(0);
        bytes memory botHandleBytes = bytes(botHandle);
        uint256 botHandleBytesLength = botHandleBytes.length;
        bool isValidLengthOfInput = botHandleBytesLength != 0 && botHandleBytesLength <= 32;
        bool isValidCharOfInput = true;
        for (uint256 i = 0; i < botHandleBytesLength; i++) {
            bytes1 singleByte = botHandleBytes[i];
            if (
                !(
                (singleByte >= "0" && singleByte <= "9") || (singleByte >= "A" && singleByte <= "Z")
                || singleByte == "_" || (singleByte >= "a" && singleByte <= "z")
                )
            ) {
                isValidCharOfInput = false;
                break;
            }
        }
        isValidInput = isValidLengthOfInput && isValidCharOfInput;
    }

    function _checkExistenceOfBot(string memory botHandle) internal view {
        if (bots[botHandle].owner == address(0)) {
            revert NonexistentBot(botHandle);
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

    function updateUserData(address[] calldata user, uint256[] calldata data) external authorizedByOwner {
        if (user.length != data.length) {
            revert InvalidUpdateOfUserData(user.length, data.length);
        }
        for (uint256 i = 0; i < user.length; i++) {
            userBalance[user[i]] = data[i];
        }
    }

    function manageReporter(address account, bool isAuthorized) external onlyOwner {
        isReporter[account] = isAuthorized;
    }

    function addSupportedToken(address addedToken) external onlyOwner {
        uint64 indexOfAddedToken = indexOfSupportedToken[addedToken];
        if (indexOfAddedToken != 0) {
            revert DuplicateTokenAdded(addedToken, indexOfAddedToken);
        }
        indexOfSupportedToken[addedToken] = uint64(supportedTokens.length);
        supportedTokens.push(addedToken);
        emit SupportedTokenAdded(addedToken);
    }

    function removeSupportedToken(address removedToken) external onlyOwner {
        if (indexOfSupportedToken[removedToken] == 0) {
            revert UnsupportedToken(removedToken);
        }
        address tailElement = supportedTokens[supportedTokens.length - 1];
        uint64 indexOfRemovedToken = indexOfSupportedToken[removedToken];
        supportedTokens[indexOfRemovedToken] = tailElement;
        delete indexOfSupportedToken[removedToken];
        supportedTokens.pop();
        emit SupportedTokenRemoved(removedToken);
    }

    function checkSupportOfToken(address tokenAddress) public view returns (bool isSupported) {
        isSupported = indexOfSupportedToken[tokenAddress] != 0;
    }
}
