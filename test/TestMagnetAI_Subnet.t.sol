// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {TetherToken} from "../src/tokens/TetherToken08.sol";
import "../src/BotTokenFactory.sol";
import "../src/BotToken.sol";
import "../src/MagnetAI.sol";
import "./CommonFunctionsForTest.sol";

contract TestMagnetAI_Subnet is Test, CommonFunctionsForTest {
    address contractOwner = makeAddr("contractOwner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");

    TetherToken public USDTContract;
    address public USDTAddr;
    BotTokenFactory public factory;
    address public factoryAddr;
    MagnetAI public entity;
    address public entityAddr;

    function setUp() public {
        deal(contractOwner, 10000 ether);
        deal(user1, 10000 ether);
        deal(user2, 10000 ether);
        deal(user3, 10000 ether);
        deal(user4, 10000 ether);
        vm.startPrank(contractOwner);
        USDTContract = new TetherToken(3 * 10 ** 12, "Tether USD", "USDT", 6);
        USDTAddr = address(USDTContract);
        factory = new BotTokenFactory();
        factoryAddr = address(factory);
        entity = new MagnetAI(factoryAddr, USDTAddr);
        entityAddr = address(entity);
        factory.initialize(entityAddr);
        USDTContract.transfer(user1, 1 * 10 ** 12);
        USDTContract.transfer(user2, 1 * 10 ** 12);
        vm.stopPrank();
    }

    /**
     * @dev Test case(s) of the function {registerSubnet}
     */
    // Case 1: Regular call(by `contractOwner`). Expect success.
    function test_registerSubnet_ByContractOwner() public {
        // Inputs
        string memory subnetHandleInput = "Subnet ABC";
        string memory metadataInput = "Metadata of Subnet ABC";
        // Test
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataInput);
        (string memory subnetHandleFetched, address ownerFetched, string memory metadataFetched) = entity.subnets(subnetHandleInput);
        assertEq(subnetHandleFetched, subnetHandleInput, "The subnetHandle does not match the input one");
        assertEq(ownerFetched, contractOwner, "The owner of the subnet is not correct");
        assertEq(metadataFetched, metadataInput, "The metadata does not match the input one");
    }

    // Case 2: Called by a non-owner address of the contract {MagnetAI}. Expect revert.
    function test_registerSubnet_ByNonContractOwner() public {
        // Inputs
        string memory subnetHandleInput = "Subnet ABC";
        string memory metadataInput = "Metadata of Subnet ABC";
        // Test
        bytes memory expectedError = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1);
        vm.expectRevert(expectedError);
        _registerSubnet(entity, user1, subnetHandleInput, metadataInput);
    }

    // Case 3: Input `subnetHandle` has already existed. Expect revert.
    function test_registerSubnet_SubnetHandleHasExisted() public {
        // Inputs
        string memory subnetHandleInput1 = "Subnet ABC";
        string memory metadataInput1 = "The metadata1 of Subnet ABC";
        string memory subnetHandleInput2 = "Subnet ABC";
        string memory metadataInput2 = "The metadata2 of Subnet ABC";
        // Test
        _registerSubnet(entity, contractOwner, subnetHandleInput1, metadataInput1);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.SubnetHandleHasExisted.selector, subnetHandleInput2);
        vm.expectRevert(expectedError);
        _registerSubnet(entity, contractOwner, subnetHandleInput2, metadataInput2);        
    }

    // Case 4: Input `subnetHandle` is invalid in length check. Expect revert.
    function test_registerSubnet_InvalidLengthOfSubnetHandle() public {
        // Inputs
        string memory subnetHandleInput1 = "";   // length: 0
        string memory metadataInput1 = "The metadata of subnet";
        string memory subnetHandleInput2 = "subnetHandle_SooooooooooooooooooooooooLoooooooooooooooooooooooong";  // length: 65
        string memory metadataInput2 = "The metadata of subnet";
        // Test
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.InvalidSubnetHandle.selector);
        vm.expectRevert(expectedError);
        _registerSubnet(entity, contractOwner, subnetHandleInput1, metadataInput1);
        vm.expectRevert(expectedError);
        _registerSubnet(entity, contractOwner, subnetHandleInput2, metadataInput2); 
    }

    /**
     * @dev Test case(s) of the function {authorizeModelManager}
     */
    // Case 1: Regular call(by the subnet owner). Expect success.
    function test_authorizeModelManager_BySubnetOwner() public {
        // Inputs
        string memory subnetHandleInput = "Subnet ABC";
        string memory metadataInput = "Metadata of Subnet ABC";
        // Test
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataInput);
        _authorizeModelManager(entity, contractOwner, user1, subnetHandleInput);
        assertEq(entity.isAuthedModelManager(user1, subnetHandleInput), true);
    }

    // Case 2: Called by a non-owner address of the subnet owner. Expect revert.
    function test_authorizeModelManager_ByNonSubnetOwner() public {
        // Inputs
        string memory subnetHandleInput = "Subnet ABC";
        string memory metadataInput = "Metadata of Subnet ABC";
        // Test
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataInput);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.NotSubnetOwner.selector, user1, contractOwner);
        vm.expectRevert(expectedError);
        _authorizeModelManager(entity, user1, user1, subnetHandleInput);
    }

    // Case 3: Test the given value of the parameter `registrant` in the function {authorizeModelManager}. Expect success.
    /// forge-config: default.fuzz.runs = 10000
    function fuzzTest_authorizeModelManager_Registrant(address registrant) public {
        // Inputs
        string memory subnetHandleInput = "Subnet ABC";
        string memory metadataInput = "Metadata of Subnet ABC";
        // Test
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataInput);
        _authorizeModelManager(entity, contractOwner, registrant, subnetHandleInput);
        assertEq(entity.isAuthedModelManager(user1, subnetHandleInput), true);
    }

    // Case 4: Input `subnetHandle` is nonexistent. Expect revert.
    function test_authorizeModelManager_NonexistentSubnetHandle() public {
        // Inputs
        string memory subnetHandleInput = "Subnet ABC";
        string memory metadataInput = "Metadata of Subnet ABC";
        string memory nonexistentSubnetHandle = "Subnet DEF";
        // Test
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataInput);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.NotSubnetOwner.selector, contractOwner, address(0));
        vm.expectRevert(expectedError);
        _authorizeModelManager(entity, contractOwner, user1, nonexistentSubnetHandle);
    }

    /**
     * @dev Test case(s) of the function {checkExistenceOfSubnet}
     */
    // Case 1: Regular call. Expect success.
    function test_checkExistenceOfSubnet() public {
        // Initialization
        string memory subnetHandleInput = "Subnet ABC";
        string memory metadataInput = "Metadata of Subnet ABC";
        string memory nonexistentSubnetHandle = "Subnet DEF";
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataInput);
        // Test
        vm.startPrank(user1);
        bool resultOfExistentSubnet = entity.checkExistenceOfSubnet(subnetHandleInput);
        bool resultOfNonexistentSubnet = entity.checkExistenceOfSubnet(nonexistentSubnetHandle);
        assertEq(resultOfExistentSubnet, true);
        assertEq(resultOfNonexistentSubnet, false);
        vm.stopPrank();
    }

    /**
     * @dev Test case(s) of the function {checkSubnetHandleForRegistry}
     */
    // Case 1: Regular call. Expect success.
    function test_checkSubnetHandleForRegistry() public {
        // Inputs
        string memory subnetHandleInput1 = "Subnet ABC";
        string memory metadataInput1 = "Metadata of Subnet ABC";
        string memory subnetHandleInput2 = "Subnet DEF";
        string memory subnetHandleInput3 = "";  // length: 0
        string memory subnetHandleInput4 = "subnetHandle_SooooooooooooooooooooooooLoooooooooooooooooooooooong";  // length: 65
        // Test
        bool isAvailable;
        bool isValidInput;
        _registerSubnet(entity, contractOwner, subnetHandleInput1, metadataInput1);
        vm.startPrank(user1);
        (isAvailable, isValidInput) = entity.checkSubnetHandleForRegistry(subnetHandleInput1);
        assertEq(isAvailable, false);
        assertEq(isValidInput, true);
        (isAvailable, isValidInput) = entity.checkSubnetHandleForRegistry(subnetHandleInput2);
        assertEq(isAvailable, true);
        assertEq(isValidInput, true);
        (isAvailable, isValidInput) = entity.checkSubnetHandleForRegistry(subnetHandleInput3);
        assertEq(isAvailable, true);
        assertEq(isValidInput, false);
        (isAvailable, isValidInput) = entity.checkSubnetHandleForRegistry(subnetHandleInput4);
        assertEq(isAvailable, true);
        assertEq(isValidInput, false);
        vm.stopPrank();
    }

}
