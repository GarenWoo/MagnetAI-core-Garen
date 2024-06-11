// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {TetherToken} from "../src/tokens/TetherToken08.sol";
import "../src/BotTokenFactory.sol";
import "../src/BotToken.sol";
import "../src/MagnetAI.sol";
import "./CommonFunctionsForTest.sol";

contract TestMagnetAI_ModelManager is Test, CommonFunctionsForTest {
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

    // ————————————————————————————————————————------------------ Model Manager ————————————————————————————————————————------------------

    /**
     * @dev Test case(s) of the function {registerModelManager}
     */
    // Case 1: Regular call(by authorized address). Expect success.
    function test_registerModelManager_ByAuthorizedAddress() public {
        // Inputs
        string memory modelManagerIdInput = "MODELMANAGER0001";
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory subnetHandleInput = "Subnet ABC";
        string memory urlInput = "The url of MODELMANAGER0001";
        // Initialization
        string memory metadataOfModelInput = "The metadata of modelHandle_GPT4";
        uint256 priceInput = 1234567;
        _registerModel(entity, contractOwner, modelHandleInput, metadataOfModelInput, priceInput);
        string memory metadataOfSubnetInput = "Metadata of Subnet ABC";
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataOfSubnetInput);
        _authorizeModelManager(entity, contractOwner, user1, subnetHandleInput);
        // Test
        _registerModelManager(entity, user1, modelManagerIdInput, modelHandleInput, subnetHandleInput, urlInput);
        (
            string memory modelManagerIdFetched,
            string memory subnetHandleFetched,
            string memory modelHandleFetched,
            address ownerFetched,
            string memory urlFetched
        ) = entity.modelManagers(modelManagerIdInput);
        assertEq(modelManagerIdFetched, modelManagerIdInput, "The modelManagerId does not match the input one");
        assertEq(subnetHandleFetched, subnetHandleInput, "The subnetHandle does not match the input one");
        assertEq(modelHandleFetched, modelHandleInput, "The modelHandle does not match the input one");
        assertEq(ownerFetched, user1, "The owner of the modelManager is not correct");
        assertEq(urlFetched, urlInput, "The url does not match the input one");
    }

    // Case 2: Called by an unauthorized address. Expect revert.
    function test_registerModelManager_ByUnauthorizedAddress() public {
        // Inputs
        string memory modelManagerIdInput = "MODELMANAGER0001";
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory subnetHandleInput = "Subnet ABC";
        string memory urlInput = "The url of MODELMANAGER0001";
        // Initialization
        string memory metadataOfModelInput = "The metadata of modelHandle_GPT4";
        uint256 priceInput = 1234567;
        _registerModel(entity, contractOwner, modelHandleInput, metadataOfModelInput, priceInput);
        string memory metadataOfSubnetInput = "Metadata of Subnet ABC";
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataOfSubnetInput);
        // Test
        bytes memory expectedError =
            abi.encodeWithSelector(IMagnetAI.NotAuthorizedBySubnet.selector, user1, subnetHandleInput);
        vm.expectRevert(expectedError);
        _registerModelManager(entity, user1, modelManagerIdInput, modelHandleInput, subnetHandleInput, urlInput);
    }

    // Case 3: Input `modelManagerId` has already existed. Expect revert
    function test_registerModelManager_ModelManagerIdHasExisted() public {
        // Inputs
        string memory modelManagerIdInput1 = "MODELMANAGER0001";
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory subnetHandleInput = "Subnet ABC";
        string memory urlInput = "The url of MODELMANAGER0001";
        string memory modelManagerIdInput2 = "MODELMANAGER0001";
        // Initialization
        string memory metadataOfModelInput = "The metadata of modelHandle_GPT4";
        uint256 priceInput = 1234567;
        _registerModel(entity, contractOwner, modelHandleInput, metadataOfModelInput, priceInput);
        string memory metadataOfSubnetInput = "Metadata of Subnet ABC";
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataOfSubnetInput);
        _authorizeModelManager(entity, contractOwner, user1, subnetHandleInput);
        _registerModelManager(entity, user1, modelManagerIdInput1, modelHandleInput, subnetHandleInput, urlInput);
        // Test
        bytes memory expectedError =
            abi.encodeWithSelector(IMagnetAI.ModelManagerIdHasExisted.selector, modelManagerIdInput2);
        vm.expectRevert(expectedError);
        _registerModelManager(entity, user1, modelManagerIdInput2, modelHandleInput, subnetHandleInput, urlInput);
    }

    // Case 4: Input `modelManagerId` is invalid in length check. Expect revert.
    function test_registerModelManager_InvalidLengthOfModelManagerId() public {
        // Inputs
        string memory modelManagerIdInput1 = "MODELMANAGER001"; // length: 15
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory subnetHandleInput = "Subnet ABC";
        string memory urlInput = "The url of MODELMANAGER";
        string memory modelManagerIdInput2 = "MODELMANAGER00001"; // length: 17
        string memory modelManagerIdInput3 = ""; // length: 0
        // Initialization
        string memory metadataOfModelInput = "The metadata of modelHandle_GPT4";
        uint256 priceInput = 1234567;
        _registerModel(entity, contractOwner, modelHandleInput, metadataOfModelInput, priceInput);
        string memory metadataOfSubnetInput = "Metadata of Subnet ABC";
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataOfSubnetInput);
        _authorizeModelManager(entity, contractOwner, user1, subnetHandleInput);
        // Test
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.InvalidModelManagerId.selector);
        vm.expectRevert(expectedError);
        _registerModelManager(entity, user1, modelManagerIdInput1, modelHandleInput, subnetHandleInput, urlInput);
        vm.expectRevert(expectedError);
        _registerModelManager(entity, user1, modelManagerIdInput2, modelHandleInput, subnetHandleInput, urlInput);
        vm.expectRevert(expectedError);
        _registerModelManager(entity, user1, modelManagerIdInput3, modelHandleInput, subnetHandleInput, urlInput);
    }

    // Case 5: Input `modelManagerId` is invalid in character check. Expect revert.
    function test_registerModelManager_InvalidCharacterOfModelManagerId() public {
        // Inputs
        string memory modelManagerIdInput1 = "MODELMANAGER_001"; // Invalid character '_'
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory subnetHandleInput = "Subnet ABC";
        string memory urlInput = "The url of MODELMANAGER";
        string memory modelManagerIdInput2 = "MODELMANAGER@001"; // Invalid character '@'
        string memory modelManagerIdInput3 = "MODELMANAGER-001"; // Invalid character '-'
        string memory modelManagerIdInput4 = "MODELMANAGER.001"; // Invalid character '.'
        // Initialization
        string memory metadataOfModelInput = "The metadata of modelHandle_GPT4";
        uint256 priceInput = 1234567;
        _registerModel(entity, contractOwner, modelHandleInput, metadataOfModelInput, priceInput);
        string memory metadataOfSubnetInput = "Metadata of Subnet ABC";
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataOfSubnetInput);
        _authorizeModelManager(entity, contractOwner, user1, subnetHandleInput);
        // Test
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.InvalidModelManagerId.selector);
        vm.expectRevert(expectedError);
        _registerModelManager(entity, user1, modelManagerIdInput1, modelHandleInput, subnetHandleInput, urlInput);
        vm.expectRevert(expectedError);
        _registerModelManager(entity, user1, modelManagerIdInput2, modelHandleInput, subnetHandleInput, urlInput);
        vm.expectRevert(expectedError);
        _registerModelManager(entity, user1, modelManagerIdInput3, modelHandleInput, subnetHandleInput, urlInput);
        vm.expectRevert(expectedError);
        _registerModelManager(entity, user1, modelManagerIdInput4, modelHandleInput, subnetHandleInput, urlInput);
    }

    // Case 6: Input `modelHandle` is nonexistent. Expect revert.
    function test_registerModelManager_NonexistentModelHandle() public {
        // Inputs
        string memory modelManagerIdInput = "MODELMANAGER0001";
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory subnetHandleInput = "Subnet ABC";
        string memory urlInput = "The url of MODELMANAGER0001";
        // Initialization
        string memory metadataOfSubnetInput = "Metadata of Subnet ABC";
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataOfSubnetInput);
        _authorizeModelManager(entity, contractOwner, user1, subnetHandleInput);
        // Test
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.NonexistentModel.selector, modelHandleInput);
        vm.expectRevert(expectedError);
        _registerModelManager(entity, user1, modelManagerIdInput, modelHandleInput, subnetHandleInput, urlInput);
    }

    /**
     * @dev Test case(s) of the function {setModelManagerUrl}
     */
    // Case 1: Regular call(by the owner of the model manager). Expect success.
    function test_setModelManagerUrl_ByModelManagerOwner() public {
        // Inputs
        string memory modelManagerIdInput = "MODELMANAGER0001";
        string memory urlUpdated = "ModelManagerURL_Updated";
        // Initialization
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory subnetHandleInput = "Subnet ABC";
        string memory urlInput = "The url of MODELMANAGER0001";
        string memory metadataOfModelInput = "The metadata of modelHandle_GPT4";
        uint256 priceInput = 1234567;
        _registerModel(entity, contractOwner, modelHandleInput, metadataOfModelInput, priceInput);
        string memory metadataOfSubnetInput = "Metadata of Subnet ABC";
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataOfSubnetInput);
        _authorizeModelManager(entity, contractOwner, user1, subnetHandleInput);
        _registerModelManager(entity, user1, modelManagerIdInput, modelHandleInput, subnetHandleInput, urlInput);
        // Test
        vm.prank(user1);
        entity.setModelManagerUrl(modelManagerIdInput, urlUpdated);
        (,,,, string memory urlFetched) = entity.modelManagers(modelManagerIdInput);
        assertEq(urlFetched, urlUpdated, "The current url of the model manager does not successfully updated");
    }

    // Case 2: Called by a non-owner of the model manager. Expect revert.
    function test_setModelManagerUrl_ByNonModelManagerOwner() public {
        // Inputs
        string memory modelManagerIdInput = "MODELMANAGER0001";
        string memory urlUpdated = "ModelManagerURL_Updated";
        // Initialization
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory subnetHandleInput = "Subnet ABC";
        string memory urlInput = "The url of MODELMANAGER0001";
        string memory metadataOfModelInput = "The metadata of modelHandle_GPT4";
        uint256 priceInput = 1234567;
        _registerModel(entity, contractOwner, modelHandleInput, metadataOfModelInput, priceInput);
        string memory metadataOfSubnetInput = "Metadata of Subnet ABC";
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataOfSubnetInput);
        _authorizeModelManager(entity, contractOwner, user1, subnetHandleInput);
        _registerModelManager(entity, user1, modelManagerIdInput, modelHandleInput, subnetHandleInput, urlInput);
        // Test
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.NotModelManagerOwner.selector, user2, user1);
        vm.expectRevert(expectedError);
        vm.prank(user2);
        entity.setModelManagerUrl(modelManagerIdInput, urlUpdated);
    }

    /**
     * @dev Test case(s) of the function {submitServiceProof}
     */
    /**
     * Case 1: Regular call(by the owner of the model manager). Expect success.
     * Details are shown below:
     * Token has been issued: false
     * BotOwner is fixed: true
     * BotOwner is possible to equal `contractOwner`: false
     * `lengthOfServiceProof` is fixed: true
     */
    function test_submitServiceProof_ByModelManagerOwner() public {
        // Initialization and preparation of inputs
        string[] memory stringInputs = new string[](6);
        stringInputs[0] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[1] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[2] = "Subnet ABC"; // subnetHandleInput
        stringInputs[3] = "The url of MODELMANAGER0001"; // urlInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        uint256 lengthOfServiceProof = 500;
        address modelManagerOwner = user1;
        address botOwner = user2; // fixed
        vm.startPrank(contractOwner);
        entity.registerModel(stringInputs[1], stringInputs[4], 1234567654321);
        entity.registerSubnet(stringInputs[2], stringInputs[5]);
        entity.authorizeModelManager(modelManagerOwner, stringInputs[2]);
        vm.stopPrank();
        vm.prank(modelManagerOwner);
        entity.registerModelManager(stringInputs[0], stringInputs[1], stringInputs[2], stringInputs[3]);
        string[] memory botHandleArrayInput =
            _createMultipleBots(entity, botOwner, lengthOfServiceProof, stringInputs[0]);
        uint256[] memory workloadArrayInput = _generateUint32Array(true, lengthOfServiceProof);
        uint256[] memory callNumberArrayInput = _generateUint16Array(true, lengthOfServiceProof);
        uint256[][] memory valueInput = _generate2DUnit128Array(true, lengthOfServiceProof, 2);
        // Test
        uint256 randomIndex = _generateRandomUint(0, lengthOfServiceProof);
        string memory botHandleSampled = botHandleArrayInput[randomIndex];
        uint256[] memory dataBeforeSubmit = new uint256[](4);
        // `dataBeforeSubmit[0]` == workload before submitting service proof
        // `dataBeforeSubmit[1]` == callNumber before submitting service proof
        // `dataBeforeSubmit[2]` == reward[subnetOnwer] before submitting service proof
        // `dataBeforeSubmit[3]` == reward[botOwner] or botReward[botHandle] before submitting service proof
        (dataBeforeSubmit[0], dataBeforeSubmit[1]) = entity.botUsage(botHandleSampled);
        dataBeforeSubmit[2] = entity.reward(contractOwner);
        dataBeforeSubmit[3] = entity.createdBotTokens(botHandleSampled) == address(0)
            ? entity.reward(contractOwner)
            : entity.botReward(botHandleSampled);
        vm.prank(modelManagerOwner);
        entity.submitServiceProof(
            stringInputs[0], botHandleArrayInput, workloadArrayInput, callNumberArrayInput, valueInput
        );
        uint256 botRewardFetched = entity.createdBotTokens(botHandleSampled) == address(0)
            ? entity.reward(botOwner)
            : entity.botReward(botHandleSampled);
        (uint256 workloadFetched, uint256 callNumberFetched) = entity.botUsage(botHandleSampled);
        // Assertions
        assertEq(
            workloadFetched - dataBeforeSubmit[0],
            workloadArrayInput[randomIndex],
            "The workload does not match in the sampled service proof"
        );
        assertEq(
            callNumberFetched - dataBeforeSubmit[1],
            callNumberArrayInput[randomIndex],
            "The callNumber does not match in the sampled service proof"
        );
        // Sum up all the subnet reward
        uint256[] memory sumOfReward = new uint256[](2);
        for (uint256 n = 0; n < lengthOfServiceProof; n++) {
            sumOfReward[0] += valueInput[n][0];
        }
        // Sum up all the bot reward
        for (uint256 p = 0; p < lengthOfServiceProof; p++) {
            sumOfReward[1] += valueInput[p][1];
        }
        if (botOwner == contractOwner) {
            assertEq(
                entity.reward(botOwner) - dataBeforeSubmit[2],
                sumOfReward[0] + sumOfReward[1],
                "botOwner == contractOwner. The sum of the subnet reward and the bot reward does not match the change of the reward of contractOwner"
            );
        } else {
            assertEq(
                entity.reward(contractOwner) - dataBeforeSubmit[2],
                sumOfReward[0],
                "The subnet reward does not match in the sampled service proof"
            );
            assertEq(
                botRewardFetched - dataBeforeSubmit[3],
                sumOfReward[1],
                "The bot reward does not match in the sampled service proof"
            );
        }
    }

    /**
     * Case 2: Called by a non-owner of the model manager. Expect revert.
     * Details are shown below:
     * Token has been issued: false
     * BotOwner is fixed: true
     * BotOwner is possible to equal `contractOwner`: false
     * `lengthOfServiceProof` is fixed: true
     */
    function test_submitServiceProof_ByNonModelManagerOwner() public {
        // Roles
        address caller1 = user2;
        address caller2 = user3;
        address modelManagerOwner = user1;
        address botOwner = user2; // fixed
        // Initialization and preparation of inputs
        string[] memory stringInputs = new string[](6);
        stringInputs[0] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[1] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[2] = "Subnet ABC"; // subnetHandleInput
        stringInputs[3] = "The url of MODELMANAGER0001"; // urlInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        uint256 lengthOfServiceProof = 100;
        vm.startPrank(contractOwner);
        entity.registerModel(stringInputs[1], stringInputs[4], 1234567654321);
        entity.registerSubnet(stringInputs[2], stringInputs[5]);
        entity.authorizeModelManager(modelManagerOwner, stringInputs[2]);
        vm.stopPrank();
        vm.prank(modelManagerOwner);
        entity.registerModelManager(stringInputs[0], stringInputs[1], stringInputs[2], stringInputs[3]);
        string[] memory botHandleArrayInput =
            _createMultipleBots(entity, botOwner, lengthOfServiceProof, stringInputs[0]);
        uint256[] memory workloadArrayInput = _generateUint32Array(true, lengthOfServiceProof);
        uint256[] memory callNumberArrayInput = _generateUint16Array(true, lengthOfServiceProof);
        uint256[][] memory valueInput = _generate2DUnit128Array(true, lengthOfServiceProof, 2);
        // Test
        vm.prank(caller1);
        bytes memory expectedError =
            abi.encodeWithSelector(IMagnetAI.NotModelManagerOwner.selector, caller1, modelManagerOwner);
        vm.expectRevert(expectedError);
        entity.submitServiceProof(
            stringInputs[0], botHandleArrayInput, workloadArrayInput, callNumberArrayInput, valueInput
        );
        vm.prank(caller2);
        expectedError = abi.encodeWithSelector(IMagnetAI.NotModelManagerOwner.selector, caller2, modelManagerOwner);
        vm.expectRevert(expectedError);
        entity.submitServiceProof(
            stringInputs[0], botHandleArrayInput, workloadArrayInput, callNumberArrayInput, valueInput
        );
    }

    /**
     * Case 3: Input `modelManagerId` is nonexistent. Expect revert.
     * Details are shown below:
     * Token has been issued: false
     * BotOwner is fixed: true
     * BotOwner is possible to equal `contractOwner`: false
     * `lengthOfServiceProof` is fixed: true
     */
    function test_submitServiceProof_NonexistentModelManagerId() public {
        // Roles
        address caller = user3;
        address modelManagerOwner = user1;
        address botOwner = user2; // fixed
        // Initialization and preparation of inputs
        string[] memory stringInputs = new string[](6);
        stringInputs[0] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[1] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[2] = "Subnet ABC"; // subnetHandleInput
        stringInputs[3] = "The url of MODELMANAGER0001"; // urlInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        uint256 lengthOfServiceProof = 100;
        vm.startPrank(contractOwner);
        entity.registerModel(stringInputs[1], stringInputs[4], 1234567654321);
        entity.registerSubnet(stringInputs[2], stringInputs[5]);
        entity.authorizeModelManager(modelManagerOwner, stringInputs[2]);
        vm.stopPrank();
        vm.prank(modelManagerOwner);
        entity.registerModelManager(stringInputs[0], stringInputs[1], stringInputs[2], stringInputs[3]);
        string[] memory botHandleArrayInput =
            _createMultipleBots(entity, botOwner, lengthOfServiceProof, stringInputs[0]);
        uint256[] memory workloadArrayInput = _generateUint32Array(true, lengthOfServiceProof);
        uint256[] memory callNumberArrayInput = _generateUint16Array(true, lengthOfServiceProof);
        uint256[][] memory valueInput = _generate2DUnit128Array(true, lengthOfServiceProof, 2);
        // Test
        string memory nonexistentModelManagerId = "MODELMANAGER0002";
        vm.prank(caller);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.NotModelManagerOwner.selector, caller, address(0));
        vm.expectRevert(expectedError);
        entity.submitServiceProof(
            nonexistentModelManagerId, botHandleArrayInput, workloadArrayInput, callNumberArrayInput, valueInput
        );
    }

    /**
     * Case 4: The length of any array in service proof is unmatched(but not equal to zero). Expect revert.
     * Details are shown below:
     * Token has been issued: false
     * BotOwner is fixed: true
     * BotOwner is possible to equal `contractOwner`: false
     * `lengthOfServiceProof` is fixed: false
     */
    /// forge-config: default.fuzz.runs = 50
    function testFuzz_submitServiceProof_UnmatchedLengthOfArrays(
        uint256 lengthOfBotHandles,
        uint256 lengthOfWorkloads,
        uint256 lengthOfCallNumbers,
        uint256 lengthOfValues
    ) public {
        // Assumptions
        vm.assume(lengthOfBotHandles <= 500 && lengthOfWorkloads <= 500 && lengthOfCallNumbers <= 500 && lengthOfValues <= 500);
        vm.assume(lengthOfBotHandles * lengthOfWorkloads * lengthOfCallNumbers * lengthOfValues != 0);
        vm.assume(
            !(
                lengthOfBotHandles == lengthOfWorkloads && lengthOfWorkloads == lengthOfCallNumbers
                    && lengthOfCallNumbers == lengthOfValues
            )
        );
        // Roles
        address botOwner = user2; // fixed
        // Initialization and preparation of inputs
        string[] memory stringInputs = new string[](6);
        stringInputs[0] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[1] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[2] = "Subnet ABC"; // subnetHandleInput
        stringInputs[3] = "The url of MODELMANAGER0001"; // urlInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        vm.startPrank(contractOwner);
        entity.registerModel(stringInputs[1], stringInputs[4], 1234567654321);
        entity.registerSubnet(stringInputs[2], stringInputs[5]);
        entity.authorizeModelManager(user1, stringInputs[2]);
        vm.stopPrank();
        vm.prank(user1);
        entity.registerModelManager(stringInputs[0], stringInputs[1], stringInputs[2], stringInputs[3]);
        string[] memory botHandleArrayInput = _createMultipleBots(entity, botOwner, lengthOfBotHandles, stringInputs[0]);
        uint256[] memory workloadArrayInput = _generateUint32Array(true, lengthOfWorkloads);
        uint256[] memory callNumberArrayInput = _generateUint16Array(true, lengthOfCallNumbers);
        uint256[][] memory valueInput = _generate2DUnit128Array(true, lengthOfValues, 2);
        // Test
        uint256[] memory lengthArray = new uint256[](4);
        lengthArray[0] = lengthOfBotHandles;
        lengthArray[1] = lengthOfWorkloads;
        lengthArray[2] = lengthOfCallNumbers;
        lengthArray[3] = lengthOfValues;
        uint256 randomIndex = _generateRandomUint(1, _deriveMin(lengthArray)) - 1;
        string memory botHandleSampled = botHandleArrayInput[randomIndex];
        uint256[] memory dataBeforeSubmit = new uint256[](4);
        // `dataBeforeSubmit[0]` == workload before submitting service proof
        // `dataBeforeSubmit[1]` == callNumber before submitting service proof
        // `dataBeforeSubmit[2]` == reward[subnetOnwer] before submitting service proof
        // `dataBeforeSubmit[3]` == reward[botOwner] or botReward[botHandle] before submitting service proof
        (dataBeforeSubmit[0], dataBeforeSubmit[1]) = entity.botUsage(botHandleSampled);
        dataBeforeSubmit[2] = entity.reward(contractOwner);
        dataBeforeSubmit[3] = entity.createdBotTokens(botHandleSampled) == address(0)
            ? entity.reward(contractOwner)
            : entity.botReward(botHandleSampled);
        bytes memory expectedError;
        vm.prank(user1);
        expectedError = abi.encodeWithSelector(
            IMagnetAI.InvalidProof.selector, lengthOfBotHandles, lengthOfWorkloads, lengthOfCallNumbers, lengthOfValues
        );
        vm.expectRevert(expectedError);
        entity.submitServiceProof(
            stringInputs[0], botHandleArrayInput, workloadArrayInput, callNumberArrayInput, valueInput
        );
    }

    /**
     * Case 5: The length of any array in service proof with zero-length. Expect revert.
     * Details are shown below:
     * Token has been issued: false
     * BotOwner is fixed: true
     * BotOwner is possible to equal `contractOwner`: false
     * `lengthOfServiceProof` is fixed: false
     */
    /// forge-config: default.fuzz.runs = 50
    function testFuzz_submitServiceProof_ZeroLengthOfArrays(
        uint256 lengthOfWorkloads,
        uint256 lengthOfCallNumbers,
        uint256 lengthOfValues
    ) public {
        // Assumptions
        // Assume that `lengthOfBotHandles` is not equal to 1.
        uint256 lengthOfBotHandles = 1;
        vm.assume(lengthOfWorkloads >= 0 && lengthOfWorkloads <= 1);
        vm.assume(lengthOfCallNumbers >= 0 && lengthOfCallNumbers <= 1);
        vm.assume(lengthOfValues >= 0 && lengthOfValues <= 1);
        vm.assume(lengthOfWorkloads * lengthOfCallNumbers * lengthOfValues == 0);
        // Roles
        address botOwner = user2; // fixed
        // Initialization and preparation of inputs
        string[] memory stringInputs = new string[](6);
        stringInputs[0] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[1] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[2] = "Subnet ABC"; // subnetHandleInput
        stringInputs[3] = "The url of MODELMANAGER0001"; // urlInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        vm.startPrank(contractOwner);
        entity.registerModel(stringInputs[1], stringInputs[4], 1234567654321);
        entity.registerSubnet(stringInputs[2], stringInputs[5]);
        entity.authorizeModelManager(user1, stringInputs[2]);
        vm.stopPrank();
        vm.prank(user1);
        entity.registerModelManager(stringInputs[0], stringInputs[1], stringInputs[2], stringInputs[3]);
        string[] memory botHandleArrayInput = _createMultipleBots(entity, botOwner, lengthOfBotHandles, stringInputs[0]);
        uint256[] memory workloadArrayInput = _generateUint32Array(true, lengthOfWorkloads);
        uint256[] memory callNumberArrayInput = _generateUint16Array(true, lengthOfCallNumbers);
        uint256[][] memory valueInput = _generate2DUnit128Array(true, lengthOfValues, 2);
        // Test
        uint256[] memory lengthArray = new uint256[](4);
        lengthArray[0] = lengthOfBotHandles;
        lengthArray[1] = lengthOfWorkloads;
        lengthArray[2] = lengthOfCallNumbers;
        lengthArray[3] = lengthOfValues;
        // `botHandleArrayInput` only has one element, because `lengthOfBotHandles` equals 1
        string memory botHandleSampled = botHandleArrayInput[0];
        uint256[] memory dataBeforeSubmit = new uint256[](4);
        // `dataBeforeSubmit[0]` == workload before submitting service proof
        // `dataBeforeSubmit[1]` == callNumber before submitting service proof
        // `dataBeforeSubmit[2]` == reward[subnetOnwer] before submitting service proof
        // `dataBeforeSubmit[3]` == reward[botOwner] or botReward[botHandle] before submitting service proof
        (dataBeforeSubmit[0], dataBeforeSubmit[1]) = entity.botUsage(botHandleSampled);
        dataBeforeSubmit[2] = entity.reward(contractOwner);
        dataBeforeSubmit[3] = entity.createdBotTokens(botHandleSampled) == address(0)
            ? entity.reward(contractOwner)
            : entity.botReward(botHandleSampled);
        bytes memory expectedError;
        vm.prank(user1);
        expectedError = abi.encodeWithSelector(
            IMagnetAI.InvalidProof.selector, lengthOfBotHandles, lengthOfWorkloads, lengthOfCallNumbers, lengthOfValues
        );
        vm.expectRevert(expectedError);
        entity.submitServiceProof(
            stringInputs[0], botHandleArrayInput, workloadArrayInput, callNumberArrayInput, valueInput
        );
    }

    /**
     * @dev Test case(s) of the function {getModelManagerOwner}
     */
    // Case 1: Regular call. Expect success.
    function test_getModelManagerOwner_ExistentModelManager() public {
        // Inputs
        string memory modelManagerIdInput = "MODELMANAGER0001";
        // Initialization
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory subnetHandleInput = "Subnet ABC";
        string memory urlInput = "The url of MODELMANAGER0001";
        string memory metadataOfModelInput = "The metadata of modelHandle_GPT4";
        uint256 priceInput = 1234567;
        _registerModel(entity, contractOwner, modelHandleInput, metadataOfModelInput, priceInput);
        string memory metadataOfSubnetInput = "Metadata of Subnet ABC";
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataOfSubnetInput);
        _authorizeModelManager(entity, contractOwner, user1, subnetHandleInput);
        _registerModelManager(entity, user1, modelManagerIdInput, modelHandleInput, subnetHandleInput, urlInput);
        // Test
        vm.prank(user2);
        address result = entity.getModelManagerOwner(modelManagerIdInput);
        assertEq(result, user1, "The owner of the model manager does not match the expected one");
    }

    // Case 2: Call with a nonexistent `modelManagerId`. Expect revert.
    function test_getModelManagerOwner_NonexistentModelManager() public {
        // Inputs
        string memory modelManagerIdInput = "MODELMANAGER0001";
        string memory modelManagerIdNonexistent = "MODELMANAGER0002";
        // Initialization
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory subnetHandleInput = "Subnet ABC";
        string memory urlInput = "The url of MODELMANAGER0001";
        string memory metadataOfModelInput = "The metadata of modelHandle_GPT4";
        uint256 priceInput = 1234567;
        _registerModel(entity, contractOwner, modelHandleInput, metadataOfModelInput, priceInput);
        string memory metadataOfSubnetInput = "Metadata of Subnet ABC";
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataOfSubnetInput);
        _authorizeModelManager(entity, contractOwner, user1, subnetHandleInput);
        _registerModelManager(entity, user1, modelManagerIdInput, modelHandleInput, subnetHandleInput, urlInput);
        // Test
        vm.prank(user2);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.NonexistentModelManager.selector, modelManagerIdNonexistent);
        vm.expectRevert(expectedError);
        entity.getModelManagerOwner(modelManagerIdNonexistent);
    }

    /**
     * @dev Test case(s) of the function {checkExistenceOfModelManager}
     */
    // Case 1: Regular call. Expect success.
    function test_checkExistenceOfModelManager() public {
        // Inputs
        string memory modelManagerIdInput = "MODELMANAGER0001";
        string memory modelManagerIdNonexistent = "MODELMANAGER0002";
        // Initialization
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory subnetHandleInput = "Subnet ABC";
        string memory urlInput = "The url of MODELMANAGER0001";
        string memory metadataOfModelInput = "The metadata of modelHandle_GPT4";
        uint256 priceInput = 1234567;
        _registerModel(entity, contractOwner, modelHandleInput, metadataOfModelInput, priceInput);
        string memory metadataOfSubnetInput = "Metadata of Subnet ABC";
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataOfSubnetInput);
        _authorizeModelManager(entity, contractOwner, user1, subnetHandleInput);
        _registerModelManager(entity, user1, modelManagerIdInput, modelHandleInput, subnetHandleInput, urlInput);
        // Test
        vm.startPrank(user2);
        bool isExisted = entity.checkExistenceOfModelManager(modelManagerIdInput);
        assertEq(isExisted, true, "The model manager is expected to be existent");
        isExisted = entity.checkExistenceOfModelManager(modelManagerIdNonexistent);
        assertEq(isExisted, false, "The model manager is expected to be nonexistent");
        vm.stopPrank();
    }

    /**
     * @dev Test case(s) of the function {checkModelManagerIdForRegistry}
     */
    // Case 1: Regular call. Expect success.
    function test_checkModelManagerIdForRegistry_ExistentModelManager() public {
        // Inputs
        string memory modelManagerIdInput1 = "MODELMANAGER0001";
        string memory modelManagerIdInput2 = "MODELMANAGER0002";
        string memory modelManagerIdInput3 = "";
        string memory modelManagerIdInput4 = "MODELMANAGERSOLONG";  // Length: 18
        string memory modelManagerIdInput5 = "MODELMANAGERabcd";  // Including lower case characters
        string memory modelManagerIdInput6 = "MODELMANAGER_001";  // Including invalid characters
        // Initialization
        string memory modelHandleInput = "modelHandle_GPT4";
        string memory subnetHandleInput = "Subnet ABC";
        string memory urlInput = "The url of MODELMANAGER0001";
        string memory metadataOfModelInput = "The metadata of modelHandle_GPT4";
        uint256 priceInput = 1234567;
        _registerModel(entity, contractOwner, modelHandleInput, metadataOfModelInput, priceInput);
        string memory metadataOfSubnetInput = "Metadata of Subnet ABC";
        _registerSubnet(entity, contractOwner, subnetHandleInput, metadataOfSubnetInput);
        _authorizeModelManager(entity, contractOwner, user1, subnetHandleInput);
        _registerModelManager(entity, user1, modelManagerIdInput1, modelHandleInput, subnetHandleInput, urlInput);
        // Test
        bool isAvailable;
        bool isValidInput;
        vm.startPrank(user2);
        (isAvailable, isValidInput) = entity.checkModelManagerIdForRegistry(modelManagerIdInput1);
        assertEq(isAvailable, false);
        assertEq(isValidInput, true);
        (isAvailable, isValidInput) = entity.checkModelManagerIdForRegistry(modelManagerIdInput2);
        assertEq(isAvailable, true);
        assertEq(isValidInput, true);
        (isAvailable, isValidInput) = entity.checkModelManagerIdForRegistry(modelManagerIdInput3);
        assertEq(isAvailable, true);
        assertEq(isValidInput, false);
        (isAvailable, isValidInput) = entity.checkModelManagerIdForRegistry(modelManagerIdInput4);
        assertEq(isAvailable, true);
        assertEq(isValidInput, false);
        (isAvailable, isValidInput) = entity.checkModelManagerIdForRegistry(modelManagerIdInput5);
        assertEq(isAvailable, true);
        assertEq(isValidInput, false);
        (isAvailable, isValidInput) = entity.checkModelManagerIdForRegistry(modelManagerIdInput6);
        assertEq(isAvailable, true);
        assertEq(isValidInput, false);
        vm.stopPrank();
    }
    
}