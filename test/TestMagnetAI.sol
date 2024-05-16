// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {MagnetAI} from "../src/MagnetAI.sol";
import {IMagnetAI} from "../src/interfaces/IMagnetAI.sol";
import {TetherToken} from "../src/tokens/TetherToken08.sol";

contract TestMagnetAI is Test {
    address contractOwner = makeAddr("contractOwner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    MagnetAI public entity;
    address public entityAddr;
    TetherToken public USDTContract;
    address public USDTAddress;

    function setUp() public {
        deal(contractOwner, 10000 ether);
        deal(user1, 10000 ether);
        deal(user2, 10000 ether);
        vm.startPrank(contractOwner);
        USDTContract = new TetherToken(3 * 10 ** 12, "Tether USD", "USDT", 6);
        USDTAddress = address(USDTContract);
        entity = new MagnetAI(USDTAddress);
        entityAddr = address(entity);
        USDTContract.transfer(user1, 1 * 10 ** 12);
        USDTContract.transfer(user2, 1 * 10 ** 12);
        vm.stopPrank();
    }

    // ———————————————————————————————————————— AI Model ————————————————————————————————————————
    // Case 1: Test the call of the function {registerModel} by a non_ContractOwner address. Expect revert.
    function test_registerModel_ByNonContractOwner() public {
        uint256 price = 1234567;
        vm.startPrank(contractOwner);
        entity.registerModel("modelHandle_GPT3.5", "metadataOfModel1", price);
        (string memory modelHandleFetched, address ownerFetched, string memory metadataFetched, uint256 priceFetched) =
            entity.models("modelHandle_GPT3.5");
        IMagnetAI.AIModel memory modelFetched = IMagnetAI.AIModel(modelHandleFetched, ownerFetched, metadataFetched, priceFetched);
        assertEq(modelFetched.modelHandle, "modelHandle_GPT3.5", "Expect that the modelHandle equals 'modelHandle_GPT3.5'");
        assertEq(modelFetched.owner, contractOwner, "Expect that the owner equals contractOwner");
        assertEq(modelFetched.metadata, "metadataOfModel1", "Expect that the metadata equals 'metadataOfModel1'");
        assertEq(modelFetched.price, price, "The price of 'modelHandle_GPT3.5' does not match the given price");
        // Register a new model by a non_ContractOwner address. Expect the call reverts an error.
        vm.startPrank(user1);
        vm.expectRevert();
        entity.registerModel("modelHandleOfGPT4", "metadataOfModel2", price);
        vm.stopPrank();
    }

    // Case 2: Test the given value of the parameter `price` in the function {registerModel}.
    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_registerModel_ParamPrice(uint256 price) public {
        vm.startPrank(contractOwner);
        entity.registerModel("modelHandle_GPT3.5", "metadataOfModel1", price);
        (string memory modelHandleFetched, address ownerFetched, string memory metadataFetched, uint256 priceFetched) =
            entity.models("modelHandle_GPT3.5");
        IMagnetAI.AIModel memory modelFetched = IMagnetAI.AIModel(modelHandleFetched, ownerFetched, metadataFetched, priceFetched);
        assertEq(modelFetched.modelHandle, "modelHandle_GPT3.5", "Expect that the modelHandle equals 'modelHandle_GPT3.5'");
        assertEq(modelFetched.owner, contractOwner, "Expect that the owner equals contractOwner");
        assertEq(modelFetched.metadata, "metadataOfModel1", "Expect that the metadata equals 'metadataOfModel1'");
        assertEq(modelFetched.price, price, "The price of 'modelHandle_GPT3.5' does not match the given price");
        // Register a new model by a non_ContractOwner address. Expect the call reverts an error.
        vm.startPrank(user1);
        vm.expectRevert();
        entity.registerModel("modelHandleOfGPT4", "metadataOfModel2", price);
        vm.stopPrank();
    }

    // Case 3: Test the given value of the parameter `price` in the function {setModelPrice}.
    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_setModelPrice_ParamPrice(uint256 price) public {
        uint256 initialPrice = 1234567;
        vm.startPrank(contractOwner);
        entity.registerModel("modelHandle_GPT3.5", "metadataOfModel1", initialPrice);
        (string memory modelHandleFetched, address ownerFetched, string memory metadataFetched, uint256 priceFetched) =
            entity.models("modelHandle_GPT3.5");
        IMagnetAI.AIModel memory modelFetched =
            IMagnetAI.AIModel(modelHandleFetched, ownerFetched, metadataFetched, priceFetched);
        console.log("the inital price of 'modelHandle_GPT3.5':", modelFetched.price);
        entity.setModelPrice("modelHandle_GPT3.5", price);
        (modelHandleFetched, ownerFetched, metadataFetched, priceFetched) = entity.models("modelHandle_GPT3.5");
        modelFetched = IMagnetAI.AIModel(modelHandleFetched, ownerFetched, metadataFetched, priceFetched);
        console.log("The updated price of 'modelHandle_GPT3.5':", modelFetched.price);
        assertEq(modelFetched.price, price, "The current price does not equal the given price after the update");
        vm.stopPrank();
    }

    // ———————————————————————————————————————— Subnet ————————————————————————————————————————
    function test_registerSubnet() public {
        vm.startPrank(contractOwner);
        entity.registerSubnet("Subnet ABC", "Metadata of Subnet ABC");
        (string memory subnetHandleFetched, address ownerFetched, string memory metadataFetched) = entity.subnets("Subnet ABC");
        IMagnetAI.Subnet memory subnetFetched = IMagnetAI.Subnet(subnetHandleFetched, ownerFetched, metadataFetched);
        assertEq(subnetFetched.subnetHandle, "Subnet ABC", "Not expected subnetHandle");
        assertEq(subnetFetched.owner, contractOwner, "Expect that the owner equals contractOwner");
        assertEq(subnetFetched.metadata, "Metadata of Subnet ABC", "Not expected metadata of Subnet ABC");
        // Register a new subnet by a non_ContractOwner address. Expect the call reverts an error.
        vm.startPrank(user1);
        vm.expectRevert();
        entity.registerSubnet("Subnet DEF", "Metadata of Subnet DEF");
        vm.stopPrank();
    }

    // ———————————————————————————————————————— Model Manager ————————————————————————————————————————
    function test_registerModelManager() public {
        vm.startPrank(contractOwner);
        entity.registerModel("modelHandle_GPT3.5", "metadataOfModel1", 1 gwei);
        entity.registerSubnet("Subnet ABC", "Metadata of Subnet ABC");
        entity.registerModelManager("modelHandle_GPT3.5", "Subnet ABC", "ModelManagerURL");
        (
            uint256 modelManagerIdFetched,
            string memory subnetHandleFetched,
            string memory modelHandleFetched,
            address ownerFetched,
            string memory urlFetched
        ) = entity.modelManagers(1);
        IMagnetAI.ModelManager memory modelManagerFetched =
            IMagnetAI.ModelManager(modelManagerIdFetched, subnetHandleFetched, modelHandleFetched, ownerFetched, urlFetched);
        assertEq(modelManagerFetched.modelManagerId, 1, "Expect that the modelManagerId equals 1");
        assertEq(modelManagerFetched.subnetHandle, "Subnet ABC", "Not expected subnetHandle");
        assertEq(modelManagerFetched.modelHandle, "modelHandle_GPT3.5", "Expect that the modelHandle equals 'modelHandle_GPT3.5'");
        assertEq(modelManagerFetched.owner, contractOwner, "Expect that the owner equals contractOwner");
        assertEq(modelManagerFetched.url, "ModelManagerURL", "Expect that the url equals 'ModelManagerURL'");
        // Register a new model manager by a non_ContractOwner address. Expect the call reverts an error.
        vm.startPrank(user1);
        vm.expectRevert();
        entity.registerModelManager("modelHandle_GPT3.5", "Subnet ABC", "ModelManagerURL_Another");
        vm.stopPrank();
    }

    function test_setModelManagerUrl() public {
        vm.startPrank(contractOwner);
        entity.registerModel("modelHandle_GPT3.5", "MetadataOfModel", 12345);
        entity.registerSubnet("Subnet ABC", "Metadata of Subnet ABC");
        entity.registerModelManager("modelHandle_GPT3.5", "Subnet ABC", "ModelManagerURL_Original");
        entity.setModelManagerUrl(1, "ModelManagerURL_Updated");
        (
            uint256 modelManagerIdFetched,
            string memory subnetHandleFetched,
            string memory modelHandleFetched,
            address ownerFetched,
            string memory urlFetched
        ) = entity.modelManagers(1);
        IMagnetAI.ModelManager memory modelManagerFetched =
            IMagnetAI.ModelManager(modelManagerIdFetched, subnetHandleFetched, modelHandleFetched, ownerFetched, urlFetched);
        assertEq(modelManagerFetched.url, "ModelManagerURL_Updated", "The current url does not equal the input url");
        // Set the url of a model manager by a non-ModelManagerOwner address. Expect the call reverts an error.
        vm.startPrank(user1);
        vm.expectRevert();
        entity.setModelManagerUrl(1, "ModelManagerURL_Another");
        vm.stopPrank();
    }

    // function test_submitServiceProof() public {
    //     vm.startPrank(contractOwner);
    //     entity.registerModel("modelHandle_GPT3.5", "MetadataOfModel", 12345);
    //     entity.registerSubnet();
    //     entity.registerModelManager("modelHandle_GPT3.5", 1, "ModelManagerURL_Original");
    //     string[] memory botHandleArray;
    //     uint256[] memory workloadArray;
    //     uint256[] memory callNumberArray;
    //     uint256[][] memory value;
    //     entity.submitServiceProof(1, botHandleArray, workloadArray, callNumberArray, value);

    //     vm.stopPrank();
    // }

    // ———————————————————————————————————————— Bot ————————————————————————————————————————
    function test_createBot() public {
        uint256 price = 11223344;
        vm.startPrank(contractOwner);
        entity.registerModel("modelHandle_GPT3.5", "MetadataOfModel", 12345);
        entity.registerSubnet("Subnet ABC", "Metadata of Subnet ABC");
        entity.registerModelManager("modelHandle_GPT3.5", "Subnet ABC", "ModelManagerURL");
        entity.createBot("bot_1", 1, "metadataForBot1", price);
        (
            string memory botHandleFetched,
            uint256 modelManagerIdFetched,
            address ownerFetched,
            string memory metadataFetched,
            uint256 priceFetched
        ) = entity.bots("bot_1");
        IMagnetAI.Bot memory botFetched =
            IMagnetAI.Bot(botHandleFetched, modelManagerIdFetched, ownerFetched, metadataFetched, priceFetched);
        assertEq(botFetched.botHandle, "bot_1", "Expect that the botHandle is 'bot_1'");
        assertEq(botFetched.modelManagerId, 1, "Expect that the modelManagerId is 1");
        assertEq(botFetched.metadata, "metadataForBot1", "Expect that the metadata is 'metadataForBot1'");
        assertEq(botFetched.price, price, "Expect that the price is 11223344");
        vm.startPrank(user1);
        vm.expectRevert();
        entity.createBot("bot_1", 1, "metadataForBot1", price);
        vm.stopPrank();
    }

    function test_setBotPrice() public {
        uint256 originalPrice = 11223344;
        uint256 newPrice = 99998888;
        vm.startPrank(contractOwner);
        entity.registerModel("modelHandle_GPT3.5", "MetadataOfModel", 12345);
        entity.registerSubnet("Subnet ABC", "Metadata of Subnet ABC");
        entity.registerModelManager("modelHandle_GPT3.5", "Subnet ABC", "urlForModelManager1");
        entity.createBot("bot_1", 1, "metadataForBot1", originalPrice);
        entity.setBotPrice("bot_1", newPrice);
        (
            string memory botHandleFetched,
            uint256 modelManagerIdFetched,
            address ownerFetched,
            string memory metadataFetched,
            uint256 priceFetched
        ) = entity.bots("bot_1");
        IMagnetAI.Bot memory botFetched =
            IMagnetAI.Bot(botHandleFetched, modelManagerIdFetched, ownerFetched, metadataFetched, priceFetched);
        assertEq(botFetched.price, newPrice, "Expect that the price of the Bot is 99998888");
        vm.startPrank(user1);
        vm.expectRevert();
        entity.setBotPrice("bot_1", newPrice);
        vm.stopPrank();
    }

    function test_followBot() public {
        vm.startPrank(contractOwner);
        entity.registerModel("modelHandle_GPT3.5", "MetadataOfModel", 12345);
        entity.registerSubnet("Subnet ABC", "Metadata of Subnet ABC");
        entity.registerModelManager("modelHandle_GPT3.5", "Subnet ABC", "urlForModelManager1");
        entity.createBot("bot_1", 1, "metadataForBot1", 1122334455);
        entity.followBot("bot_1");
        vm.stopPrank();
    }

    function test_payForBot() public {
        vm.startPrank(contractOwner);
        entity.registerModel("modelHandle_GPT3.5", "MetadataOfModel", 12345);
        entity.registerSubnet("Subnet ABC", "Metadata of Subnet ABC");
        entity.registerModelManager("modelHandle_GPT3.5", "Subnet ABC", "urlForModelManager1");
        entity.createBot("bot_1", 1, "metadataForBot1", 1122334455);
        // Pay for bot called by `contractOwner`
        uint256 payment1 = 123 * 10 ** USDTContract.decimals();
        USDTContract.approve(entityAddr, payment1);
        entity.payForBot(payment1);
        assertEq(entity.userBalance(contractOwner), payment1, "The USDT balance of contractOwner is not as expected");
        assertEq(USDTContract.balanceOf(entityAddr), payment1, "Not expected USDT balance in the entity contract after the 1st payment");
        // Pay for bot called by `user1`
        vm.startPrank(user1);
        uint256 payment2 = 377 * 10 ** USDTContract.decimals();
        USDTContract.approve(entityAddr, payment2);
        entity.payForBot(payment2);
        assertEq(entity.userBalance(user1), payment2, "The USDT balance of user1 is not as expected");
        assertEq(USDTContract.balanceOf(entityAddr), payment1 + payment2, "Not expected USDT balance in the entity contract after the 2nd payment");
        vm.stopPrank();
    }

    // ———————————————————————————————————————— General Business ————————————————————————————————————————
}
