// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title The interface of OrderSystem.
 */
interface IOrderSystem {
    struct AIModel {
        uint256 modelId;
        address owner;
        string metadata;
        uint256 price;
    }

    struct Subnet {
        uint256 subnetId;
        address owner;
    }

    struct ModelManager {
        uint256 modelManagerId;
        uint256 subnetId;
        uint256 modelId;
        address owner;
        string url;
    }

    struct Bot {
        uint256 botHandle;
        uint256 modelManagerId;
        address owner;
        string metadata;
        uint256 price;
    }

    event ModelRegistered(uint256 modelId, address account);
    event ModelPriceModified(uint256 modelId, uint256 newPrice);
    event SubnetRegistered(uint256 subnetId, address account);
    event ModelManagerRegistered(uint256 modelManagerId, address account);
    event ModelManagerUrlModified(uint256 modelManagerId, string url);
    event BotCreated(address account, uint256 botHandle, uint256 modelManagerId);
    event BotPriceModified(uint256 botHandle, uint256 newPrice);
    event BotFollowed(uint256 botHandle, address user);
    event BotPayment(address user, uint256 value);
    
    error NotModelOwner(address caller, address owner);
    error NotSubnetOwner(address caller, address owner);
    error NotModelManagerOwner(address caller, address owner);
    error NotBotOwner(address caller, address owner);
    error NonexistentModel(uint256 modelId);
    error NonexistentSubnet(uint256 subnetId);
    error BotHandleHasExisted(uint256 botHandle);
    error NonexistentModelManager(uint256 subnetId);

// ———————————————————————————————————————— AI Model ————————————————————————————————————————


}