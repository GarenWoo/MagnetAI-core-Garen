// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {TetherToken} from "../src/tokens/TetherToken08.sol";
import "../src/BotTokenFactory.sol";
import "../src/BotToken.sol";
import "../src/MagnetAI.sol";
import "./CommonFunctionsForTest.sol";

contract TestMagnetAI_Bot is Test, CommonFunctionsForTest {
    address contractOwner = makeAddr("contractOwner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");

    TetherToken public USDTContract;
    address public USDTAddr;
    BotTokenFactory public factory;
    address public factoryAddr;
    BotToken public botToken;
    address public botTokenAddr;
    MagnetAI public entity;
    address public entityAddr;

    function setUp() public {
        deal(contractOwner, 999999999 ether);
        deal(user1, 999999999 ether);
        deal(user2, 999999999 ether);
        deal(user3, 999999999 ether);
        deal(user4, 999999999 ether);
        vm.startPrank(contractOwner);
        USDTContract = new TetherToken(9 * 10 ** 15, "Tether USD", "USDT", 6);
        USDTAddr = address(USDTContract);
        factory = new BotTokenFactory();
        factoryAddr = address(factory);
        entity = new MagnetAI(factoryAddr, USDTAddr);
        entityAddr = address(entity);
        factory.initialize(entityAddr);
        USDTContract.transfer(user1, 2 * 10 ** 15);
        USDTContract.transfer(user2, 2 * 10 ** 15);
        USDTContract.transfer(user3, 2 * 10 ** 15);
        USDTContract.transfer(user4, 2 * 10 ** 15);
        vm.stopPrank();
    }

    /**
     * @dev Test case(s) of the function {createBot}
     */
    // Case 1: Regular call. Expect success.
    function test_createBot() public {
        // Inputs
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = "bot_1"; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        // Initialization
        uint256 priceOfModelInput = 1234567;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        // Test
        _createBot(entity, user2, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        (
            string memory botHandleFetched,
            string memory modelManagerIdFetched,
            address ownerFetched,
            string memory metadataFetched,
            uint256 priceFetched
        ) = entity.bots("bot_1");
        assertEq(botHandleFetched, stringInputs[0], "The botHandle of the created bot does not match the input one");
        assertEq(
            modelManagerIdFetched, stringInputs[1], "The modelManagerId of the created bot does not match the input one"
        );
        assertEq(ownerFetched, user2, "The owner of the created bot does not match the expected one");
        assertEq(metadataFetched, stringInputs[2], "The metadata of the created bot does not match the input one");
        assertEq(priceFetched, priceOfBotInput, "The price of the created bot does not match the input one");
    }

    // Case 2: Input `botHandle` has already existed. Expect revert.
    function test_createBot_ExistentBotHandle() public {
        // Inputs
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = "bot_1"; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        // Initialization
        uint256 priceOfModelInput = 1234567;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, user2, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        // Test
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.BotHandleHasExisted.selector, stringInputs[0]);
        vm.expectRevert(expectedError);
        _createBot(entity, user2, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
    }

    // Case 3: Input `botHandle` is invalid. Expect revert.
    function test_createBot_InvalidBotHandle() public {
        // Inputs
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = "bot-1"; // invalid botHandleInput(, `-` is not acceptable)
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        // Initialization
        uint256 priceOfModelInput = 1234567;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        // Test
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.InvalidBotHandle.selector);
        vm.expectRevert(expectedError);
        _createBot(entity, user2, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
    }

    // Case 4: Input `modelManagerId` is nonexistent. Expect revert.
    function test_createBot_NonexistentModelManagerId() public {
        // Initialization
        string[] memory stringInputs = new string[](9);
        stringInputs[0] = "bot_1"; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        stringInputs[8] = "MODELMANAGER0002"; // nonexistent modelManagerIdInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        uint256 priceOfModelInput = 1234567;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        // Test
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.NonexistentModelManager.selector, stringInputs[8]);
        vm.expectRevert(expectedError);
        _createBot(entity, user2, stringInputs[0], stringInputs[8], stringInputs[2], priceOfBotInput);
    }

    // Case 5: Input `price` exceeds the maximum. Expect revert.
    function test_createBot_ExcessivePrice() public {
        // Inputs
        uint256 maximum = 100 * 10 ** 6;
        uint256 invalidPrice = maximum + 1;
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = "bot_1"; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfModelInput = 1234567;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        // Test
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.ExcessiveBotPrice.selector, invalidPrice, maximum);
        vm.expectRevert(expectedError);
        _createBot(entity, user2, stringInputs[0], stringInputs[1], stringInputs[2], invalidPrice);
    }

    /**
     * @dev Test case(s) of the function {setBotPrice}
     */
    // Case 1: Regular call. Expect success.
    /// forge-config: default.fuzz.runs = 10000
    function testFuzz_setBotPrice_ByBotOwner(uint256 newPrice) public {
        // Assumption(s)
        vm.assume(newPrice >= 0 && newPrice <= 100 * 10 ** 6);
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = "bot_1"; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6; // initial price when the bot is created
        uint256 priceOfModelInput = 1234567;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, user2, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        // Test
        vm.prank(user2);
        entity.setBotPrice(stringInputs[0], newPrice);
        (,,,, uint256 priceFetched) = entity.bots(stringInputs[0]);
        assertEq(priceFetched, newPrice, "The price of the created bot does not match the updated one");
    }

    // Case 2: Called by a non-owner of bot. Expect revert.
    function test_setBotPrice_ByNonBotOwner() public {
        // Inputs
        uint256 priceOfBotInput = 50 * 10 ** 6; // initial price when the bot is created
        uint256 newPrice = 50 * 10 ** 6 + 1;
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = "bot_1"; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfModelInput = 1234567;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, user2, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        // Test
        vm.prank(user3);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.NotBotOwner.selector, user3, user2);
        vm.expectRevert(expectedError);
        entity.setBotPrice(stringInputs[0], newPrice);
    }

    // Case 3: Input `botHandle` does not exist. Expect revert.
    function test_setBotPrice_NonexistentBotHandle() public {
        // Inputs
        string[] memory stringInputs = new string[](9);
        stringInputs[0] = "bot_1"; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        stringInputs[8] = "bot_2"; // nonexistent botHandle
        uint256 priceOfBotInput = 50 * 10 ** 6; // initial price when the bot is created
        uint256 newPrice = 50 * 10 ** 6 + 1;
        // Initialization
        uint256 priceOfModelInput = 1234567;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        // Test
        _createBot(entity, user2, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        vm.prank(user3);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.NotBotOwner.selector, user3, address(0));
        vm.expectRevert(expectedError);
        entity.setBotPrice(stringInputs[8], newPrice);
    }

    // Case 4: Input `price` exceeds the maximum. Expect revert.
    function test_setBotPrice_ExcessivePrice() public {
        // Inputs
        uint256 maximum = 100 * 10 ** 6; // initial price when the bot is created
        uint256 newPrice = maximum + 1;
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = "bot_1"; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfModelInput = 1234567;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, user2, stringInputs[0], stringInputs[1], stringInputs[2], maximum);
        // Test
        vm.prank(user2);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.ExcessiveBotPrice.selector, newPrice, maximum);
        vm.expectRevert(expectedError);
        entity.setBotPrice(stringInputs[0], newPrice);
    }

    /**
     * @dev Test case(s) of the function {followBot}
     */
    // Case 1: Regular call. Expect success.
    function test_followBot() public {
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = "bot_1"; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        uint256 priceOfModelInput = 1234567;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, user2, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        // Test
        vm.prank(user3);
        vm.expectEmit(false, false, false, true, entityAddr);
        emit IMagnetAI.BotFollowed(stringInputs[0], user3);
        entity.followBot(stringInputs[0]);
    }

    // Case 2: Input `botHandle` does not exist. Expect success.
    function test_followBot_NonexistentBotHandle() public {
        // Initialization
        string[] memory stringInputs = new string[](9);
        stringInputs[0] = "bot_1"; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        stringInputs[8] = "bot_2"; // nonexistent modelHandle
        uint256 priceOfBotInput = 50 * 10 ** 6;
        uint256 priceOfModelInput = 1234567;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, user2, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        // Test
        vm.prank(user3);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.NonexistentBot.selector, stringInputs[8]);
        vm.expectRevert(expectedError);
        entity.followBot(stringInputs[8]);
    }

    /**
     * @dev Test case(s) of the function {payForBot}
     */
    // Case 1: Regular call. Expect success.
    /// forge-config: default.fuzz.runs = 10000
    function testFuzz_payForBot(uint256 amount) public {
        // Assumption(s)
        address payer = user3;
        uint256 balanceOfPayer = USDTContract.balanceOf(payer);
        uint256 balanceOfEntity = USDTContract.balanceOf(entityAddr);
        vm.assume(amount > 0 && amount <= balanceOfPayer);
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = "bot_1"; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        uint256 priceOfModelInput = 1234567;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, user2, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        // Test
        vm.startPrank(payer);
        uint256 userBalanceBeforePayment = entity.userBalance(payer);
        USDTContract.approve(entityAddr, amount);
        entity.payForBot(amount);
        uint256 userBalanceAfterPayment = entity.userBalance(payer);
        require(userBalanceAfterPayment >= userBalanceBeforePayment, "userBalance of payer is less than before");
        assertEq(userBalanceAfterPayment - userBalanceBeforePayment, amount, "The change of userBalance does not match the expected value");
        assertEq(USDTContract.balanceOf(payer), balanceOfPayer - amount, "The USDT balance of payer after calling {payForBot} does not match the expect value");
        assertEq(USDTContract.balanceOf(entityAddr), balanceOfEntity + amount, "The USDT balance of MagnetAI after calling {payForBot} does not match the expect value");
        vm.stopPrank();
    }

    // Case 2: Input `amount` equals zero. Expect revert.
    function test_payForBot_ZeroAmount() public {
        // Inputs
        address payer = user3;
        uint256 amount = 0;
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = "bot_1"; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        uint256 priceOfModelInput = 1234567;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, user2, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        // Test
        vm.startPrank(payer);
        USDTContract.approve(entityAddr, amount);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.InvalidPayment.selector);
        vm.expectRevert(expectedError);
        entity.payForBot(amount);
        vm.stopPrank();
    }

    // Case 3:  the payer has not approved the address of the contract {MagnetAI}(i.e. `entityAddr`) with sufficient allowance.
    // This will lead the lower-level call to failure. Expect revert.
    function test_payForBot_InsufficientAllowance() public {
        // Inputs
        address payer = user3;
        uint256 amount = USDTContract.balanceOf(payer) / 10;
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = "bot_1"; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        uint256 priceOfModelInput = 1234567;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, user2, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        vm.startPrank(payer);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.TokenTransferFailed.selector, amount);
        vm.expectRevert(expectedError);
        entity.payForBot(amount);
        USDTContract.approve(entityAddr, amount - 1); // still insufficient
        vm.expectRevert(expectedError);
        entity.payForBot(amount);
        vm.stopPrank();
    }

    // Case 4: The balance of the payer is insufficient though the allowance of the address of the contract {MagnetAI}(i.e. `entityAddr`) is enough.
    // This will lead the lower-level call to failure. Expect revert.
    function test_payForBot_InsufficientBalance() public {
        // Inputs
        address payer = user3;
        uint256 amount = USDTContract.balanceOf(payer) + 1;
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = "bot_1"; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        uint256 priceOfModelInput = 1234567;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, user2, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        vm.startPrank(payer);
        USDTContract.approve(entityAddr, amount);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.TokenTransferFailed.selector, amount);
        vm.expectRevert(expectedError);
        entity.payForBot(amount);
        vm.stopPrank();
    }

    // Case 5: The gas runs out in the call.
    // This will lead the lower-level call to failure. Expect revert.
    function test_payForBot_InsufficientGas() public {
        // Inputs
        address payer = user3;
        uint256 amount = USDTContract.balanceOf(payer) / 10;
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = "bot_1"; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        uint256 priceOfModelInput = 1234567;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, user2, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        vm.startPrank(payer);
        USDTContract.approve(entityAddr, amount);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.TokenTransferFailed.selector, amount);
        vm.expectRevert(expectedError);
        bytes memory callData = abi.encodeCall(entity.payForBot, (amount));
        (bool isSuccess,) = entityAddr.call{gas: 20999}(callData);  // insufficient gas
        require(isSuccess, "{payForBot} is called unsuccessfully in the test case");
        vm.stopPrank();
    }

}
