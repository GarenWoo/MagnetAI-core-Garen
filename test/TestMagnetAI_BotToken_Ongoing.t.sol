// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {TetherToken} from "../src/tokens/TetherToken08.sol";
import "../src/BotTokenFactory.sol";
import "../src/BotToken.sol";
import "../src/MagnetAI.sol";
import "./CommonFunctionsForTest.sol";

contract TestMagnetAI_BotToken_Ongoing is Test, CommonFunctionsForTest {
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
    // Case 1: Regular call. First mint of the current slot.
    // Fuzz testing of `amount`. Expect success.
    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_mint_Amount_FirstMintOfSlot(uint256 amount) public {
        uint256 mintSupply = bot0Token.mintSupply();
        uint256 price = bot0Token.mintablePrice();
        vm.assume(amount != 0 && amount % 1000 == 0 && amount <= mintSupply / price); // avoid both invalidity and overflow
        vm.warp(issuanceStartTimeOfBot0);
        deal(user1, amount * price / 1000);
        vm.prank(user1);
        bot0Token.mint{value: amount * price / 1000}(amount, price);
        (
            uint256 confirmedAmountFetched,
            uint256 confirmedPaymentFetched,
            uint256 amountFetched,
            uint256 priceFetched,
            uint256 slotFetched,
            address nextFetched
        ) = bot0Token.mints(user1);
        assertEq(confirmedAmountFetched, 0, "confirmedAmount does not match");
        assertEq(confirmedPaymentFetched, 0, "confirmedPayment does not match");
        assertEq(amountFetched, amount, "amount does not match");
        assertEq(priceFetched, price, "price does not match");
        assertEq(slotFetched, bot0Token.calculateCurrentSlotStartTime(), "slot does not match");
        assertEq(nextFetched, address(0), "next does not match");
        assertEq(bot0Token.headOfCurrentSlot(), user1, "headOfCurrentSlot does not match");
        assertEq(bot0Token.previousConfirmedAmount(), 0, "previousConfirmedAmount does not match");
        assertEq(bot0Token.totalMintedAmount(), amount, "totalMintedAmount does not match");
        assertEq(bot0Token.previousConfirmedPayment(), 0, "previousConfirmedPayment does not match");
        assertEq(bot0Token.totalMintedPayment(), amount * price / 1000, "totalMintedPayment does not match");
    }

    // Case 2: Regular call. First mint of the current slot.
    // Fuzz testing of `price`. Expect success.
    /// forge-config: default.fuzz.runs = 200
    function testFuzz_mint_Price_FirstMint(uint256 price) public {
        vm.assume(
            price >= bot0Token.mintablePrice()
                && (price - bot0Token.mintablePrice()) % bot0Token.mintPriceIncrement() == 0
        );
        // Preset the payer and its payment
        vm.startPrank(payer);
        USDTContract.approve(magnetAIAddr, USDTContract.balanceOf(payer));
        magnetAI.payForBot(USDTContract.balanceOf(payer));
        vm.stopPrank();
        uint256 mintSupply = bot0Token.mintSupply();
        uint256 amount = _generateRandomUint(1, mintSupply / price / 1000) * 1000; // Avoid overflow
        vm.warp(issuanceStartTimeOfBot0);
        deal(user1, amount * price / 1000);
        vm.prank(user1);
        bot0Token.mint{value: amount * price / 1000}(amount, price);
        (
            uint256 confirmedAmountFetched,
            uint256 confirmedPaymentFetched,
            uint256 amountFetched,
            uint256 priceFetched,
            uint256 slotFetched,
            address nextFetched
        ) = bot0Token.mints(user1);
        assertEq(confirmedAmountFetched, 0, "confirmedAmount does not match");
        assertEq(confirmedPaymentFetched, 0, "confirmedPayment does not match");
        assertEq(amountFetched, amount, "amount does not match");
        assertEq(priceFetched, price, "price does not match");
        assertEq(slotFetched, bot0Token.calculateCurrentSlotStartTime(), "slot does not match");
        assertEq(nextFetched, address(0), "next does not match");
        assertEq(bot0Token.headOfCurrentSlot(), user1, "headOfCurrentSlot does not match");
        assertEq(bot0Token.previousConfirmedAmount(), 0, "previousConfirmedAmount does not match");
        assertEq(bot0Token.totalMintedAmount(), amount, "totalMintedAmount does not match");
        assertEq(bot0Token.previousConfirmedPayment(), 0, "previousConfirmedPayment does not match");
        assertEq(bot0Token.totalMintedPayment(), amount * price / 1000, "totalMintedPayment does not match");
    }

    // Case 3: Additional mint of the current slot. Only one user mints in the slot. Expect success.
    function test_mint_AdditionalMint_OneUser() public {
        uint256 mintSupply = bot0Token.mintSupply();
        uint256 price = bot0Token.mintablePrice();
        uint256 amount = _generateRandomUint(1, mintSupply / price / 1000) * 1000; // Avoid overflow
        uint256 payment = amount * price / 1000;
        vm.warp(issuanceStartTimeOfBot0);
        deal(user1, payment);
        vm.startPrank(user1);
        bot0Token.mint{value: payment}(amount, price);

        // Additional mint
        amount += 1000;
        price += bot0Token.mintPriceIncrement();
        uint256 additionalPayment = amount * price / 1000 - payment;
        deal(user1, additionalPayment);
        bot0Token.mint{value: additionalPayment}(amount, price);
        // Assertions
        (
            uint256 confirmedAmountFetched,
            uint256 confirmedPaymentFetched,
            uint256 amountFetched,
            uint256 priceFetched,
            uint256 slotFetched,
            address nextFetched
        ) = bot0Token.mints(user1);
        assertEq(confirmedAmountFetched, 0, "confirmedAmount does not match");
        assertEq(confirmedPaymentFetched, 0, "confirmedPayment does not match");
        assertEq(amountFetched, amount, "amount does not match");
        assertEq(priceFetched, price, "price does not match");
        assertEq(slotFetched, bot0Token.calculateCurrentSlotStartTime(), "slot does not match");
        assertEq(nextFetched, address(0), "next does not match");
        assertEq(bot0Token.headOfCurrentSlot(), user1, "headOfCurrentSlot does not match");
        assertEq(bot0Token.previousConfirmedAmount(), 0, "previousConfirmedAmount does not match");
        assertEq(bot0Token.totalMintedAmount(), amount, "totalMintedAmount does not match");
        assertEq(bot0Token.previousConfirmedPayment(), 0, "previousConfirmedPayment does not match");
        assertEq(bot0Token.totalMintedPayment(), payment, "totalMintedPayment does not match");
        vm.stopPrank();
    }

    // Case 4: 3 users mint token in the same slot. Every user only has one mint in the current slot.
    // Test sorting. Expect success.
    function test_mint_OnlyOneMint_3Users() public {
        vm.warp(issuanceStartTimeOfBot0);
        // The mint of `user1`
        uint256 price1 = bot0Token.mintablePrice();
        uint256 amount1 = 1 * 10 ** 6;
        uint256 payment1 = amount1 * price1 / 1000;
        deal(user1, payment1);
        vm.prank(user1);
        bot0Token.mint{value: payment1}(amount1, price1);

        // Assertions after the mint of `user1`
        (,,,,, address next1Fetched) = bot0Token.mints(user1);
        assertEq(next1Fetched, address(0), "next1 does not match");
        assertEq(bot0Token.headOfCurrentSlot(), user1, "headOfCurrentSlot does not match");
        assertEq(bot0Token.totalMintedAmount(), amount1, "totalMintedAmount does not match");
        assertEq(bot0Token.totalMintedPayment(), payment1, "totalMintedPayment does not match");

        // The mint of `user2`
        uint256 amount2 = amount1; // same as the one of `user1`
        uint256 price2 = price1; // same as the one of `user1`
        uint256 payment2 = amount2 * price2 / 1000;
        deal(user2, payment2);
        vm.prank(user2);
        bot0Token.mint{value: payment2}(amount2, price2);

        // Assertions after the mint of `user2`
        (,,,,, next1Fetched) = bot0Token.mints(user1);
        (,,,,, address next2Fetched) = bot0Token.mints(user2);
        assertEq(next1Fetched, user2, "next1 does not match");
        assertEq(next2Fetched, address(0), "next2 does not match");
        assertEq(bot0Token.headOfCurrentSlot(), user1, "headOfCurrentSlot does not match");
        assertEq(bot0Token.totalMintedAmount(), amount1 + amount2, "totalMintedAmount does not match");
        assertEq(bot0Token.totalMintedPayment(), payment1 + payment2, "totalMintedPayment does not match");

        // The mint of `user3`
        uint256 amount3 = amount1; // same as the one of `user1`
        uint256 price3 = price1 + bot0Token.mintPriceIncrement();
        uint256 payment3 = amount3 * price3 / 1000;
        deal(user3, payment3);
        vm.prank(user3);
        bot0Token.mint{value: payment3}(amount3, price3);

        // Assertions after the mint of `user3`
        (,,,,, next1Fetched) = bot0Token.mints(user1);
        (,,,,, next2Fetched) = bot0Token.mints(user2);
        (,,,,, address next3Fetched) = bot0Token.mints(user3);
        assertEq(next1Fetched, user2, "next1 does not match");
        assertEq(next2Fetched, address(0), "next2 does not match");
        assertEq(next3Fetched, user1, "next3 does not match");
        assertEq(bot0Token.headOfCurrentSlot(), user3, "headOfCurrentSlot does not match");
        assertEq(bot0Token.totalMintedAmount(), amount1 + amount2 + amount3, "totalMintedAmount does not match");
        assertEq(bot0Token.totalMintedPayment(), payment1 + payment2 + payment3, "totalMintedPayment does not match");
    }

}
