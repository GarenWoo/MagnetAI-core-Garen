// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

/**
 * @title The interface of {BotToken}.
 */
interface IBotToken {
    // Struct
    struct Mint {
        uint256 confirmedAmount;
        uint256 confirmedPayment;
        uint256 amount;
        uint256 price;
        uint256 slot;
        address next;
    }

    // Events
    event TokenMinted(uint256 timestamp, address user, uint256 amount, uint256 mintedAmount, uint256 price);
    event MintWithdrawal(uint256 timestamp, address user, address paymentToken, uint256 withdrawal);
    event TokenClaimed(address claimant, uint256 actualMintedAmount, uint256 refund);
    event FundClaimed(address claimant, uint256 claimedPayment);

    // Errors
    error NotMagnetAI(address caller);
    error NotBotOwner(address caller, address botOwner);
    error IssuanceNotStarted(uint256 currentTime, uint256 startTime);
    error IssuanceHasEnded(uint256 currentTime, uint256 endTime);
    error InvalidAmount(uint256 amount);
    error InvalidPrice(uint256 mintPrice, uint256 mintIncrement);
    error LessMintAmount(uint256 currentAmount, uint256 previousAmount);
    error DuplicateMint(uint256 currentAmount, uint256 currentPrice);
    error NotInOngoingPhase(uint256 totalMintedAmount, uint256 maxSupply, uint256 currentTime, uint256 endTime);
    error NotEnded(uint256 totalMintedAmount, uint256 maxSupply, uint256 currentTime, uint256 endTime);
    error InsufficientETHPaid(uint256 paidAmount, uint256 payables);
    error NoneMinted(address caller);
    error AssetTransferFailed(address tokenAddress, address from, address recipient, uint256 tokenAmount);
    error ETHTransferWithFrom(address paymentToken, address from);
    error FundHasClaimed();

    // Functions
    function mint(uint256 amount, uint256 price) external payable;
    function withdrawMint() external;
    function claimToken() external;
    function claimFund() external;
    function calculateCurrentSlotStartTime() external view returns (uint256 currentSlot);
    function getIssuanceStatus() external view returns (string memory status);
    
}
