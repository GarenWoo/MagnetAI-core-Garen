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
        assertEq(
            userBalanceAfterPayment - userBalanceBeforePayment,
            amount,
            "The change of userBalance does not match the expected value"
        );
        assertEq(
            USDTContract.balanceOf(payer),
            balanceOfPayer - amount,
            "The USDT balance of payer after calling {payForBot} does not match the expect value"
        );
        assertEq(
            USDTContract.balanceOf(entityAddr),
            balanceOfEntity + amount,
            "The USDT balance of MagnetAI after calling {payForBot} does not match the expect value"
        );
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
        (bool isSuccess,) = entityAddr.call{gas: 20999}(callData); // insufficient gas
        require(isSuccess, "{payForBot} is called unsuccessfully in the test case");
        vm.stopPrank();
    }

    /**
     * @dev Test case(s) of the function {createToken}
     */
    // Case 1: Regular call. Expect success.
    /// forge-config: default.fuzz.runs = 10000
    function testFuzz_createToken_ByBotOwner(uint256 seed, uint256 totalFund) public {
        // Prepare inputs and assumption(s)
        uint256 airdropRatio = _generateRandomUint(0, 100);
        uint256 decimals = 18; // pay by ether
        vm.assume(seed <= type(uint256).max - 100000); // to avoid `maxSupply` overflowing
        uint256 maxSupply = 100000 * (seed / 100000 + 1);
        vm.assume(
            totalFund < type(uint256).max / (1000 * 10 ** decimals)
                && (airdropRatio == 0 || maxSupply <= type(uint256).max / airdropRatio)
        );
        string[3] memory stringData;
        stringData[0] = "bot_1"; // botHandle
        stringData[1] = _generateRandomUniqueString(BOTTOKENNAME_CHARS, seed % 32 + 1); // name
        stringData[2] = _generateRandomUniqueString(BOTTOKENSYMBOL_CHARS, seed % 10 + 1); // symbol
        uint256[5] memory uintData;
        uintData[0] = maxSupply;
        uintData[1] = block.timestamp + _generateRandomUint(0, 31536001); // issuanceStartTime
        uintData[2] = _generateRandomUint(1, 1000); // dropTime
        uintData[3] = airdropRatio;
        uintData[4] = totalFund;
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
        address botOwner = user2;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, botOwner, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        // Test
        vm.prank(botOwner);
        entity.createToken(stringData, uintData, address(0));
        // Check the value of state variables in the created bot token
        BotToken token = BotToken(payable(entity.createdBotTokens(stringData[0])));
        assertEq(token.botHandle(), stringInputs[0], "BotHandle does not match");
        assertEq(token.magnetAI(), entityAddr, "magnetAI address does not match");
        assertEq(token.botOwner(), botOwner, "botOwner does not match");
        assertEq(token.paymentToken(), address(0), "paymentToken does not match");
        assertEq(token.headOfCurrentSlot(), address(0), "headOfCurrentSlot does not match");
        assertEq(token.issuanceStartTime(), uintData[1], "issuanceStartTime does not match");
        assertEq(token.issuanceEndTime(), 0, "issuanceEndTime does not match");
        assertEq(token.dropTime(), uintData[2] * 86400, "dropTime does not match");
        assertEq(token.isFundClaimed(), false, "isFundClaimed does not match");
        uint256 airdropSupply = uintData[3] * uintData[0] / 100;
        assertEq(token.airdropSupply(), airdropSupply, "airdropSupply does not match");
        assertEq(token.mintSupply(), uintData[0] - airdropSupply, "mintSupply does not match");
        uint256 minPriceThousandTokens = 1 * 10 ** (decimals / 2);
        uint256 pricePerKToken = (totalFund + 1) * 1000 * 10 ** decimals / (uintData[0] - airdropSupply);
        if (pricePerKToken < minPriceThousandTokens) {
            pricePerKToken = minPriceThousandTokens;
        }
        uint256 mintPriceIncrement = pricePerKToken < 10 ? 1 : pricePerKToken / 10;
        assertEq(token.mintPriceIncrement(), mintPriceIncrement, "mintPriceIncrement does not match");
        assertEq(token.previousConfirmedAmount(), 0, "previousConfirmedAmount does not match");
        assertEq(token.totalMintedAmount(), 0, "totalMintedAmount does not match");
        assertEq(token.previousConfirmedPayment(), 0, "previousConfirmedPayment does not match");
        assertEq(token.totalMintedPayment(), 0, "totalMintedPayment does not match");
        assertEq(token.totalUsage(), 0, "totalUsage does not match");
        assertEq(token.mintablePrice(), pricePerKToken, "mintablePrice does not match");
        assertEq(token.finalSlotMintableAmount(), 0, "finalSlotMintableAmount does not match");
    }

    // Case 2: Called by a non-owner of the bot. Expect revert.
    function test_createToken_ByNonBotOwner() public {
        // Prepare inputs and assumption(s)
        uint256 airdropRatio = _generateRandomUint(0, 100);
        uint256 maxSupply = 1 * 10 ** 24;   // valid maxSupply
        uint256 totalFund = 1 * 10 ** 6;    // valid totalFund
        string memory botHandle = "bot_1";
        string[3] memory stringData;
        stringData[0] = botHandle; // botHandle
        stringData[1] = "MagnetBotToken001"; // name
        stringData[2] = "MBT001"; // symbol
        uint256[5] memory uintData;
        uintData[0] = maxSupply;
        uintData[1] = block.timestamp + _generateRandomUint(0, 31536001); // issuanceStartTime
        uintData[2] = _generateRandomUint(1, 1000); // dropTime
        uintData[3] = airdropRatio;
        uintData[4] = totalFund;
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = botHandle; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        uint256 priceOfModelInput = 1234567;
        address botOwner = user2;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, botOwner, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        // Test
        vm.prank(user4);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.NotBotOwner.selector, user4, botOwner);
        vm.expectRevert(expectedError);
        entity.createToken(stringData, uintData, address(0));
    }

    // Case 3: The bot token of the given `botHandle` has already created. Expect revert.
    function test_createToken_DuplicateCreation() public {
        // Prepare inputs and assumption(s)
        uint256 airdropRatio = _generateRandomUint(0, 100);
        uint256 maxSupply = 1 * 10 ** 24;   // valid maxSupply
        uint256 totalFund = 1 * 10 ** 6;    // valid totalFund
        string memory botHandle = "bot_1";
        string[3] memory stringData;
        stringData[0] = botHandle; // botHandle
        stringData[1] = "MagnetBotToken001"; // name
        stringData[2] = "MBT001"; // symbol
        uint256[5] memory uintData;
        uintData[0] = maxSupply;
        uintData[1] = block.timestamp + _generateRandomUint(0, 31536001); // issuanceStartTime
        uintData[2] = _generateRandomUint(1, 1000); // dropTime
        uintData[3] = airdropRatio;
        uintData[4] = totalFund;
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = botHandle; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        uint256 priceOfModelInput = 1234567;
        address botOwner = user2;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, botOwner, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        // Test
        vm.startPrank(botOwner);
        entity.createToken(stringData, uintData, address(0));
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.BotTokenHasCreated.selector, botHandle, entity.createdBotTokens(botHandle));
        vm.expectRevert(expectedError);
        entity.createToken(stringData, uintData, address(0));
        vm.stopPrank();
    }

    // Case 4: Input `botHandle` does not exist. Expect revert.
    function test_createToken_NonexistentBotHandle() public {
        // Prepare inputs and assumption(s)
        uint256 airdropRatio = _generateRandomUint(0, 100);
        uint256 maxSupply = 1 * 10 ** 24;   // valid maxSupply
        uint256 totalFund = 1 * 10 ** 6;    // valid totalFund
        string memory botHandle = "bot_1";
        string memory botHandleNonexistent = "bot_2";
        string[3] memory stringData;
        stringData[0] = botHandleNonexistent; // botHandle
        stringData[1] = "MagnetBotToken001"; // name
        stringData[2] = "MBT001"; // symbol
        uint256[5] memory uintData;
        uintData[0] = maxSupply;
        uintData[1] = block.timestamp + _generateRandomUint(0, 31536001); // issuanceStartTime
        uintData[2] = _generateRandomUint(1, 1000); // dropTime
        uintData[3] = airdropRatio;
        uintData[4] = totalFund;
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = botHandle; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        uint256 priceOfModelInput = 1234567;
        address botOwner = user2;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, botOwner, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        // Test
        vm.prank(botOwner);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.NotBotOwner.selector, botOwner, address(0));
        vm.expectRevert(expectedError);
        entity.createToken(stringData, uintData, address(0));
    }

    // Case 5: Input `name` is invalid. Expect revert.
    function test_createToken_InvalidName() public {
        // Prepare inputs and assumption(s)
        uint256 airdropRatio = _generateRandomUint(0, 100);
        uint256 maxSupply = 1 * 10 ** 24;   // valid maxSupply
        uint256 totalFund = 1 * 10 ** 6;    // valid totalFund
        string memory botHandle = "bot_1";
        string[3] memory stringData;
        stringData[0] = botHandle; // botHandle
        stringData[2] = "MBT001"; // symbol
        uint256[5] memory uintData;
        uintData[0] = maxSupply;
        uintData[1] = block.timestamp + _generateRandomUint(0, 31536001); // issuanceStartTime
        uintData[2] = _generateRandomUint(1, 1000); // dropTime
        uintData[3] = airdropRatio;
        uintData[4] = totalFund;
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = botHandle; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        uint256 priceOfModelInput = 1234567;
        address botOwner = user2;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, botOwner, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);

        // Test
        vm.startPrank(botOwner);
        stringData[1] = "MagnetBotToken@001"; // name(including invalid character `@`)
        bytes memory expectedError = abi.encodeWithSelector(IBotTokenFactory.InvalidTokenName.selector, stringData[1]);
        vm.expectRevert(expectedError);
        entity.createToken(stringData, uintData, address(0));

        stringData[1] = ""; // name(zero-length is invalid)
        expectedError = abi.encodeWithSelector(IBotTokenFactory.InvalidTokenName.selector, stringData[1]);
        vm.expectRevert(expectedError);
        entity.createToken(stringData, uintData, address(0));

        stringData[1] = "MagnetBotTokenSooooooooLooooooong"; // name(invalid length 33 over the maximum 32)
        expectedError = abi.encodeWithSelector(IBotTokenFactory.InvalidTokenName.selector, stringData[1]);
        vm.expectRevert(expectedError);
        entity.createToken(stringData, uintData, address(0));
        vm.stopPrank();
    }

    // Case 6: Input `symbol` is invalid. Expect revert.
    function test_createToken_InvalidSymbol() public {
        // Prepare inputs and assumption(s)
        uint256 airdropRatio = _generateRandomUint(0, 100);
        uint256 maxSupply = 1 * 10 ** 24;   // valid maxSupply
        uint256 totalFund = 1 * 10 ** 6;    // valid totalFund
        string memory botHandle = "bot_1";
        string[3] memory stringData;
        stringData[0] = botHandle; // botHandle
        stringData[1] = "MagnetBotToken001"; // name
        uint256[5] memory uintData;
        uintData[0] = maxSupply;
        uintData[1] = block.timestamp + _generateRandomUint(0, 31536001); // issuanceStartTime
        uintData[2] = _generateRandomUint(1, 1000); // dropTime
        uintData[3] = airdropRatio;
        uintData[4] = totalFund;
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = botHandle; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        uint256 priceOfModelInput = 1234567;
        address botOwner = user2;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, botOwner, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);

        // Test
        vm.startPrank(botOwner);
        stringData[2] = "MBT_001"; // symbol(including invalid character `_`)
        bytes memory expectedError = abi.encodeWithSelector(IBotTokenFactory.InvalidTokenSymbol.selector, stringData[2]);
        vm.expectRevert(expectedError);
        entity.createToken(stringData, uintData, address(0));

        stringData[2] = ""; // symbol(zero-length is invalid)
        expectedError = abi.encodeWithSelector(IBotTokenFactory.InvalidTokenSymbol.selector, stringData[2]);
        vm.expectRevert(expectedError);
        entity.createToken(stringData, uintData, address(0));

        stringData[2] = "MBTSooLoong"; // symbol(invalid length 11 over the maximum 10)
        expectedError = abi.encodeWithSelector(IBotTokenFactory.InvalidTokenSymbol.selector, stringData[2]);
        vm.expectRevert(expectedError);
        entity.createToken(stringData, uintData, address(0));
        vm.stopPrank();
    }

    // Case 7: Input `maxSupply` is zero or not a common multiple of 100000. Expect revert.
    function test_createToken_InvalidMaxSupply() public {
        // Prepare inputs and assumption(s)
        uint256 airdropRatio = _generateRandomUint(0, 100);
        uint256 totalFund = 1 * 10 ** 6;    // valid totalFund
        string memory botHandle = "bot_1";
        string[3] memory stringData;
        stringData[0] = botHandle; // botHandle
        stringData[1] = "MagnetBotToken001"; // name
        stringData[2] = "MBT001"; // symbol
        uint256[5] memory uintData;
        uintData[1] = block.timestamp + _generateRandomUint(0, 31536001); // issuanceStartTime
        uintData[2] = _generateRandomUint(1, 1000); // dropTime
        uintData[3] = airdropRatio;
        uintData[4] = totalFund;
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = botHandle; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        uint256 priceOfModelInput = 1234567;
        address botOwner = user2;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, botOwner, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        
        // Test
        vm.startPrank(botOwner);
        uintData[0] = 1 * 10 ** 24 + 1;   // invalid maxSupply(not a common multiple of 100000)
        bytes memory expectedError = abi.encodeWithSelector(IBotTokenFactory.InvalidMaxSupply.selector, uintData[0]);
        vm.expectRevert(expectedError);
        entity.createToken(stringData, uintData, address(0));
        
        uintData[0] = 0;   // invalid maxSupply(not a common multiple of 100000)
        expectedError = abi.encodeWithSelector(IBotTokenFactory.InvalidMaxSupply.selector, uintData[0]);
        vm.expectRevert(expectedError);
        entity.createToken(stringData, uintData, address(0));
        vm.stopPrank();
    }

    // Case 8: Input `issuanceStartTime` is more than 1 later since the issuance of the bot token. Expect revert.
    function test_createToken_InvalidIssuanceStartTime() public {
        // Prepare inputs and assumption(s)
        uint256 airdropRatio = _generateRandomUint(0, 100);
        uint256 totalFund = 1 * 10 ** 6;    // valid totalFund
        string memory botHandle = "bot_1";
        string[3] memory stringData;
        stringData[0] = botHandle; // botHandle
        stringData[1] = "MagnetBotToken001"; // name
        stringData[2] = "MBT001"; // symbol
        uint256[5] memory uintData;
        uintData[0] = 1 * 10 ** 24;
        uintData[1] = block.timestamp + 31536001; // invalid issuanceStartTime(more than 1 year later)
        uintData[2] = _generateRandomUint(1, 1000); // dropTime
        uintData[3] = airdropRatio;
        uintData[4] = totalFund;
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = botHandle; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        uint256 priceOfModelInput = 1234567;
        address botOwner = user2;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, botOwner, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        // Test
        vm.prank(botOwner);
        bytes memory expectedError = abi.encodeWithSelector(IBotTokenFactory.InvalidIssuanceStartTime.selector, uintData[1], block.timestamp);
        vm.expectRevert(expectedError);
        entity.createToken(stringData, uintData, address(0));
    }

    // Case 9: Input `airdropRatio` exceeds 99. Expect revert.
    function test_createToken_InvalidAirdropRatio() public {
        // Prepare inputs and assumption(s)
        uint256 totalFund = 1 * 10 ** 6;    // valid totalFund
        string memory botHandle = "bot_1";
        string[3] memory stringData;
        stringData[0] = botHandle; // botHandle
        stringData[1] = "MagnetBotToken001"; // name
        stringData[2] = "MBT001"; // symbol
        uint256[5] memory uintData;
        uintData[0] = 1 * 10 ** 24;
        uintData[1] = block.timestamp + _generateRandomUint(0, 31536001); // issuanceStartTime
        uintData[2] = _generateRandomUint(1, 1000); // dropTime
        uintData[3] = 100; // invalid airdropRatio(100 > maximum which is 99)
        uintData[4] = totalFund;
        // Initialization
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = botHandle; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        uint256 priceOfModelInput = 1234567;
        address botOwner = user2;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, botOwner, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        // Test
        vm.prank(botOwner);
        bytes memory expectedError = abi.encodeWithSelector(IBotTokenFactory.InvalidAirdropRatio.selector, uintData[3]);
        vm.expectRevert(expectedError);
        entity.createToken(stringData, uintData, address(0));
    }

    // Case 10: PaymentToken is unsupported. Expect revert.
    /// forge-config: default.fuzz.runs = 10000
    function testFuzz_createToken_PayByUnsupportedToken(uint256 seed, uint256 totalFund) public {
        // Prepare inputs and assumption(s)
        uint256 airdropRatio = _generateRandomUint(0, 100);
        uint256 decimals = 18; // pay by ether
        vm.assume(seed <= type(uint256).max - 100000); // to avoid `maxSupply` overflowing
        uint256 maxSupply = 100000 * (seed / 100000 + 1);
        vm.assume(
            totalFund < type(uint256).max / (1000 * 10 ** decimals)
                && (airdropRatio == 0 || maxSupply <= type(uint256).max / airdropRatio)
        );
        string[3] memory stringData;
        stringData[0] = "bot_1"; // botHandle
        stringData[1] = _generateRandomUniqueString(BOTTOKENNAME_CHARS, seed % 32 + 1); // name
        stringData[2] = _generateRandomUniqueString(BOTTOKENSYMBOL_CHARS, seed % 10 + 1); // symbol
        uint256[5] memory uintData;
        uintData[0] = maxSupply;
        uintData[1] = block.timestamp + _generateRandomUint(0, 31536001); // issuanceStartTime
        uintData[2] = _generateRandomUint(1, 1000); // dropTime
        uintData[3] = airdropRatio;
        uintData[4] = totalFund;
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
        address botOwner = user2;
        _registerModel(entity, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(entity, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(entity, contractOwner, user1, stringInputs[5]);
        _registerModelManager(entity, user1, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
        _createBot(entity, botOwner, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        // Test
        address unsupportedToken = address(1234567);
        vm.prank(botOwner);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.UnsupportedToken.selector, unsupportedToken);
        vm.expectRevert(expectedError);
        entity.createToken(stringData, uintData, unsupportedToken);
    }

    /**
     * @dev Test case(s) of the function {getBotOwner}
     */
    // Case 1: Regular call. The input `botHandle` exists. Expect success.
    function test_getBotOwner() public {
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
        address result = entity.getBotOwner(stringInputs[0]);
        assertEq(result, user2, "The bot owner does not match the expect one");
    }

    // Case 2: Input `botHandle` does not exist. Expect revert.
    function test_getBotOwner_NonexistentBotHandle() public {
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
        string memory nonexistentBotHandle = "bot_2";
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.NonexistentBot.selector, nonexistentBotHandle);
        vm.expectRevert(expectedError);
        entity.getBotOwner(nonexistentBotHandle);
    }
}
