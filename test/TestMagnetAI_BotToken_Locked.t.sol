// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {TetherToken} from "../src/tokens/TetherToken08.sol";
import "../src/BotTokenFactory.sol";
import "../src/BotToken.sol";
import "../src/MagnetAI.sol";
import "./CommonFunctionsForTest.sol";

contract TestMagnetAI_BotToken_Locked is Test, CommonFunctionsForTest {
    address contractOwner = makeAddr("contractOwner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");
    address user5 = makeAddr("user5");
    address modelManager = makeAddr("modelManager");
    address botOwner = makeAddr("botOwner");
    address payer = makeAddr("payer");
    // State variables of bot and bot token
    string botHandle0 = "BotForTest_0";
    string tokenNameOfBot0 = "botTokenForTest_0";
    string tokenSymbolOfBot0 = "BTFT0";
    // Make `maxSupply` is the common supply of 100000
    // Also avoid the overflow of `maxSupply` * `airdropRatio`
    uint256 decimalsOfBot0 = 18;
    uint256 issuanceStartTimeOfBot0 = block.timestamp + _generateRandomUint(0, 31536001);
    uint256 airdropRatioOfBot0 = _generateRandomUint(0, 100);
    uint256 maxSupplyOfBot0 = 1 * 10 ** 48;
    uint256 dropTimeOfBot0 = _generateRandomUint(1, 1000);
    uint256 totalFundOfBot0 = _generateRandomUint(0, (type(uint256).max / (1000 * 10 ** decimalsOfBot0) - 1));

    TetherToken public USDTContract;
    address public USDTAddr;
    BotTokenFactory public factory;
    address public factoryAddr;
    BotToken public bot0Token;
    address public bot0TokenAddr;
    MagnetAI public magnetAI;
    address public magnetAIAddr;

    function setUp() public {
        deal(contractOwner, 1 * 10 * 10 ether);
        vm.startPrank(contractOwner);
        USDTContract = new TetherToken(1 * 10 ** 32, "Tether USD", "USDT", 6);
        USDTAddr = address(USDTContract);
        factory = new BotTokenFactory();
        factoryAddr = address(factory);
        magnetAI = new MagnetAI(factoryAddr, USDTAddr);
        magnetAIAddr = address(magnetAI);
        factory.initialize(magnetAIAddr);
        USDTContract.transfer(user1, 1 * 10 ** 30);
        USDTContract.transfer(user2, 1 * 10 ** 30);
        USDTContract.transfer(user3, 1 * 10 ** 30);
        USDTContract.transfer(user4, 1 * 10 ** 30);
        USDTContract.transfer(user5, 1 * 10 ** 30);
        USDTContract.transfer(modelManager, 1 * 10 ** 30);
        USDTContract.transfer(botOwner, 1 * 10 ** 30);
        USDTContract.transfer(payer, 1 * 10 ** 30);
        vm.stopPrank();
        // Initialization of bot
        string[] memory stringInputs = new string[](8);
        stringInputs[0] = botHandle0; // botHandleInput
        stringInputs[1] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[2] = "The metadata of bot_1"; // metadataOfBotInput
        stringInputs[3] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Subnet ABC"; // subnetHandleInput
        stringInputs[6] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        stringInputs[7] = "The url of MODELMANAGER0001"; // urlInput
        uint256 priceOfBotInput = 50 * 10 ** 6;
        uint256 priceOfModelInput = 1234567;
        _registerModel(magnetAI, contractOwner, stringInputs[3], stringInputs[4], priceOfModelInput);
        _registerSubnet(magnetAI, contractOwner, stringInputs[5], stringInputs[6]);
        _authorizeModelManager(magnetAI, contractOwner, modelManager, stringInputs[5]);
        _registerModelManager(
            magnetAI, modelManager, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]
        );
        _createBot(magnetAI, botOwner, stringInputs[0], stringInputs[1], stringInputs[2], priceOfBotInput);
        // Initialize the creation of bot token
        string[3] memory stringData;
        stringData[0] = botHandle0;
        stringData[1] = tokenNameOfBot0;
        stringData[2] = tokenSymbolOfBot0;
        uint256[5] memory uintData;
        uintData[0] = maxSupplyOfBot0;
        uintData[1] = issuanceStartTimeOfBot0;
        uintData[2] = dropTimeOfBot0;
        uintData[3] = airdropRatioOfBot0;
        uintData[4] = totalFundOfBot0;
        // Test
        vm.prank(botOwner);
        magnetAI.createToken(stringData, uintData, address(0));
        bot0TokenAddr = magnetAI.createdBotTokens(botHandle0);
        bot0Token = BotToken(payable(bot0TokenAddr));
    }

    /**
     * @dev Test case(s) of the function {mint}
     */
    // Case 1: 5 users mint token in the final slot.
    // Test sorting. Expect success.
    function test_mint_Complex() public {
        vm.warp(issuanceStartTimeOfBot0);
        uint256 price = bot0Token.mintablePrice();
        uint256 amount = bot0Token.mintSupply() - 90000;
        uint256 payment = amount * price / 1000;
        uint256 totalMintedAmount = amount;
        uint256 totalMintedPayment = payment;
        deal(user1, payment);
        vm.prank(user1);
        bot0Token.mint{value: payment}(amount, price);
        // Step into the 2nd slot
        vm.warp(issuanceStartTimeOfBot0 + 3600);
        uint256 baseFee = bot0Token.mintablePrice();
        // The mint of `user1` in the 2nd slot will triggered the lock status of the token issuance
        price = baseFee + bot0Token.mintPriceIncrement();
        amount = 90000;
        payment = amount * price / 1000;
        totalMintedAmount += amount;
        totalMintedPayment += payment;
        deal(user1, payment);
        vm.prank(user1);
        bot0Token.mint{value: payment}(amount, price);
        // Assertions after the mint of `user1`
        (,,,,, address next1Fetched) = bot0Token.mints(user1);
        assertEq(next1Fetched, address(0), "next1 does not match");
        assertEq(bot0Token.headOfCurrentSlot(), user1, "headOfCurrentSlot does not match");
        assertEq(bot0Token.totalMintedAmount(), totalMintedAmount, "totalMintedAmount does not match");
        assertEq(bot0Token.totalMintedPayment(), totalMintedPayment, "totalMintedPayment does not match");
        assertEq(
            bot0Token.issuanceEndTime(),
            bot0Token.calculateCurrentSlotStartTime() + 86400,
            "issuanceEndTime does not match"
        );
        assertEq(bot0Token.getIssuanceStatus(), "locked", "issuanceStatus does not match");

        // The mint of `user2`
        price = baseFee + bot0Token.mintPriceIncrement() * 2;
        amount = 50000;
        payment = amount * price / 1000;
        totalMintedAmount += amount;
        totalMintedPayment += payment;
        deal(user2, payment);
        vm.prank(user2);
        bot0Token.mint{value: payment}(amount, price);
        // Assertions after the mint of `user2`
        (,,,,, next1Fetched) = bot0Token.mints(user1);
        (,,,,, address next2Fetched) = bot0Token.mints(user2);
        assertEq(next1Fetched, address(0), "next1 does not match");
        assertEq(next2Fetched, user1, "next2 does not match");
        assertEq(bot0Token.headOfCurrentSlot(), user2, "headOfCurrentSlot does not match");
        assertEq(bot0Token.totalMintedAmount(), totalMintedAmount, "totalMintedAmount does not match");
        assertEq(bot0Token.totalMintedPayment(), totalMintedPayment, "totalMintedPayment does not match");

        // The mint of `user3`
        price = baseFee + bot0Token.mintPriceIncrement() * 3;
        amount = 60000;
        payment = amount * price / 1000;
        totalMintedAmount += amount;
        totalMintedPayment += payment;
        deal(user3, payment);
        vm.prank(user3);
        bot0Token.mint{value: payment}(amount, price);
        // Assertions after the mint of `user3`
        (,,,,, next1Fetched) = bot0Token.mints(user1);
        (,,,,, next2Fetched) = bot0Token.mints(user2);
        (,,,,, address next3Fetched) = bot0Token.mints(user3);
        assertEq(next1Fetched, address(0), "next1 does not match");
        assertEq(next2Fetched, user1, "next2 does not match");
        assertEq(next3Fetched, user2, "next3 does not match");
        assertEq(bot0Token.headOfCurrentSlot(), user3, "headOfCurrentSlot does not match");
        assertEq(bot0Token.totalMintedAmount(), totalMintedAmount, "totalMintedAmount does not match");
        assertEq(bot0Token.totalMintedPayment(), totalMintedPayment, "totalMintedPayment does not match");

        // The mint of `user4`
        price = baseFee + bot0Token.mintPriceIncrement() * 4;
        amount = 10000;
        payment = amount * price / 1000;
        totalMintedAmount += amount;
        totalMintedPayment += payment;
        deal(user4, payment);
        console.log("mintablePrice: ", bot0Token.mintablePrice());
        vm.prank(user4);
        bot0Token.mint{value: payment}(amount, price);
        // Assertions after the mint of `user4`
        (,,,,, next1Fetched) = bot0Token.mints(user1);
        (,,,,, next2Fetched) = bot0Token.mints(user2);
        (,,,,, next3Fetched) = bot0Token.mints(user3);
        (,,,,, address next4Fetched) = bot0Token.mints(user4);
        assertEq(next1Fetched, address(0), "next1 does not match");
        assertEq(next2Fetched, user1, "next2 does not match");
        assertEq(next3Fetched, user2, "next3 does not match");
        assertEq(next4Fetched, user3, "next4 does not match");
        assertEq(bot0Token.headOfCurrentSlot(), user4, "headOfCurrentSlot does not match");
        assertEq(bot0Token.totalMintedAmount(), totalMintedAmount, "totalMintedAmount does not match");
        assertEq(bot0Token.totalMintedPayment(), totalMintedPayment, "totalMintedPayment does not match");

        // The mint of `user5`
        price = baseFee + bot0Token.mintPriceIncrement() * 3;
        amount = 10000;
        payment = amount * price / 1000;
        totalMintedAmount += amount;
        totalMintedPayment += payment;
        deal(user5, payment);
        vm.prank(user5);
        bot0Token.mint{value: payment}(amount, price);
        // Assertions after the mint of `user5`
        (,,,,, next1Fetched) = bot0Token.mints(user1);
        (,,,,, next2Fetched) = bot0Token.mints(user2);
        (,,,,, next3Fetched) = bot0Token.mints(user3);
        (,,,,, next4Fetched) = bot0Token.mints(user4);
        (,,,,, address next5Fetched) = bot0Token.mints(user5);
        assertEq(next1Fetched, address(0), "next1 does not match");
        assertEq(next2Fetched, user1, "next2 does not match");
        assertEq(next3Fetched, user5, "next3 does not match");
        assertEq(next4Fetched, user3, "next4 does not match");
        assertEq(next5Fetched, user2, "next5 does not match");
        assertEq(bot0Token.headOfCurrentSlot(), user4, "headOfCurrentSlot does not match");
        assertEq(bot0Token.totalMintedAmount(), totalMintedAmount, "totalMintedAmount does not match");
        assertEq(bot0Token.totalMintedPayment(), totalMintedPayment, "totalMintedPayment does not match");

        // The second mint of `user2`
        price = baseFee + bot0Token.mintPriceIncrement() * 3;
        amount = 50000; // does not change for `user2`
        payment = amount * price / 1000;
        // `totalMintedAmount` does not change
        uint256 additionalPayment = payment - ((baseFee + bot0Token.mintPriceIncrement() * 2) * 50000 / 1000);
        totalMintedPayment += additionalPayment;
        deal(user2, additionalPayment);
        vm.prank(user2);
        bot0Token.mint{value: additionalPayment}(amount, price);
        // Assertions after the second mint of `user2`
        (,,,,, next1Fetched) = bot0Token.mints(user1);
        (,,,,, next2Fetched) = bot0Token.mints(user2);
        (,,,,, next3Fetched) = bot0Token.mints(user3);
        (,,,,, next4Fetched) = bot0Token.mints(user4);
        assertEq(next1Fetched, address(0), "next1 does not match");
        assertEq(next2Fetched, user1, "next2 does not match");
        assertEq(next3Fetched, user5, "next3 does not match");
        assertEq(next4Fetched, user3, "next4 does not match");
        assertEq(next5Fetched, user2, "next5 does not match");
        assertEq(bot0Token.headOfCurrentSlot(), user4, "headOfCurrentSlot does not match");
        assertEq(bot0Token.totalMintedAmount(), totalMintedAmount, "totalMintedAmount does not match");
        assertEq(bot0Token.totalMintedPayment(), totalMintedPayment, "totalMintedPayment does not match");
    }
}
