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
    uint256 maxSupplyOfBot0 = _generateRandomUint(100000, type(uint256).max / airdropRatioOfBot0 - 99999) / 100000 * 100000;
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
        USDTContract = new TetherToken(6 * 10 ** 30, "Tether USD", "USDT", 6);
        USDTAddr = address(USDTContract);
        factory = new BotTokenFactory();
        factoryAddr = address(factory);
        magnetAI = new MagnetAI(factoryAddr, USDTAddr);
        magnetAIAddr = address(magnetAI);
        factory.initialize(magnetAIAddr);
        USDTContract.transfer(user1, 1 * 10 ** 30);
        USDTContract.transfer(user2, 1 * 10 ** 30);
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
        _registerModelManager(magnetAI, modelManager, stringInputs[1], stringInputs[3], stringInputs[5], stringInputs[7]);
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
        vm.assume(amount != 0 && amount % 1000 == 0 && amount <= mintSupply / price);   // avoid both invalidity and overflow
        vm.warp(issuanceStartTimeOfBot0);
        deal(user1, amount * price);
        vm.prank(user1);
        bot0Token.mint{value: amount * price}(amount, price);
    }

    // Case 2: Regular call. First mint of the current slot.
    // Fuzz testing of `price`. Expect success.
    /// forge-config: default.fuzz.runs = 200
    function testFuzz_mint_Price_FirstMintOfSlot(uint256 price) public {
        vm.assume(price >= bot0Token.mintablePrice() && (price - bot0Token.mintablePrice()) % bot0Token.mintPriceIncrement() == 0);
        // Preset the payer and its payment
        vm.startPrank(payer);
        USDTContract.approve(magnetAIAddr, USDTContract.balanceOf(payer));
        magnetAI.payForBot(USDTContract.balanceOf(payer));
        vm.stopPrank();
        uint256 mintSupply = bot0Token.mintSupply();
        uint256 amount = _generateRandomUint(1, mintSupply / price / 1000) * 1000;  // Avoid overflow
        vm.warp(issuanceStartTimeOfBot0);
        deal(user1, amount * price);
        vm.prank(user1);
        bot0Token.mint{value: amount * price}(amount, price);
    }

}