// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts//utils/math/Math.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IBotToken.sol";

contract BotToken is IBotToken, ERC20, ERC20Permit, ReentrancyGuard {
    address public immutable factory;
    uint256 public immutable maxSupply;
    address public immutable bidTokenAddress;
    uint32 public immutable auctionStartTime; // Timestamp
    uint32 public auctionEndTime; // Timestamp, not initialized in constructor
    uint32 public latestBidTime; // Timestamp, not initialized in constructor
    uint32 public constant airdropRound = 604800; // 7 days(unit: second)
    uint32 public constant auctionRoundDuration = 10800; // 3 hours(unit: second)
    uint24 public constant delayDuration = 86400; // 24 hours(unit: second)
    uint8 private immutable _decimals;
    uint8 public immutable chatToEarnRatio;
    uint8 public immutable airdropPercentagePerRound;
    uint256 public immutable pricePerThousandTokens;
    uint256 public immutable bidIncrement;
    uint256 public confirmedAmount;
    uint256 public confirmedPayment;
    uint256 public totalUsage;
    uint256 public currentBasePrice; // Acceptable value for the next bid(price per 1,000 tokens)
    mapping(address user => Share shareOfUser) public confirmedShare;
    mapping(address user => uint256 amount) public refundPool;
    mapping(address user => Bid currentBid) public currentBids;
    mapping(address user => bool isFollowing) public followers;
    mapping(address user => uint256 callNumber) public userUsage;
    mapping(address user => uint256 share) public airdropShare;
    string public botHandle;
    AuctionStatus public auctionStatus;
    address[] public currentBidders;

    constructor(
        string[3] memory stringData,
        uint256[6] memory uintData,
        uint256 _bidIncrement,
        address _bidTokenAddress
    ) ERC20(stringData[1], stringData[2]) ERC20Permit(stringData[1]) {
        factory = msg.sender;
        botHandle = stringData[0];
        _decimals = uint8(uintData[0]);
        maxSupply = uintData[1];
        auctionStartTime = uint32(uintData[2]);
        chatToEarnRatio = uint8(uintData[3]);
        airdropPercentagePerRound = uint8(uintData[4]);
        pricePerThousandTokens = uintData[5];
        bidIncrement = _bidIncrement;
        bidTokenAddress = _bidTokenAddress;
        auctionStatus = AuctionStatus.ongoing;
        currentBids[address(1)] = Bid(0, 0, address(0));
    }

    modifier onlyFactory() {
        if (msg.sender != factory) {
            revert NotFactory(msg.sender);
        }
        _;
    }

    modifier onlyWithinAuction() {
        if (block.timestamp < auctionStartTime) {
            revert AuctionNotStart(block.timestamp, auctionStartTime);
        }
        if (auctionStatus == AuctionStatus.closed) {
            revert AuctionHasEnded(block.timestamp, auctionEndTime);
        }
        _;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address recipient, uint256 amount) external onlyFactory {
        _mint(recipient, amount);
        emit TokenMinted(recipient, amount);
    }

    function bid(uint256 tokenAmount, uint256 price) external onlyWithinAuction {
        // Update round. Confirm the previous round if the current bid is the first one of a new round
        if (latestBidTime < _calculateCurrentRoundStartTime()) {
            _updateRoundVariables();
        }

        // Check `tokenAmount`
        _checkBidTokenAmount(tokenAmount);

        // Check `price`
        _checkBidPrice(price);

        // Check if the bid is not the first one of `msg.sender` within the same round
        uint256 tokenAmountOfPreviousBid = currentBids[msg.sender].tokenAmount;
        uint256 priceOfPreviousBid = currentBids[msg.sender].price;
        _checkLatestBidOfBidder(tokenAmount, price, tokenAmountOfPreviousBid, priceOfPreviousBid);
        confirmedAmount += tokenAmount - tokenAmountOfPreviousBid;
        confirmedPayment += tokenAmount * price - tokenAmountOfPreviousBid * priceOfPreviousBid;

        // Insertion sort of the current bid
        address nextOfCurrentBid = _sortBids(price);
        currentBids[msg.sender] = Bid({tokenAmount: tokenAmount, price: price, next: nextOfCurrentBid});

        // After the execution of the bid, do the following updates
        if (tokenAmountOfPreviousBid == 0) {
            currentBidders.push(msg.sender);
        }
        currentBasePrice = price;
        latestBidTime = uint32(block.timestamp);
        _updateAuctionStatus();
        emit BidToken(msg.sender, tokenAmount, price);
    }

    function _calculateCurrentRoundStartTime() internal view returns (uint256 currentRoundStartTime) {
        uint256 c = (block.timestamp - auctionStartTime) / auctionRoundDuration;
        c = c * auctionRoundDuration;
        currentRoundStartTime = c + auctionStartTime;
    }

    function _updateRoundVariables() internal {
        for (uint256 i = 0; i < currentBidders.length; i++) {
            address bidder = currentBidders[i];
            confirmedShare[bidder].tokenAmount += currentBids[bidder].tokenAmount;
            confirmedShare[bidder].payment += currentBids[bidder].tokenAmount * currentBids[bidder].price;
            delete currentBids[bidder];
        }
        delete currentBidders;
    }

    function _checkBidTokenAmount(uint256 tokenAmount) internal pure {
        if (tokenAmount == 0 || tokenAmount % 1000 != 0) {
            revert InvalidBidTokenAmount(tokenAmount);
        }
    }

    function _checkBidPrice(uint256 price) internal view {
        // When this bid is the first one of this round, the base price is `pricePerThousandTokens`. Otherwise, the base price is increased by `bidIncrement`
        uint256 basePrice = currentBidders.length == 0 ? pricePerThousandTokens : currentBasePrice + bidIncrement;
        if (price < basePrice) {
            revert InsufficientBidPrice(price, basePrice);
        }
    }

    function _checkLatestBidOfBidder(
        uint256 tokenAmount,
        uint256 price,
        uint256 tokenAmountOfPreviousBid,
        uint256 priceOfPreviousBid
    ) internal pure {
        if (tokenAmountOfPreviousBid != 0) {
            if (tokenAmount < tokenAmountOfPreviousBid) {
                revert LessTokenAmount(tokenAmount, tokenAmountOfPreviousBid);
            }
            if (price < priceOfPreviousBid) {
                revert LessPrice(price, priceOfPreviousBid);
            }
            if (tokenAmount == tokenAmountOfPreviousBid && price == priceOfPreviousBid) {
                revert DuplicateBid(tokenAmount, price);
            }
        }
    }

    function _updateAuctionStatus() internal {
        if (auctionEndTime != 0 && block.timestamp > auctionEndTime) {
            auctionStatus = AuctionStatus.closed;
        } else {
            if (confirmedAmount >= maxSupply) {
                auctionStatus = AuctionStatus.locked;
                auctionEndTime = uint32(block.timestamp) + delayDuration;
            }
        }
    }

    function _sortBids(uint256 price) internal returns (address nextOfCurrentBid) {
        address current = address(1);
        while (currentBids[current].next != address(0) && currentBids[currentBids[current].next].price < price) {
            current = currentBids[current].next;
        }
        nextOfCurrentBid = currentBids[current].next;
        currentBids[current].next = msg.sender;
    }

    function getAuctionStatus() public view returns (string memory status) {
        if (block.timestamp < auctionStartTime) {
            return "notStarted";
        }
        if (auctionStatus == AuctionStatus.ongoing) {
            return "ongoing";
        }
        if (auctionStatus == AuctionStatus.locked) {
            return "locked";
        }
        if (auctionStatus == AuctionStatus.closed) {
            return "closed";
        }
    }
}
