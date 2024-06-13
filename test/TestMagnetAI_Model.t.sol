// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {TetherToken} from "../src/tokens/TetherToken08.sol";
import "../src/BotTokenFactory.sol";
import "../src/BotToken.sol";
import "../src/MagnetAI.sol";
import "./CommonFunctionsForTest.sol";

contract TestMagnetAI_Model is Test, CommonFunctionsForTest {
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
     * @dev Test case(s) of the function {registerModel}
     */
    // Case 1: Regular call(by `contractOwner`). Expect success.
    function test_registerModel_ByContractOwner() public {
        // Inputs
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory metadataInput = "The metadata of modelHandle_GPT4";
        uint256 priceInput = 1234567;
        // Test
        _registerModel(entity, contractOwner, modelHandleInput, metadataInput, priceInput);
        (string memory modelHandleFetched, address ownerFetched, string memory metadataFetched, uint256 priceFetched) =
            entity.models(modelHandleInput);
        assertEq(modelHandleFetched, modelHandleInput, "The modelHandle does not match the input one");
        assertEq(ownerFetched, contractOwner, "The owner of the model is not correct");
        assertEq(metadataFetched, metadataInput, "The metadata does not match the input one");
        assertEq(priceFetched, priceInput, "The price does not match the input one");
    }

    // Case 2: Called by a non-owner address of the contract {MagnetAI}. Expect revert.
    function test_registerModel_ByNonContractOwner() public {
        // Inputs
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory metadataInput = "The metadata of modelHandle_GPT4";
        uint256 priceInput = 1234567;
        // Test
        bytes memory expectedError = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1);
        vm.expectRevert(expectedError);
        _registerModel(entity, user1, modelHandleInput, metadataInput, priceInput);
    }

    // Case 3: Input `modelHandle` has already existed. Expect revert.
    function test_registerModel_ModelHandleHasExisted() public {
        // Inputs
        string memory modelHandleInput1 = "modelHandle_GPT4";
        string memory metadataInput1 = "The metadata1 of modelHandle_GPT4";
        uint256 priceInput1 = 1234567;
        string memory modelHandleInput2 = "modelHandle_GPT4";
        string memory metadataInput2 = "The metadata2 of modelHandle_GPT4";
        uint256 priceInput2 = 7654321;
        // Test
        _registerModel(entity, contractOwner, modelHandleInput1, metadataInput1, priceInput1);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.ModelHandleHasExisted.selector, modelHandleInput2);
        vm.expectRevert(expectedError);
        _registerModel(entity, contractOwner, modelHandleInput2, metadataInput2, priceInput2);
    }

    // Case 4: Input `modelHandle` is invalid in length check. Expect revert.
    function test_registerModel_InvalidLengthOfModelHandle() public {
        // Inputs
        string memory modelHandleInput1 = ""; // length: 0
        string memory metadataInput1 = "The metadata of model";
        uint256 priceInput1 = 1234567;
        string memory modelHandleInput2 = "modelHandle_SoooooooooooooooooooooooooLoooooooooooooooooooooooong"; // length: 65
        string memory metadataInput2 = "The metadata of model";
        uint256 priceInput2 = 1234567;
        // Test
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.InvalidModelHandle.selector);
        vm.expectRevert(expectedError);
        _registerModel(entity, contractOwner, modelHandleInput1, metadataInput1, priceInput1);
        vm.expectRevert(expectedError);
        _registerModel(entity, contractOwner, modelHandleInput2, metadataInput2, priceInput2);
    }

    // Case 5: Fuzz test the input value of the parameter `price`. Expect success.
    /// forge-config: default.fuzz.runs = 10000
    function testFuzz_registerModel_Price(uint256 priceInput) public {
        // Inputs
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory metadataInput = "The metadata of modelHandle_GPT4";
        // Test
        _registerModel(entity, contractOwner, modelHandleInput, metadataInput, priceInput);
        (string memory modelHandleFetched, address ownerFetched, string memory metadataFetched, uint256 priceFetched) =
            entity.models(modelHandleInput);
        assertEq(modelHandleFetched, modelHandleInput, "The modelHandle does not match the input one");
        assertEq(ownerFetched, contractOwner, "The owner of the model is not correct");
        assertEq(metadataFetched, metadataInput, "The metadata does not match the input one");
        assertEq(priceFetched, priceInput, "The price does not match the input one");
    }

    /**
     * @dev Test case(s) of the function {setModelPrice}
     */
    // Case 1: Called by a non-owner address of the model. Expect revert.
    function test_setModelPrice_ByNonModelOwner() public {
        // Initialization
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory metadataInput = "The metadata of modelHandle_GPT4";
        uint256 priceInput = 1234567;
        uint256 updatedPrice = 7654321;
        _registerModel(entity, contractOwner, modelHandleInput, metadataInput, priceInput);
        // Test
        vm.startPrank(user1);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.NotModelOwner.selector, user1, contractOwner);
        vm.expectRevert(expectedError);
        entity.setModelPrice(modelHandleInput, updatedPrice);
        vm.stopPrank();
    }

    // Case 2: Input `modelHandle` is nonexistent. Expect revert.
    function test_setModelPrice_NonexistentModelHandle() public {
        // Inputs
        string memory modelHandleInput = "modelHandle_GPT4";
        uint256 updatedPrice = 7654321;
        // Test
        vm.startPrank(contractOwner);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.NotModelOwner.selector, contractOwner, address(0));
        vm.expectRevert(expectedError);
        entity.setModelPrice(modelHandleInput, updatedPrice);
        vm.stopPrank();
    }

    // Case 3: Test the given value of the parameter `price` in the function {setModelPrice}. Expect success.
    /// forge-config: default.fuzz.runs = 10000
    function testFuzz_setModelPrice_ByModelOwner_Price(uint256 price) public {
        // Initialization
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory metadataInput = "The metadata of modelHandle_GPT4";
        uint256 priceInput = 1234567;
        _registerModel(entity, contractOwner, modelHandleInput, metadataInput, priceInput);
        // Test
        vm.startPrank(contractOwner);
        entity.setModelPrice(modelHandleInput, price);
        (,,, uint256 priceFetched) = entity.models(modelHandleInput);
        assertEq(priceFetched, price, "The current price does not equal the updated price");
        vm.stopPrank();
    }

    /**
     * @dev Test case(s) of the function {checkExistenceOfModel}
     */
    // Case 1: Regular call. Expect success.
    function test_checkExistenceOfModel() public {
        // Initialization
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory metadataInput = "The metadata of modelHandle_GPT4";
        uint256 priceInput = 1234567;
        string memory modelHandleNonexistent = "modelHandle_GPT4o";
        _registerModel(entity, contractOwner, modelHandleInput, metadataInput, priceInput);
        // Test
        vm.startPrank(user1);
        bool resultOfExistentModel = entity.checkExistenceOfModel(modelHandleInput);
        bool resultOfNonexistentModel = entity.checkExistenceOfModel(modelHandleNonexistent);
        assertEq(resultOfExistentModel, true);
        assertEq(resultOfNonexistentModel, false);
        vm.stopPrank();
    }

    /**
     * @dev Test case(s) of the function {checkModelHandleForRegistry}
     */
    // Case 1: Regular call. Expect success.
    function test_checkModelHandleForRegistry() public {
        // Inputs
        string memory modelHandleInput1 = "modelHandle_GPT4";
        string memory metadataInput1 = "The metadata1 of modelHandle_GPT4";
        uint256 priceInput1 = 1234567;
        string memory modelHandleInput2 = "modelHandle_GPT4o";
        string memory modelHandleInput3 = ""; // length: 0
        string memory modelHandleInput4 = "modelHandle_SoooooooooooooooooooooooooLoooooooooooooooooooooooong"; // length: 65
        // Test
        bool isAvailable;
        bool isValidInput;
        _registerModel(entity, contractOwner, modelHandleInput1, metadataInput1, priceInput1);
        vm.startPrank(user1);
        (isAvailable, isValidInput) = entity.checkModelHandleForRegistry(modelHandleInput1);
        assertEq(isAvailable, false);
        assertEq(isValidInput, true);
        (isAvailable, isValidInput) = entity.checkModelHandleForRegistry(modelHandleInput2);
        assertEq(isAvailable, true);
        assertEq(isValidInput, true);
        (isAvailable, isValidInput) = entity.checkModelHandleForRegistry(modelHandleInput3);
        assertEq(isAvailable, true);
        assertEq(isValidInput, false);
        (isAvailable, isValidInput) = entity.checkModelHandleForRegistry(modelHandleInput4);
        assertEq(isAvailable, true);
        assertEq(isValidInput, false);
        vm.stopPrank();
    }

}
