// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

/**
 * @title The interface of {BotToken}.
 */
interface IBotToken {
    // Struct
    struct Bid {
        uint256 tokenAmount;
        uint256 price;
        address next;
    }

    struct Share {
        uint256 tokenAmount;
        uint256 payment;
    }

    // Enums
    enum AuctionStatus {
        ongoing,
        locked,
        closed
    }

    // events:
    event TokenMinted(address recipient, uint256 totalMinted);
    event BidToken(address bidder, uint256 tokenAmount, uint256 price);

    // errors:
    error NotFactory(address caller);
    error AuctionNotStart(uint256 currentTime, uint256 startTime);
    error AuctionHasEnded(uint256 currentTime, uint256 endTime);
    error InvalidBidTokenAmount(uint256 bidTokenAmount);
    error InsufficientBidPrice(uint256 bidPrice, uint256 basePrice);
    error LessTokenAmount(uint256 currentAmount, uint256 previousAmount);
    error LessPrice(uint256 currentPrice, uint256 previousPrice);
    error DuplicateBid(uint256 currentAmount, uint256 currentPrice);
}