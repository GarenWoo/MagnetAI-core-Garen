// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {TetherToken} from "../src/tokens/TetherToken08.sol";
import "../src/BotTokenFactory.sol";
import "../src/BotToken.sol";
import "../src/MagnetAI.sol";
import "./CommonFunctionsForTest.sol";

contract TestMagnetAI_General is Test, CommonFunctionsForTest {
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
        deal(contractOwner, 100000 ether);
        deal(user1, 100000 ether);
        deal(user2, 100000 ether);
        deal(user3, 100000 ether);
        deal(user4, 100000 ether);
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
     * @dev Test case(s) of the function {claimReward}
     */
    // Case 1: Regular call. Expect success.
    function test_claimReward_BotTokenUncreated() public {
        // Initialization and preparation of inputs
        string[] memory stringInputs = new string[](6);
        stringInputs[0] = "MODELMANAGER0001"; // modelManagerIdInput
        stringInputs[1] = "modelHandle_GPT4"; // modelHandleInput
        stringInputs[2] = "Subnet ABC"; // subnetHandleInput
        stringInputs[3] = "The url of MODELMANAGER0001"; // urlInput
        stringInputs[4] = "The metadata of modelHandle_GPT4"; // metadataOfModelInput
        stringInputs[5] = "Metadata of Subnet ABC"; // metadataOfSubnetInput
        uint256 lengthOfServiceProof = 200;
        address botOwner = user2; // fixed
        vm.startPrank(contractOwner);
        entity.registerModel(stringInputs[1], stringInputs[4], 1234567654321);
        entity.registerSubnet(stringInputs[2], stringInputs[5]);
        entity.authorizeModelManager(user1, stringInputs[2]);
        vm.stopPrank();
        vm.prank(user1);
        entity.registerModelManager(stringInputs[0], stringInputs[1], stringInputs[2], stringInputs[3]);
        string[] memory botHandleArrayInput =
            _createMultipleBots(entity, botOwner, lengthOfServiceProof, stringInputs[0]);
        uint256[] memory workloadArrayInput = _generateUint32Array(true, lengthOfServiceProof);
        uint256[] memory callNumberArrayInput = _generateUint16Array(true, lengthOfServiceProof);
        uint256[][] memory valueInput = _generate2DUnit128Array(true, lengthOfServiceProof, 2);
        string memory botHandleSampled = botHandleArrayInput[_generateRandomUint(0, lengthOfServiceProof)];
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
        vm.prank(user1);
        entity.submitServiceProof(
            stringInputs[0], botHandleArrayInput, workloadArrayInput, callNumberArrayInput, valueInput
        );
        // Sum up rewards
        uint256[] memory sumOfReward = new uint256[](2);
        for (uint256 n = 0; n < lengthOfServiceProof; n++) {
            sumOfReward[0] += valueInput[n][0];
        }
        for (uint256 p = 0; p < lengthOfServiceProof; p++) {
            sumOfReward[1] += valueInput[p][1];
        }
        uint256 totalRewardOfUser = botOwner == contractOwner ? sumOfReward[0] + sumOfReward[1] : sumOfReward[1];
        deal(entityAddr, totalRewardOfUser); // Set the ETH balance of `entityAddr`
        // Test
        uint256 RewardBeforeClaim = entity.reward(botOwner);
        uint256 ETHBalanceBeforeClaim = botOwner.balance;
        vm.prank(botOwner);
        entity.claimReward();
        assertEq(entity.reward(botOwner), 0, "The reward should be reset to be 0 after the claim");
        assertEq(
            RewardBeforeClaim,
            botOwner.balance - ETHBalanceBeforeClaim,
            "The reward change does not match the change of ETH balance"
        );
    }

    // Case 2: The reward of `msg.sender` is zero. Expect revert.
    function test_claimReward_ZeroReward() public {
        address claimant = user1;
        vm.prank(claimant);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.InsufficientReward.selector, claimant);
        vm.expectRevert(expectedError);
        entity.claimReward();
    }

    /**
     * @dev Test case(s) of the function {claimReward}
     */
    // Case 1: Regular call(by authorized user). Expect success.
    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_updateUserData_ByAuthorizedUser(uint256 seed) public {
        // Assumption(s)
        vm.assume(seed > 0 && seed <= 2000);
        // Inputs
        address[] memory users = _generateUniqueAddressArray(seed);
        uint256[] memory data = _generateUint256Array(true, seed);
        address updater = user1;
        // Test
        vm.prank(contractOwner);
        entity.manageReporter(updater, true);
        vm.prank(updater);
        entity.updateUserData(users, data);
    }

    // Case 2: Called by unauthorized user. Expect revert.
    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_updateUserData_ByUnauthorizedUser(uint256 seed) public {
        // Assumption(s)
        vm.assume(seed > 0 && seed <= 2000);
        // Inputs
        address[] memory users = _generateUniqueAddressArray(seed);
        uint256[] memory data = _generateUint256Array(true, seed);
        address updater = user1;
        // Test
        vm.prank(updater);
        bytes memory expectedError = abi.encodeWithSelector(IMagnetAI.NotAuthorizedByOwner.selector, updater);
        vm.expectRevert(expectedError);
        entity.updateUserData(users, data);
    }

    // Case 3: The length of the given arrays does not match. Expect revert.
    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_updateUserData_UnmatchedArrays(uint256 lengthOfUsers, uint256 lengthOfData) public {
        // Assumption(s)
        vm.assume(
            lengthOfUsers <= 2000 && lengthOfData <= 2000 && lengthOfUsers * lengthOfData > 0
                && lengthOfUsers != lengthOfData
        );
        // Inputs
        address[] memory users = _generateUniqueAddressArray(lengthOfUsers);
        uint256[] memory data = _generateUint256Array(true, lengthOfData);
        address updater = user1;
        // Test
        vm.prank(contractOwner);
        entity.manageReporter(updater, true);
        vm.prank(updater);
        bytes memory expectedError =
            abi.encodeWithSelector(IMagnetAI.InvalidUpdateOfUserData.selector, lengthOfUsers, lengthOfData);
        vm.expectRevert(expectedError);
        entity.updateUserData(users, data);
    }

    // Case 4: One of the given array is zero-length. Expect revert.
    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_updateUserData_ZeroLengthOfArray(uint256 seed) public {
        // Assumption(s)
        vm.assume(seed > 0 && seed <= 2000);
        // Inputs
        address[] memory users = _generateUniqueAddressArray(0);
        uint256[] memory data = _generateUint256Array(true, seed);
        address updater = user1;
        // Test
        vm.prank(contractOwner);
        entity.manageReporter(updater, true);
        vm.prank(updater);
        bytes memory expectedError =
            abi.encodeWithSelector(IMagnetAI.InvalidUpdateOfUserData.selector, 0, seed);
        vm.expectRevert(expectedError);
        entity.updateUserData(users, data);
    }

    // {manageReporter} has already tested in the above 3 functions(i.e. case 1, case 3 and case 4 of {updateUserData}). Hence, omit test case of it.
    
    /**
     * @dev Test case(s) of the function {addSupportedToken}
     */
    // Case 1: Regular call(by the contract owner). Expect success.
    /// forge-config: default.fuzz.runs = 50000
    function testFuzz_addSupportedToken_ByContractOwner(address tokenToBeAdded) public {
        // Assumption(s)
        vm.assume(tokenToBeAdded != address(0));
        // Test
        vm.prank(contractOwner);
        entity.addSupportedToken(tokenToBeAdded);
        uint256 indexFetched = entity.indexOfSupportedToken(tokenToBeAdded);
        assertEq(indexFetched, 1, "The index of the added token does not match the fetched one");
    }

    // Case 2: Add a duplicated token. Expect revert.
    /// forge-config: default.fuzz.runs = 50000
    function testFuzz_addSupportedToken_AddDuplicatedToken(address tokenToBeAdded) public {
        // Assumption(s)
        vm.assume(tokenToBeAdded != address(0));
        // Initialization
        vm.startPrank(contractOwner);
        entity.addSupportedToken(tokenToBeAdded);        
        // Test
        uint256 indexOfToken = entity.indexOfSupportedToken(tokenToBeAdded);
        bytes memory expectedError =
            abi.encodeWithSelector(IMagnetAI.DuplicateTokenAdded.selector, tokenToBeAdded, indexOfToken);
        vm.expectRevert(expectedError);
        entity.addSupportedToken(tokenToBeAdded);
        vm.stopPrank();
    }

    // Case 3: Called by a non-owner of the contract. Expect revert.
    function test_addSupportedToken_ByNonContractOwner() public {
        address tokenToBeAdded = address(1);    // non-address(0)
        // Test
        address caller = user1;
        vm.prank(caller);
        bytes memory expectedError =
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller);
        vm.expectRevert(expectedError);
        entity.addSupportedToken(tokenToBeAdded);
    }

    /**
     * @dev Test case(s) of the function {removeSupportedToken}
     */
    // Case 1: Regular call(by the contract owner). Expect success.
    /// forge-config: default.fuzz.runs = 5000
    function testFuzz_removeSupportedToken_ByContractOwner(uint256 length) public {
        // Assumption(s)
        vm.assume(length > 0 && length <= 100);
        address[] memory tokens = new address[](length);
        // Test
        vm.startPrank(contractOwner);
        for (uint i = 0; i < length; i++) {
            tokens[i] = address(uint160(uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())))));
            entity.addSupportedToken(tokens[i]);
        }
        uint256 randomIndex = length == 1 ? 1 : _generateRandomUint(1, length - 1);
        address tokenToBeRemoved = entity.supportedTokens(randomIndex);
        entity.removeSupportedToken(tokenToBeRemoved);
        uint256 indexFetched = entity.indexOfSupportedToken(tokenToBeRemoved);
        assertEq(indexFetched, 0, "The index of the removed token does not equal zero");
        vm.stopPrank();
    }

    // Case 2: Attempt to remove a unsupported token. Expect revert.
    /// forge-config: default.fuzz.runs = 5000
    function testFuzz_removeSupportedToken_RemoveUnsupportedToken(address token) public {
        // Assumption(s)
        vm.assume(token != address(0));
        // Test
        vm.prank(contractOwner);
        bytes memory expectedError =
            abi.encodeWithSelector(IMagnetAI.UnsupportedToken.selector, token);
        vm.expectRevert(expectedError);
        entity.removeSupportedToken(token);
    }


    // Case 3: Called by a non-owner of the contract. Expect revert.
    function test_removeSupportedToken_ByNonContractOwner() public {
        address token = address(1);
        vm.prank(contractOwner);
        entity.addSupportedToken(token);
        // Test
        address caller = user1;
        vm.prank(caller);
        bytes memory expectedError =
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller);
        vm.expectRevert(expectedError);
        entity.removeSupportedToken(token);
    }

    /**
     * @dev Test case(s) of the function {checkSupportOfToken}
     */
    // Case 1: Regular call. Expect success.
    /// forge-config: default.fuzz.runs = 50000
    function testFuzz_checkSupportOfToken(address token1, address token2) public {
        // Assumption(s)
        vm.assume(token1 != address(0) && token2 != address(0) && token1 != token2);
        // Test
        vm.prank(contractOwner);
        entity.addSupportedToken(token1);
        vm.startPrank(user1);
        bool result = entity.checkSupportOfToken(token1);
        assertEq(result, true, "The given token1 is expected supported");
        result = entity.checkSupportOfToken(token2);
        assertEq(result, false, "The given token2 is expected unsupported");
        vm.stopPrank();
    }
}
