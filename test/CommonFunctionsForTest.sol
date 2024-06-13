// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {MagnetAI} from "../src/MagnetAI.sol";

abstract contract CommonFunctionsForTest is Test {
    // Logic of Business
    uint256 internal constant _decimals = 6;
    uint256 internal constant _minPriceOfBot = 0;
    uint256 internal constant _maxPriceOfBot = 100 * 10 ** _decimals;

    uint256 internal constant _minLengthOfBotHandle = 1;
    uint256 internal constant _maxLengthOfBotHandle = 32;

    // Private State Variables
    string internal constant ALL_CHARS =
        " !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    string internal constant BOTHANDLE_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    string internal constant BOTTOKENNAME_CHARS = " -._ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    string internal constant BOTTOKENSYMBOL_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    mapping(bytes32 => bool) internal _stringHashRegistry;
    uint256 internal _nonce;

    // Model: Internal function(s)
    function _registerModel(
        MagnetAI entity,
        address caller,
        string memory modelHandle,
        string memory metadata,
        uint256 price
    ) internal {
        vm.prank(caller);
        entity.registerModel(modelHandle, metadata, price);
    }

    // Subnet: Internal function(s)
    function _registerSubnet(MagnetAI entity, address caller, string memory subnetHandle, string memory metadata)
        internal
    {
        vm.prank(caller);
        entity.registerSubnet(subnetHandle, metadata);
    }

    function _authorizeModelManager(MagnetAI entity, address caller, address registrant, string memory subnetHandle)
        internal
    {
        vm.prank(caller);
        entity.authorizeModelManager(registrant, subnetHandle);
    }

    // ModelManager: Internal function(s)
    function _registerModelManager(
        MagnetAI entity,
        address caller,
        string memory modelManagerId,
        string memory modelHandle,
        string memory subnetHandle,
        string memory url
    ) internal {
        vm.prank(caller);
        entity.registerModelManager(modelManagerId, modelHandle, subnetHandle, url);
    }

    // Bot: Internal function(s)
    function _createBot(
        MagnetAI entity,
        address caller,
        string memory botHandle,
        string memory modelManagerId,
        string memory metadata,
        uint256 price
    ) internal {
        vm.prank(caller);
        entity.createBot(botHandle, modelManagerId, metadata, price);
    }

    function _createMultipleBots(MagnetAI entity, address caller, uint256 amountOfBot, string memory modelManagerId)
        internal
        returns (string[] memory)
    {
        string[] memory botHandles = new string[](amountOfBot);
        for (uint256 i = 0; i < amountOfBot; i++) {
            uint256 botHandleLength = _generateRandomUint(_minLengthOfBotHandle, _maxLengthOfBotHandle);
            string memory botHandle = _generateRandomUniqueString(BOTHANDLE_CHARS, botHandleLength);
            // Note Test on Foundry local node(anvil) will exceed the maximum of memory capacity if the following code is not commented
            // uint256 metadataLength = _generateRandomUint(0, type(uint32).max);
            // string memory metadata = _generateRandomUniqueString(ALL_CHARS, metadataLength);
            // Replaced the code with the following one considering `metadata` is relatively not crucial in testing.
            string memory metadata = "uniform metadata of bot";
            uint256 price = _generateRandomUint(_minPriceOfBot, _maxPriceOfBot);
            vm.prank(caller);
            entity.createBot(botHandle, modelManagerId, metadata, price);
            botHandles[i] = botHandle;
        }
        return botHandles;
    }

    // ------------------------------------ Utils ------------------------------------
    function _useNonce() internal returns (uint256) {
        uint256 recordedNonce = _nonce;
        _nonce++;
        return recordedNonce;
    }

    function _generateUint256Array(bool isRandomElement, uint256 length) internal returns (uint256[] memory) {
        uint256[] memory uintArray = new uint256[](length);
        if (isRandomElement) {
            for (uint256 i = 0; i < length; i++) {
                uintArray[i] =
                    uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())));
            }
        } else {
            uint256 fixedElement =
                uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())));
            for (uint256 i = 0; i < length; i++) {
                uintArray[i] = fixedElement;
            }
        }
        return uintArray;
    }

    function _generateUint128Array(bool isRandomElement, uint256 length) internal returns (uint256[] memory) {
        uint256[] memory uintArray = new uint256[](length);
        if (isRandomElement) {
            for (uint256 i = 0; i < length; i++) {
                uintArray[i] = uint128(
                    uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())))
                );
            }
        } else {
            uint128 fixedElement = uint128(
                uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())))
            );
            for (uint256 i = 0; i < length; i++) {
                uintArray[i] = fixedElement;
            }
        }
        return uintArray;
    }

    function _generateUint64Array(bool isRandomElement, uint256 length) internal returns (uint256[] memory) {
        uint256[] memory uintArray = new uint256[](length);
        if (isRandomElement) {
            for (uint256 i = 0; i < length; i++) {
                uintArray[i] = uint64(
                    uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())))
                );
            }
        } else {
            uint64 fixedElement =
                uint64(uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce()))));
            for (uint256 i = 0; i < length; i++) {
                uintArray[i] = fixedElement;
            }
        }
        return uintArray;
    }

    function _generateUint32Array(bool isRandomElement, uint256 length) internal returns (uint256[] memory) {
        uint256[] memory uintArray = new uint256[](length);
        if (isRandomElement) {
            for (uint256 i = 0; i < length; i++) {
                uintArray[i] = uint32(
                    uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())))
                );
            }
        } else {
            uint32 fixedElement =
                uint32(uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce()))));
            for (uint256 i = 0; i < length; i++) {
                uintArray[i] = fixedElement;
            }
        }
        return uintArray;
    }

    function _generateUint16Array(bool isRandomElement, uint256 length) internal returns (uint256[] memory) {
        uint256[] memory uintArray = new uint256[](length);
        if (isRandomElement) {
            for (uint256 i = 0; i < length; i++) {
                uintArray[i] = uint16(
                    uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())))
                );
            }
        } else {
            uint16 fixedElement =
                uint16(uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce()))));
            for (uint256 i = 0; i < length; i++) {
                uintArray[i] = fixedElement;
            }
        }
        return uintArray;
    }

    function _generateUint8Array(bool isRandomElement, uint256 length) internal returns (uint256[] memory) {
        uint256[] memory uintArray = new uint256[](length);
        if (isRandomElement) {
            for (uint256 i = 0; i < length; i++) {
                uintArray[i] = uint8(
                    uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())))
                );
            }
        } else {
            uint8 fixedElement =
                uint8(uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce()))));
            for (uint256 i = 0; i < length; i++) {
                uintArray[i] = fixedElement;
            }
        }
        return uintArray;
    }

    function _generate2DUnit8Array(bool isRandomElement, uint256 lengthOfOutter, uint256 lengthOfInner)
        internal
        returns (uint256[][] memory)
    {
        uint256[][] memory uintArray = new uint256[][](lengthOfOutter);
        if (isRandomElement) {
            for (uint256 i = 0; i < lengthOfOutter; i++) {
                uintArray[i] = new uint256[](lengthOfInner);
                for (uint256 j = 0; j < lengthOfInner; j++) {
                    uintArray[i][j] = uint8(
                        uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())))
                    );
                }
            }
        } else {
            uint8 fixedElement1OfInnerArray =
                uint8(uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce()))));
            uint8 fixedElement2OfInnerArray =
                uint8(uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce()))));
            for (uint256 i = 0; i < lengthOfOutter; i++) {
                uintArray[i] = new uint256[](lengthOfInner);
                uintArray[i][0] = fixedElement1OfInnerArray;
                uintArray[i][1] = fixedElement2OfInnerArray;
            }
        }
        return uintArray;
    }

    function _generate2DUnit16Array(bool isRandomElement, uint256 lengthOfOutter, uint256 lengthOfInner)
        internal
        returns (uint256[][] memory)
    {
        uint256[][] memory uintArray = new uint256[][](lengthOfOutter);
        if (isRandomElement) {
            for (uint256 i = 0; i < lengthOfOutter; i++) {
                uintArray[i] = new uint256[](lengthOfInner);
                for (uint256 j = 0; j < lengthOfInner; j++) {
                    uintArray[i][j] = uint16(
                        uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())))
                    );
                }
            }
        } else {
            uint16 fixedElement1OfInnerArray =
                uint16(uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce()))));
            uint16 fixedElement2OfInnerArray =
                uint16(uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce()))));
            for (uint256 i = 0; i < lengthOfOutter; i++) {
                uintArray[i] = new uint256[](lengthOfInner);
                uintArray[i][0] = fixedElement1OfInnerArray;
                uintArray[i][1] = fixedElement2OfInnerArray;
            }
        }
        return uintArray;
    }

    function _generate2DUnit32Array(bool isRandomElement, uint256 lengthOfOutter, uint256 lengthOfInner)
        internal
        returns (uint256[][] memory)
    {
        uint256[][] memory uintArray = new uint256[][](lengthOfOutter);
        if (isRandomElement) {
            for (uint256 i = 0; i < lengthOfOutter; i++) {
                uintArray[i] = new uint256[](lengthOfInner);
                for (uint256 j = 0; j < lengthOfInner; j++) {
                    uintArray[i][j] = uint32(
                        uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())))
                    );
                }
            }
        } else {
            uint32 fixedElement1OfInnerArray =
                uint32(uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce()))));
            uint32 fixedElement2OfInnerArray =
                uint32(uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce()))));
            for (uint256 i = 0; i < lengthOfOutter; i++) {
                uintArray[i] = new uint256[](lengthOfInner);
                uintArray[i][0] = fixedElement1OfInnerArray;
                uintArray[i][1] = fixedElement2OfInnerArray;
            }
        }
        return uintArray;
    }

    function _generate2DUnit64Array(bool isRandomElement, uint256 lengthOfOutter, uint256 lengthOfInner)
        internal
        returns (uint256[][] memory)
    {
        uint256[][] memory uintArray = new uint256[][](lengthOfOutter);
        if (isRandomElement) {
            for (uint256 i = 0; i < lengthOfOutter; i++) {
                uintArray[i] = new uint256[](lengthOfInner);
                for (uint256 j = 0; j < lengthOfInner; j++) {
                    uintArray[i][j] = uint64(
                        uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())))
                    );
                }
            }
        } else {
            uint64 fixedElement1OfInnerArray =
                uint64(uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce()))));
            uint64 fixedElement2OfInnerArray =
                uint64(uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce()))));
            for (uint256 i = 0; i < lengthOfOutter; i++) {
                uintArray[i] = new uint256[](lengthOfInner);
                uintArray[i][0] = fixedElement1OfInnerArray;
                uintArray[i][1] = fixedElement2OfInnerArray;
            }
        }
        return uintArray;
    }

    function _generate2DUnit128Array(bool isRandomElement, uint256 lengthOfOutter, uint256 lengthOfInner)
        internal
        returns (uint256[][] memory)
    {
        uint256[][] memory uintArray = new uint256[][](lengthOfOutter);
        if (isRandomElement) {
            for (uint256 i = 0; i < lengthOfOutter; i++) {
                uintArray[i] = new uint256[](lengthOfInner);
                for (uint256 j = 0; j < lengthOfInner; j++) {
                    uintArray[i][j] = uint128(
                        uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())))
                    );
                }
            }
        } else {
            uint128 fixedElement1OfInnerArray = uint128(
                uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())))
            );
            uint128 fixedElement2OfInnerArray = uint128(
                uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())))
            );
            for (uint256 i = 0; i < lengthOfOutter; i++) {
                uintArray[i] = new uint256[](lengthOfInner);
                uintArray[i][0] = fixedElement1OfInnerArray;
                uintArray[i][1] = fixedElement2OfInnerArray;
            }
        }
        return uintArray;
    }

    function _generateUniqueAddressArray(uint256 length) internal returns (address[] memory) {
        address[] memory addressArray = new address[](length);
        for (uint i = 0; i < length; i++) {
            addressArray[i] = address(uint160(uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())))));
        }
        return addressArray;
    }

    function _generateRandomUint(uint256 increment, uint256 divisor) internal returns (uint256 result) {
        uint256 denominator = divisor == 0 ? 1 : divisor;
        result = uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), _useNonce())))
            % denominator + increment;
    }

    function _generateRandomUniqueString(string memory chars, uint256 length) internal returns (string memory) {
        require(length != 0, "Zero-length of string!");
        bytes memory randomStringInBytes = new bytes(length);
        bytes memory charsInBytes = bytes(chars);
        uint256 lengthOfChars = charsInBytes.length;
        bytes32 stringHash;
        bool isExisted;
        while (!isExisted) {
            uint256 randomIndex;
            for (uint256 i = 0; i < length; i++) {
                randomIndex = _generateRandomUint(0, lengthOfChars);
                randomStringInBytes[i] = charsInBytes[randomIndex];
            }
            stringHash = keccak256(abi.encodePacked(randomStringInBytes));
            if (_stringHashRegistry[stringHash] == false) {
                _stringHashRegistry[stringHash] = true;
                isExisted = true;
            }
        }
        return string(randomStringInBytes);
    }

    function _deriveLesserUint(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _deriveMin(uint256[] memory nums) internal pure returns (uint256) {
        uint256 length = nums.length;
        require(length != 0, "Zero length of given nums");
        uint256 min = nums[0];
        for (uint256 i = 0; i < length; i++) {
            min = _deriveLesserUint(min, nums[i]);
        }
        return min;
    }
}
