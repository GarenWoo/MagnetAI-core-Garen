// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IBotToken.sol";

contract BotToken is IBotToken, ERC20, ERC20Permit, ReentrancyGuard {
    string public botHandle;
    address public immutable magnetAI;
    address public immutable factory;
    address public immutable botOwner;
    address public immutable paymentToken;
    address public headOfCurrentSlot;
    uint32 public immutable issuanceStartTime; // Timestamp
    uint32 public issuanceEndTime; // Timestamp, not initialized in constructor
    uint32 public immutable dropTime; // Time interval between the end of minting and the start of airdrop(unit: second)
    uint32 public constant slotDuration = 3600; // 1 hour(unit: second)
    uint24 public constant delayDuration = 86400; // 24 hours(unit: second)
    bool public isFundClaimed;
    uint256 public immutable airdropSupply;
    uint256 public immutable mintSupply;
    uint256 public immutable mintPriceIncrement;
    uint256 public previousConfirmedAmount;
    uint256 public totalMintedAmount;
    uint256 public previousConfirmedPayment;
    uint256 public totalMintedPayment;
    uint256 public totalUsage;
    uint256 public mintablePrice; // Initialized in the constructor with the value of the price per 1,000 bot tokens
    uint256 public finalSlotMintableAmount;
    mapping(address user => Mint mint) public mints;
    mapping(address user => bool isFollowing) public followers;
    mapping(address user => uint256 callNumber) public userUsage;
    mapping(address user => uint256 share) public airdropShare;

    constructor(
        string[3] memory stringData,
        uint256[5] memory uintData,
        uint256 pricePerKToken,
        uint256 _mintPriceIncrement,
        address _magnetAI,
        address _botOwner,
        address _paymentToken
    ) ERC20(stringData[1], stringData[2]) ERC20Permit(stringData[1]) {
        factory = msg.sender;
        botHandle = stringData[0];
        // If `issuanceStartTime` is early than the moment of contract deployment, it is set as `block.timestamp`
        issuanceStartTime = uintData[1] > block.timestamp ? uint32(uintData[1]) : uint32(block.timestamp);
        dropTime = uint32(uintData[2] * 86400);
        mintPriceIncrement = _mintPriceIncrement;
        magnetAI = _magnetAI;
        botOwner = _botOwner;
        paymentToken = _paymentToken;
        airdropSupply = uintData[0] * uintData[3] / 100;
        mintSupply = uintData[0] - airdropSupply;
        mintablePrice = pricePerKToken;
    }

    modifier onlyMagnetAI() {
        if (msg.sender != magnetAI) {
            revert NotMagnetAI(msg.sender);
        }
        _;
    }

    modifier onlyAfterStarted() {
        if (block.timestamp < issuanceStartTime) {
            revert IssuanceNotStarted(block.timestamp, issuanceStartTime);
        }
        _;
    }

    modifier onlyWithinIssuance() {
        if (block.timestamp < issuanceStartTime) {
            revert IssuanceNotStarted(block.timestamp, issuanceStartTime);
        }
        if (issuanceEndTime != 0 && block.timestamp >= issuanceEndTime) {
            revert IssuanceHasEnded(block.timestamp, issuanceEndTime);
        }
        _;
    }

    modifier onlyOngoing() {
        if (totalMintedAmount >= mintSupply || block.timestamp < issuanceStartTime) {
            revert NotInOngoingPhase(totalMintedAmount, mintSupply, block.timestamp, issuanceEndTime);
        }
        _;
    }

    modifier onlyEnded() {
        if (issuanceEndTime == 0 || block.timestamp < issuanceEndTime) {
            revert NotEnded(totalMintedAmount, mintSupply, block.timestamp, issuanceEndTime);
        }
        _;
    }

    modifier onlyBotOwner() {
        if (msg.sender != botOwner) {
            revert NotBotOwner(msg.sender, botOwner);
        }
        _;
    }

    receive() external payable {}

    function mint(uint256 amount, uint256 price) external payable onlyWithinIssuance nonReentrant {
        // Get the timestamp of the start of the current slot
        uint256 currentSlot = calculateCurrentSlotStartTime();
        // Declare `excess` to record the excessive amount of minted token
        uint256 excess;
        // Declare `payables` to record the correct amount of token that `msg.sender` should pay
        uint256 payables;
        // Check `amount`
        if (amount == 0 || amount % 1000 != 0 || amount > mintSupply) {
            revert InvalidAmount(amount);
        }
        // Check `price`
        if (price == 0 || price % mintPriceIncrement != 0 || price < mintablePrice) {
            revert InvalidPrice(price, mintPriceIncrement);
        }

        // Get the values of latest mint of `msg.sender`
        uint256 amountOfPreviousMint = mints[msg.sender].amount;
        uint256 priceOfPreviousMint = mints[msg.sender].price;

        // Judge if the current mint is the first one in the current slot
        if (mints[headOfCurrentSlot].slot != currentSlot) {
            headOfCurrentSlot = address(0);
            mints[msg.sender].next = address(0);
            previousConfirmedAmount = totalMintedAmount;
            previousConfirmedPayment = totalMintedPayment;
        }

        // Check if there is an another, earlier, mint of `msg.sender` in the same slot
        if (mints[msg.sender].slot == currentSlot) {
            if (amount < amountOfPreviousMint) {
                revert LessMintAmount(amount, amountOfPreviousMint);
            }
            if (price < priceOfPreviousMint) {
                revert InvalidPrice(price, mintPriceIncrement);
            }
            if (amount == amountOfPreviousMint && price == priceOfPreviousMint) {
                revert DuplicateMint(amount, price);
            }
            payables = amount * price / 1000 - amountOfPreviousMint * priceOfPreviousMint / 1000;
            totalMintedAmount += amount - amountOfPreviousMint;
            totalMintedPayment += payables;
        } else {
            payables = amount * price / 1000;
            mints[msg.sender].confirmedAmount += amountOfPreviousMint;
            mints[msg.sender].confirmedPayment += amountOfPreviousMint * priceOfPreviousMint / 1000;
            totalMintedAmount += amount;
            totalMintedPayment += payables;
        }

        // Insertion sorting of the mints of the current slot considering the current mint
        excess = _sortMints(price, currentSlot, amount);

        // Check `msg.value` or excute ERC20 token transfer
        if (paymentToken == address(0)) {
            if (msg.value < payables) {
                revert InsufficientETHPaid(msg.value, payables);
            }
            if (msg.value > payables) {
                // Refund the excess of payable token or ETH
                _transferAsset(address(0), msg.sender, msg.value - payables);
            }
        } else {
            // ERC20 token tranferred from `msg.sender` to `address(this)`
            _transferAsset(msg.sender, address(this), payables);
        }

        // Updates fields of the instance of struct `Mint` of `msg.sender`
        mints[msg.sender].amount = amount - excess;
        mints[msg.sender].price = price;
        mints[msg.sender].slot = currentSlot;

        // Check the status of the token issuance
        if (totalMintedAmount >= mintSupply && issuanceEndTime == 0) {
            issuanceEndTime = uint32(block.timestamp) + delayDuration;
            finalSlotMintableAmount = mintSupply - previousConfirmedAmount;
        }

        emit TokenMinted(block.timestamp, msg.sender, amount, amount - excess, price);
    }

    function withdrawMint() external onlyOngoing nonReentrant {
        // Get the data from `Mint` instance of `msg.sender`
        // Assume `amount` and `price` of `msg.sender` are both updated at the same time. `amount` updated before the current slot will be set zero
        uint256 amount = mints[msg.sender].amount;
        uint256 totalAmount = mints[msg.sender].confirmedAmount + amount;
        uint256 totalPayment = mints[msg.sender].confirmedPayment + amount * mints[msg.sender].price / 1000;
        // Ensure the payment of `msg.sender` withdrawable
        if (totalPayment == 0) {
            revert NoneMinted(msg.sender);
        }
        // Get the timestamp of the start of the current slot
        uint256 currentSlot = calculateCurrentSlotStartTime();
        // Update sorting
        // Update state variable of the token issuance
        if (mints[msg.sender].slot == currentSlot) {
            address prev = address(1);
            address current = headOfCurrentSlot;
            while (current != msg.sender) {
                prev = current;
                current = mints[current].next;
            }
            if (prev == address(1)) {
                headOfCurrentSlot = mints[msg.sender].next;
            } else {
                mints[prev].next = mints[msg.sender].next;
            }
            previousConfirmedAmount -= mints[msg.sender].confirmedAmount;
            previousConfirmedPayment -= mints[msg.sender].confirmedPayment;
        } else {
            previousConfirmedAmount -= totalAmount;
            previousConfirmedPayment -= totalPayment;
        }

        totalMintedAmount -= totalAmount;
        totalMintedPayment -= totalPayment;

        // Reset the data of user
        delete mints[msg.sender];

        // Withdraw payment
        _transferAsset(address(0), msg.sender, totalPayment);
        emit MintWithdrawal(block.timestamp, msg.sender, paymentToken, totalPayment);
    }

    function claimToken() external onlyEnded nonReentrant {
        uint256 currentSlot = calculateCurrentSlotStartTime();
        uint256 unconfirmedAmount = mints[msg.sender].amount;
        uint256 price = mints[msg.sender].price;
        uint256 actualMintedAmount = mints[msg.sender].confirmedAmount;
        uint256 refund;
        // Ensure the minted amount of `msg.sender` is non-zero
        if (actualMintedAmount + unconfirmedAmount == 0) {
            revert NoneMinted(msg.sender);
        }
        if (mints[msg.sender].slot != currentSlot) {
            actualMintedAmount += unconfirmedAmount;
        } else {
            // The case that `msg.sender` has minted in the last slot(i.e. the slot that gets into the locked phase)
            uint256 priceOfLastFinalist = mintablePrice - mintPriceIncrement;
            // If `price` is definitely lower than `priceOfLastFinalist`, refund (`unconfirmedAmount` * `price` / 1000) to `msg.sender`
            if (price < priceOfLastFinalist) {
                refund = unconfirmedAmount * price / 1000;
            } else if (price > priceOfLastFinalist) {
                actualMintedAmount += unconfirmedAmount;
                finalSlotMintableAmount -= unconfirmedAmount;
                previousConfirmedAmount += unconfirmedAmount;
                previousConfirmedPayment += unconfirmedAmount * price / 1000;
            } else {
                address current = headOfCurrentSlot;
                uint256 updatedAmount = finalSlotMintableAmount;
                while (updatedAmount != 0) {
                    if (current == msg.sender) {
                        actualMintedAmount += unconfirmedAmount;
                        uint256 excess;
                        if (updatedAmount < unconfirmedAmount) {
                            // Calculate the amount of refund
                            excess = unconfirmedAmount - updatedAmount;
                            refund = excess * price / 1000;
                            actualMintedAmount -= excess;
                        }
                        finalSlotMintableAmount -= unconfirmedAmount - excess;
                        previousConfirmedAmount += unconfirmedAmount - excess;
                        previousConfirmedPayment += (unconfirmedAmount - excess) * price / 1000;
                        break;
                    }
                    if (mints[current].amount >= updatedAmount) {
                        break;
                    }
                    updatedAmount -= mints[current].amount;
                    current = mints[current].next;
                }
            }
        }

        // Reset
        mints[msg.sender].amount = 0;
        mints[msg.sender].confirmedAmount = 0;

        // Execute minting bot tokens
        if (actualMintedAmount > 0) {
            _mint(msg.sender, actualMintedAmount);
        }

        // Execute refund of unsuccessful mint
        if (refund > 0) {
            _transferAsset(address(0), msg.sender, refund);
        }

        emit TokenClaimed(msg.sender, actualMintedAmount, refund);
    }

    function claimFund() external onlyBotOwner onlyEnded {
        if (isFundClaimed) {
            revert FundHasClaimed();
        }
        // Sum up all the payment in the entire token issuance
        uint256 payment = previousConfirmedPayment;
        uint256 updatedAmount = previousConfirmedAmount;
        address prev;
        address current = headOfCurrentSlot;
        while (updatedAmount < mintSupply) {
            updatedAmount += mints[current].amount;
            payment += mints[current].amount * mints[current].price / 1000;
            prev = current;
            current = mints[current].next;
        }
        // Calculate the refunded amount for the last finalist if `updatedAmount` exceeds `mintSupply`
        if (updatedAmount > mintSupply) {
            uint256 failedPayment = (updatedAmount - mintSupply) * mints[prev].price / 1000;
            payment -= failedPayment;
        }
        // Locked this function
        isFundClaimed = true;

        // Execute token/ETH transfer
        _transferAsset(address(0), msg.sender, payment);

        emit FundClaimed(msg.sender, payment);
    }

    function calculateCurrentSlotStartTime() public view onlyAfterStarted returns (uint256 currentSlot) {
        // When `totalMintedAmount` has reached or exceed `mintSupply`, the valid timestamp for slot calculation should be the moment of being locked
        uint256 time = issuanceEndTime == 0 ? block.timestamp : issuanceEndTime - delayDuration;
        uint256 c = (time - issuanceStartTime) / slotDuration;
        c = c * slotDuration;
        currentSlot = c + issuanceStartTime;
    }

    function getIssuanceStatus() public view returns (string memory status) {
        if (block.timestamp < issuanceStartTime) {
            return "notStarted";
        }
        if (block.timestamp >= issuanceStartTime && totalMintedAmount < mintSupply) {
            return "ongoing";
        }
        if (totalMintedAmount >= mintSupply && block.timestamp < issuanceEndTime) {
            return "locked";
        }
        if (issuanceEndTime != 0 && block.timestamp >= issuanceEndTime) {
            return "closed";
        }
    }

    function _sortMints(uint256 price, uint256 currentSlot, uint256 amount) private returns (uint256 excess) {
        address prev = address(1);
        address current = headOfCurrentSlot;
        uint256 updatedAmount = previousConfirmedAmount;
        address insertion;
        uint256 previousSlot = mints[msg.sender].slot;
        uint256 previousPrice = mints[msg.sender].price;
        // Look for the insertion point
        while (current != address(0) && mints[current].price >= price) {
            // When the current mint of `msg.sender` has the same price as the previous one
            if (current == msg.sender) {
                prev = current;
                current = mints[current].next;
                break;
            }
            updatedAmount += mints[current].amount;
            prev = current;
            current = mints[current].next;
        }
        updatedAmount += amount;
        // Insertion can be `msg.sender` when `msg.sender` give the same price in the current mint
        insertion = prev;
        // Proceed to check if the token issuance has reached `mintSupply`
        if (totalMintedAmount >= mintSupply) {
            if (updatedAmount > mintSupply) {
                excess = updatedAmount - mintSupply;
                uint256 paymentOfExcess = excess * price / 1000;
                totalMintedAmount -= excess;
                totalMintedPayment -= paymentOfExcess;
                _transferAsset(address(0), msg.sender, paymentOfExcess);
            }
            while (updatedAmount < mintSupply) {
                if (current == msg.sender) {
                    mints[prev].next = mints[current].next;
                    current = mints[current].next;
                }
                updatedAmount += mints[current].amount;
                prev = current;
                current = mints[current].next;
            }
            uint256 priceOfLastFinalist = headOfCurrentSlot == address(0) ? price : mints[prev].price;
            mintablePrice = priceOfLastFinalist + mintPriceIncrement;
        } else if (previousSlot == currentSlot && previousPrice != price) {
            while (msg.sender != current) {
                prev = current;
                current = mints[current].next;
            }
            mints[prev].next = mints[current].next;
        }

        // Execution insertion
        if (!(previousSlot == currentSlot && price == previousPrice)) {
            // Insert the current mint
            if (insertion == address(1)) {
                mints[msg.sender].next = headOfCurrentSlot;
                headOfCurrentSlot = msg.sender;
            } else {
                mints[msg.sender].next = mints[insertion].next;
                mints[insertion].next = msg.sender;
            }
        }
    }

    function _transferAsset(address from, address recipient, uint256 tokenAmount) private {
        if (paymentToken == address(0)) {
            if (from != address(0)) {
                revert ETHTransferWithFrom(paymentToken, from);
            }
            (bool ETHTransferSuccess,) = payable(recipient).call{value: tokenAmount}("");
            if (!ETHTransferSuccess) {
                revert AssetTransferFailed(paymentToken, from, recipient, tokenAmount);
            }
        } else {
            bool TransferSuccess;
            bytes memory data;
            if (from != address(0)) {
                // 0x23b872dd == bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
                (TransferSuccess, data) =
                    paymentToken.call(abi.encodeWithSelector(0x23b872dd, from, recipient, tokenAmount));
            } else {
                // 0xa9059cbb == bytes4(keccak256(bytes('transfer(address,uint256)')));
                (TransferSuccess, data) = paymentToken.call(abi.encodeWithSelector(0xa9059cbb, recipient, tokenAmount));
            }
            if (!(TransferSuccess && (data.length == 0 || abi.decode(data, (bool))))) {
                revert AssetTransferFailed(paymentToken, from, recipient, tokenAmount);
            }
        }
    }
}
