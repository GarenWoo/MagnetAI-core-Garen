// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import "../src/MagnetAI.sol";

contract TestMagnetAI is Test {
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    MagnetAI public entry;

    address public entryAddr;
    
    function setUp() public {
        deal(alice, 10000 ether);
        deal(bob, 10000 ether);
        vm.startPrank(alice);
        entry = new MagnetAI();
        entryAddr = address(entry);
        vm.stopPrank();
    }

    function test_registerModel() public {
        uint256 price = 112233;
        vm.startPrank(alice);
        entry.registerModel("abcd", price);
        MagnetAI.AIModel memory fetchedModel = entry.getModelInfo(0);
        assertEq(fetchedModel.modelId, 0, "Expect that the modelId equals 0");
        assertEq(fetchedModel.owner, alice, "Expect that the owner equals alice");
        assertEq(fetchedModel.metadata, "abcd", "Expect that the metadata equals 0xabcd");
        assertEq(fetchedModel.price, price, "Expect that the price equals 112233");
        vm.startPrank(bob);
        vm.expectRevert();
        entry.registerModel("fedc", price);
        vm.stopPrank();
    }

    function test_setModelPrice() public {
        vm.startPrank(alice);
        entry.registerModel("", 12345);
        MagnetAI.AIModel memory fetchedModel = entry.getModelInfo(0);
        console.log("the Price of model 0:", fetchedModel.price);
        entry.setModelPrice(0, 67890);
        fetchedModel = entry.getModelInfo(0);
        console.log("The new price of model 0:", fetchedModel.price);
        assertEq(fetchedModel.price, 67890, "Expect that the price of Model 0 is 67890");
        vm.startPrank(bob);
        vm.expectRevert();
        entry.setModelPrice(0, 998877);
        vm.stopPrank();
        
    }

    // function test_setModelOwner() public {
    //     vm.startPrank(alice);
    //     entry.registerModel("", 12345);
    //     MagnetAI.AIModel memory fetchedModel = entry.getModelInfo(0);
    //     console.log("owner of model 0:", fetchedModel.owner);
    //     assertEq(fetchedModel.owner, alice, "Expect that the owner of Model 0 is alice");
    //     entry.setModelOwner(0, bob);        
    //     fetchedModel = entry.getModelInfo(0);
    //     console.log("new owner of model 0:", fetchedModel.owner);
    //     vm.stopPrank();
    //     assertEq(fetchedModel.owner, bob, "Expect that the owner of Model 0 is bob");
    // }

    function test_registerSubnet() public {
        vm.startPrank(alice);
        entry.registerSubnet();
        MagnetAI.Subnet memory fetchedSubnet = entry.getSubnetInfo(0);
        assertEq(fetchedSubnet.subnetId, 0, "Expect that the subnetId equals 0");
        assertEq(fetchedSubnet.owner, alice, "Expect that the owner equals alice");
        vm.startPrank(bob);
        vm.expectRevert();
        entry.registerSubnet();
        vm.stopPrank();
    }

    // function test_setSubnetOwner() public {
    //     vm.startPrank(alice);
    //     entry.registerSubnet();
    //     MagnetAI.Subnet memory fetchedSubnet = entry.getSubnetInfo(0);
    //     console.log("owner of Subnet 0:", fetchedSubnet.owner);
    //     assertEq(fetchedSubnet.owner, alice, "Expect that the owner of Subnet 0 is alice");
    //     entry.setSubnetOwner(0, bob);        
    //     fetchedSubnet = entry.getSubnetInfo(0);
    //     console.log("new owner of Subnet 0:", fetchedSubnet.owner);
    //     vm.stopPrank();
    //     assertEq(fetchedSubnet.owner, bob, "Expect that the owner of Subnet 0 is bob");
    // }

    function test_registerModelManager() public {
        vm.startPrank(alice);
        entry.registerModel("", 12345);
        entry.registerSubnet();
        entry.registerModelManager(0, 0, "an api url");
        MagnetAI.ModelManager memory fetchedModelManager = entry.getModelManagerInfo(0);
        assertEq(fetchedModelManager.modelManagerId, 0, "Expect that the modelManagerId equals 0");
        assertEq(fetchedModelManager.subnetId, 0, "Expect that the subnetId equals 0");
        assertEq(fetchedModelManager.modelId, 0, "Expect that the modelId equals 0");
        assertEq(fetchedModelManager.owner, alice, "Expect that the owner equals alice");
        assertEq(fetchedModelManager.url, "an api url", "Expect that the url equals 'an api url'");
        vm.startPrank(bob);
        vm.expectRevert();
        entry.registerModelManager(0, 0, "an api url");
        vm.stopPrank();
    }

    function test_setModelManagerUrl() public {
        vm.startPrank(alice);
        entry.registerModel("", 12345);
        entry.registerSubnet();
        entry.registerModelManager(0, 0, "url123");
        entry.setModelManagerUrl(0, "url456");
        MagnetAI.ModelManager memory fetchedModelManager = entry.getModelManagerInfo(0);
        assertEq(fetchedModelManager.url, "url456", "Expect that the url is url456");
        vm.startPrank(bob);
        vm.expectRevert();
        entry.setModelManagerUrl(0, "url789");
        vm.stopPrank();
    }

    // function test_setModelManagerOwner() public {
    //     vm.startPrank(alice);
    //     entry.registerModel("", 12345);
    //     entry.registerSubnet();
    //     entry.registerModelManager(0, 0, "url123");
    //     vm.startPrank(bob);
    //     vm.expectRevert();
    //     entry.setModelManagerOwner(0, bob);
    //     vm.startPrank(alice);
    //     entry.setModelManagerOwner(0, bob);
    //     MagnetAI.ModelManager memory fetchedModelManager = entry.getModelManagerInfo(0);
    //     assertEq(fetchedModelManager.owner, bob, "Expect that the owner of ModelManager 0 is bob");
    //     vm.stopPrank();
    // }

    function test_createBot() public {
        uint256 price = 11223344;
        vm.startPrank(alice);
        entry.registerModel("", 12345);
        entry.registerSubnet();
        entry.registerModelManager(0, 0, "urlForModelManager0");
        entry.createBot(0, 0, "metadataForBot0", price);
        MagnetAI.Bot memory fetchedBot = entry.getBotInfo(0);
        assertEq(fetchedBot.botHandle, 0, "Expect that the botHandle is 0");
        assertEq(fetchedBot.modelManagerId, 0, "Expect that the modelManagerId is 0");
        assertEq(fetchedBot.metadata, "metadataForBot0", "Expect that the metadata is 'metadataForBot0'");
        assertEq(fetchedBot.price, price, "Expect that the price is 11223344");
        entry.registerModel("", 12345);
        entry.registerSubnet();
        entry.registerModelManager(1, 1, "urlForModelManager1");
        vm.startPrank(bob);
        vm.expectRevert();
        entry.createBot(0, 1, "metadataForBot1", price);
        vm.stopPrank();
    }

    function test_setBotPrice() public {
        uint256 originalPrice = 11223344;
        uint256 newPrice = 99998888;
        vm.startPrank(alice);
        entry.registerModel("", 12345);
        entry.registerSubnet();
        entry.registerModelManager(0, 0, "urlForModelManager0");
        entry.createBot(0, 0, "metadataForBot0", originalPrice);
        entry.setBotPrice(0, newPrice);
        MagnetAI.Bot memory fetchedBot = entry.getBotInfo(0);
        assertEq(fetchedBot.price, newPrice, "Expect that the price of the Bot is 99998888");
        vm.startPrank(bob);
        vm.expectRevert();
        entry.setBotPrice(0, newPrice);
        vm.stopPrank();
    }

    function test_followBot() public {
        vm.startPrank(alice);
        entry.registerModel("", 12345);
        entry.registerSubnet();
        entry.registerModelManager(0, 0, "urlForModelManager0");
        entry.createBot(0, 0, "metadataForBot0", 1122334455);
        entry.followBot(0);
        vm.stopPrank();
    }

    function test_payForBot() public {
        vm.startPrank(alice);
        entry.registerModel("", 12345);
        entry.registerSubnet();
        entry.registerModelManager(0, 0, "urlForModelManager0");
        entry.createBot(0, 0, "metadataForBot0", 1122334455);
        entry.payForBot{value: 123 ether}(0);
        assertEq(entry.userBalance(alice), 123 ether, "Expect that the balance of alice is 123 ether");
        assertEq(entryAddr.balance, 123 ether, "Expect that the total ETH balance of the contract is 123 ether");
        vm.startPrank(bob);
        entry.payForBot{value: 377 ether}(0);
        assertEq(entry.userBalance(bob), 377 ether, "Expect that the balance of alice is 123 ether");
        assertEq(entryAddr.balance, 500 ether, "Expect that the total ETH balance of the contract is 123 ether");
        vm.stopPrank();
    }

}
