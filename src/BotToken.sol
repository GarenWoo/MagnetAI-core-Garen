// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "./interfaces/IBotToken.sol";

contract BotToken is IBotToken, ERC20, ERC20Permit {
    uint256 public immutable maxSupply;
    address public immutable magnetAI;
    address public immutable factory;
    address public immutable botOwner;
    address public immutable paymentToken;
    address public headOfCurrentSlot;
    uint32 public immutable issuanceStartTime; // Timestamp
    uint32 public issuanceEndTime; // Timestamp, not initialized in constructor
    uint32 public constant airdropRound = 604800; // 7 days(unit: second)
    uint32 public constant slotDuration = 3600; // 1 hour(unit: second)
    uint24 public constant delayDuration = 86400; // 24 hours(unit: second)
    uint8 public immutable airdropRatio;
    uint8 public immutable airdropPercentagePerRound;
    uint256 public immutable pricePerThousandTokens;
    uint256 public immutable mintPriceIncrement;
    uint256 public totalConfirmedAmount;
    uint256 public totalMintedAmount;
    uint256 public totalConfirmedPayment;
    uint256 public totalPayment;
    uint256 public totalUsage;
    uint256 public paymentOfOngoingPhase;
    uint256 public mintablePrice;
    mapping(address user => Mint mint) public mints;
    mapping(address user => bool isFollowing) public followers;
    mapping(address user => uint256 callNumber) public userUsage;
    mapping(address user => uint256 share) public airdropShare;
    string public botHandle;

    constructor(
        string[3] memory stringData,
        uint256[5] memory uintData,
        uint256 _mintPriceIncrement,
        address _magnetAI,
        address _botOwner,
        address _paymentToken
    ) ERC20(stringData[1], stringData[2]) ERC20Permit(stringData[1]) {
        factory = msg.sender;
        botHandle = stringData[0];
        maxSupply = uintData[0];
        issuanceStartTime = uint32(uintData[1]);
        airdropRatio = uint8(uintData[2]);
        airdropPercentagePerRound = uint8(uintData[3]);
        pricePerThousandTokens = uintData[4];
        mintPriceIncrement = _mintPriceIncrement;
        magnetAI = _magnetAI;
        botOwner = _botOwner;
        paymentToken = _paymentToken;
        mintablePrice = pricePerThousandTokens;
    }

    modifier onlyMagnetAI() {
        if (msg.sender != magnetAI) {
            revert NotMagnetAI(msg.sender);
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

    modifier afterLocked() {
        if (totalMintedAmount < maxSupply) {
            revert NotLocked(totalMintedAmount, maxSupply, block.timestamp, issuanceEndTime);
        }
        _;
    }

    modifier onlyOngoing() {
        if (totalMintedAmount >= maxSupply || block.timestamp < issuanceStartTime) {
            revert NotInOngoingPhase(totalMintedAmount, maxSupply, block.timestamp, issuanceEndTime);
        }
        _;
    }

    modifier onlyEnded() {
        if (!(issuanceEndTime != 0 && block.timestamp >= issuanceEndTime)) {
            revert NotEnded(totalMintedAmount, maxSupply, block.timestamp, issuanceEndTime);
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

    function mint(uint256 amount, uint256 price) external payable onlyWithinIssuance {
        // Get the timestamp of the start of the current slot
        uint256 currentSlot = calculateCurrentSlotStartTime();
        // Declare `excess` to record the excessive amount of minted token
        uint256 excess;
        // Declare `payment` to record the correct amount of token that `msg.sender` should pay
        uint256 payment;
        // Check `amount`
        _checkMintAmount(amount);
        // Check `price`
        _checkMintPrice(price, currentSlot, amount);
        // Get the values of latest mint of `msg.sender`
        uint256 amountOfPreviousMint = mints[msg.sender].amount;
        uint256 priceOfPreviousMint = mints[msg.sender].price;
        // Judge if the current mint is the first one in the current slot
        if (mints[headOfCurrentSlot].slot != currentSlot) {
            headOfCurrentSlot = msg.sender;
            mints[msg.sender].next = address(0);
            totalConfirmedAmount = totalMintedAmount;
            totalConfirmedPayment = totalPayment;
            uint256 amountAfterCurrentMint = totalMintedAmount + amount;
            if (amountAfterCurrentMint >= maxSupply) {
                if (amountAfterCurrentMint > maxSupply) {
                    excess = amountAfterCurrentMint - maxSupply;
                    // Refund
                    _transferAsset(address(0), msg.sender, excess * price);
                }
                mintablePrice = price + mintPriceIncrement;
            }
            payment = amount * price;
            mints[msg.sender].confirmedAmount += amountOfPreviousMint;
            mints[msg.sender].confirmedPayment += amountOfPreviousMint * priceOfPreviousMint;
            totalMintedAmount += amount - excess;
            totalPayment += payment - excess * price;
        } else {
            // Check if there is an another, earlier, mint of `msg.sender` in the same slot
            if (mints[msg.sender].slot == currentSlot) {
                if (amount < amountOfPreviousMint) {
                    revert LessMintAmount(amount, amountOfPreviousMint);
                }
                // The check of `price` has been done in {_checkMintPrice}
                if (amount == amountOfPreviousMint && price == priceOfPreviousMint) {
                    revert DuplicateMint(amount, price);
                }
                payment = amount * price - amountOfPreviousMint * priceOfPreviousMint;
                totalMintedAmount += amount - amountOfPreviousMint;
                totalPayment += payment;
            } else {
                payment = amount * price;
                mints[msg.sender].confirmedAmount += amountOfPreviousMint;
                mints[msg.sender].confirmedPayment += amountOfPreviousMint * priceOfPreviousMint;
                totalMintedAmount += amount;
                totalPayment += payment;
            }

            // Insertion sorting of the mints of the current slot considering the current mint
            excess = _sortMints(price, currentSlot, amount);
        }

        // Check `msg.value` or excute ERC20 token transfer
        if (paymentToken == address(0)) {
            if (msg.value < payment) {
                revert InsufficientETHPaid(msg.value, payment);
            }
            if (msg.value > payment) {
                // Refund the excessive payment of the current mint
                _transferAsset(address(0), msg.sender, msg.value - payment);
            }
        } else {
            // ERC20 token tranferred from `msg.sender` to `address(this)`
            _transferAsset(msg.sender, address(this), payment);
        }

        // Updates fields of the instance of struct `Mint` of `msg.sender`
        mints[msg.sender].amount = amount - excess;
        mints[msg.sender].price = price;
        mints[msg.sender].slot = currentSlot;

        // Check the status of the token issuance
        if (totalMintedAmount >= maxSupply && issuanceEndTime == 0) {
            issuanceEndTime = uint32(block.timestamp) + delayDuration;
        }
        
        emit TokenMinted(block.timestamp, msg.sender, amount, amount - excess, price);
    }

    function withdrawMint() external onlyOngoing {
        // Get the data from `Mint` instance of `msg.sender`
        // Assume `amount` and `price` of `msg.sender` are both updated at the same time. `amount` updated before the current slot will be set zero
        uint256 amount = mints[msg.sender].amount;
        uint256 totalAmount = mints[msg.sender].confirmedAmount + amount;
        uint256 _totalPayment = mints[msg.sender].confirmedPayment + amount * mints[msg.sender].price;
        // Ensure the payment of `msg.sender` withdrawable
        if (amount == 0 || totalAmount == 0) {
            revert NoneMinted(msg.sender);
        }
        // Update sorting
        _sortMintsAfterUserWithdrawal();

        // Update state variable of the token issuance
        if (mints[msg.sender].slot != calculateCurrentSlotStartTime()) {
            totalConfirmedAmount -= totalAmount;
            totalConfirmedPayment -= _totalPayment;
        } else {
            totalConfirmedAmount -= mints[msg.sender].confirmedAmount;
            totalConfirmedPayment -= mints[msg.sender].confirmedPayment;
        }
        totalMintedAmount -= totalAmount;
        totalPayment -= _totalPayment;

        // Reset the data of user
        delete mints[msg.sender];

        // Withdraw payment
        _transferAsset(address(0), msg.sender, _totalPayment);
        emit MintWithdrawal(block.timestamp, msg.sender, paymentToken, _totalPayment);
    }

    function claimToken() external onlyEnded {
        uint256 currentSlot = calculateCurrentSlotStartTime();
        uint256 amount = mints[msg.sender].amount;
        uint256 price = mints[msg.sender].price;
        uint256 totalAmount = mints[msg.sender].confirmedAmount + amount;
        // Ensure the minted amount of `msg.sender` is non-zero
        if (amount == 0 || totalAmount == 0) {
            revert NoneMinted(msg.sender);
        }
        uint256 actualMintedAmount;
        uint256 refund;
        if (mints[msg.sender].slot != currentSlot) {
            actualMintedAmount = totalAmount;
        } else {
            // The case that `msg.sender` has minted in the last slot(i.e. the slot that gets into the locked phase)
            uint256 priceOfLastFinalist = mintablePrice - mintPriceIncrement;
            // If `price` is definitely lower than `priceOfLastFinalist`, refund (`amount` * `price`) to `msg.sender`
            if (price < priceOfLastFinalist) {
                actualMintedAmount = mints[msg.sender].confirmedAmount;
                refund = amount * price;
            }
            if (price > priceOfLastFinalist) {
                actualMintedAmount = totalAmount;
            }
            if (price == priceOfLastFinalist) {
                (address lastFinalist,, uint256 amountBeforeLastFinalist, uint256 mintedAmount, uint256 refund) =
                    getLastFinalistData();
                if (lastFinalist == msg.sender) {
                    uint256 amountAfterLastFinalist = amount + amountBeforeLastFinalist;
                    // Assume that `amountAfterLastFinalist` cannot be less than `maxSupply`
                    if (amountAfterLastFinalist > maxSupply) {
                        // In this case, the mint of `msg.sender` in the last slot is partially successful
                        actualMintedAmount = maxSupply - amountBeforeLastFinalist + mints[msg.sender].confirmedAmount;
                        // Refund the payment corresponding to the excessive amount to `msg.sender`
                        refund = (amountAfterLastFinalist - maxSupply) * price;
                    } else if (amountAfterLastFinalist == maxSupply) {
                        actualMintedAmount = totalAmount;
                    }
                } else {
                    // The price of `msg.sender` equals to the one of `lastFinalist`, but the mint of `msg.sender` is later than `lastFinalist`
                    // Thus, the mint of `msg.sender` in the last slot(i.e. the slot that gets into the locked phase) is entirely unsuccessful
                    refund = amount * price;
                    // NOTE NEED A LITTLE TRANVERSE TO FIND THE MINTS In front of `msg.sender` but has the same mints
                    // Check if the position `msg.sender` is in front of the position of "lastFinalist"
                }
            }
        }
        // Reset
        delete mints[msg.sender];

        // Execute minting bot tokens
        if (actualMintedAmount != 0) {
            _mint(msg.sender, actualMintedAmount);
        }

        // Execute refund of unsuccessful mint
        if (refund != 0) {
            _transferAsset(address(0), msg.sender, refund);
        }

        emit TokenClaimed(msg.sender, actualMintedAmount, refund);
    }

    function claimFund() external onlyBotOwner onlyEnded {
        // Get the timestamp of the start of the current slot
        uint256 currentSlot = calculateCurrentSlotStartTime();
        // Sum up all the payment in the final slot of the token issuance via the following loop
        address current = headOfCurrentSlot;
        uint256 paymentInFinalSlot;
        while (mints[current].slot == currentSlot) {
            paymentInFinalSlot += mints[mints[current].next].price * mints[mints[current].next].amount;
            current = mints[current].next;
        }
    }

    function _transferAsset(address from, address recipient, uint256 tokenAmount) internal {
        if (paymentToken == address(0)) {
            if (from != address(0)) {
                revert ETHTransferWithFrom(paymentToken, from);
            }
            (bool ETHTransferSuccess,) = payable(recipient).call{value: tokenAmount}("");
            if (!ETHTransferSuccess) {
                revert ETHTranferFailed(recipient, tokenAmount);
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

    function calculateCurrentSlotStartTime() public view returns (uint256 currentSlot) {
        uint256 c = (block.timestamp - issuanceStartTime) / slotDuration;
        c = c * slotDuration;
        currentSlot = c + issuanceStartTime;
    }

    function _checkMintAmount(uint256 amount) internal view {
        if (amount == 0 || amount % 1000 != 0 || amount > maxSupply) {
            revert InvalidAmount(amount);
        }
    }

    function _checkMintPrice(uint256 price, uint256 currentSlot, uint256 amount) internal view {
        if (price == 0 || price % mintPriceIncrement != 0) {
            revert InvalidPrice(price, mintPriceIncrement);
        }
        uint256 basePrice;
        // Assume the "notStarted" phase has passed in the current call of this function
        if (mints[msg.sender].slot == currentSlot && totalMintedAmount < maxSupply) {
            // In this case, `mintablePrice` is equal to `pricePerThousandTokens` which must be lower than any of the two values as follows
            basePrice = amount > mints[msg.sender].amount
                ? mints[msg.sender].price
                : mints[msg.sender].price + mintPriceIncrement;
        } else {
            basePrice = mintablePrice;
        }

        if (price < basePrice) {
            revert InsufficientPriceOfMint(price, basePrice);
        }
    }

    /**
     * @dev Assume the price of the current mint is higher than any previous ones in the same slot, because price check has been done in
     * the preceding code of {mint}.
     */
    function _sortMints(uint256 price, uint256 currentSlot, uint256 amount) internal returns (uint256) {
        // Declare `result` which means the `next` of the mint of `msg.sender`(this will be `msg.sender` itself when its position does not change in sorting)
        address result;
        // Declare `excess` to record the excessive amount of minted token
        uint256 excess;
        if (msg.sender == headOfCurrentSlot) {
            // In this case, `msg.sender` has already minted with the highest price in the current slot
            result = msg.sender;
            uint256 amountAfterCurrentMint = totalMintedAmount + amount;
            if (amountAfterCurrentMint >= maxSupply) {
                if (amountAfterCurrentMint > maxSupply) {
                    excess = amountAfterCurrentMint - maxSupply;
                    // Refund
                    _transferAsset(address(0), msg.sender, excess * price);
                    // Update the value of state variables
                    totalMintedAmount -= excess;
                    totalPayment -= excess * price;
                }
                mintablePrice = price + mintPriceIncrement;
            }
        } else {
            // `insertion` means the "predecessor" of the position where the current mint inserts
            address insertion;
            address prev = address(1);
            address current = headOfCurrentSlot;
            address prior;
            if (totalMintedAmount >= maxSupply) {
                uint256 updatedAmount = totalConfirmedAmount;
                // Assume that `updatedAmount` must be lower than `maxSupply`
                while (updatedAmount < maxSupply) {
                    if (price != mints[msg.sender].price) {
                        // If `price` is larger than the price of `headOfCurrentSlot`, `insertion` will be `address(1)`
                        if (mints[current].price < price && insertion == address(0)) {
                            insertion = prev;
                        }
                        // In this case, `msg.sender` cannot be `headOfCurrentSlot`, so `prior` cannot be the initial value(i.e. `address(1)`)
                        if (mints[msg.sender].slot == currentSlot && current == msg.sender) {
                            prior = prev;
                        }
                    }
                    updatedAmount += mints[current].amount;
                    prev = current;
                    current = mints[current].next;
                }
                uint256 priceOfLastFinalist = mints[prev].price;
                if (updatedAmount > maxSupply) {
                    if (prev == msg.sender) {
                        excess = updatedAmount - maxSupply;
                        // Refund
                        _transferAsset(address(0), msg.sender, excess * priceOfLastFinalist);
                        // Update the value of state variables
                        totalMintedAmount -= excess;
                        totalPayment -= excess * priceOfLastFinalist;
                    }
                }
                mintablePrice = priceOfLastFinalist + mintPriceIncrement;
            } else {
                if (mints[msg.sender].slot != currentSlot) {
                    Mint memory currentMint = mints[current];
                    while (currentMint.slot == currentSlot && currentMint.price >= price) {
                        insertion = prev;
                        prev = current;
                        current = currentMint.next;
                        currentMint = mints[current];
                    }
                } else if (price != mints[msg.sender].price) {
                    while (current != msg.sender) {
                        if (mints[current].price < price && insertion == address(0)) {
                            insertion = prev;
                        }
                        prior = prev;
                        prev = current;
                        current = mints[current].next;
                    }
                }
            }
            // When `msg.sender` has a previous mint in the current slot and its current mint has a different position in sorting
            if (prior != address(0) && insertion != address(0) && insertion != prior) {
                // Eliminate the old-sorted position of `msg.sender` if its postion in sorting has updated to a different one.
                if (mints[mints[msg.sender].next].slot == currentSlot) {
                    mints[prior].next = mints[msg.sender].next;
                } else {
                    mints[prior].next = address(0);
                }
            }

            // Record the correct `next` of the current mint of `msg.sender` by the local variable `result`
            if (insertion == address(1)) {
                result = headOfCurrentSlot;
                headOfCurrentSlot = msg.sender;
            } else {
                if (insertion != address(0)) {
                    if (mints[mints[insertion].next].slot == currentSlot) {
                        result = mints[insertion].next;
                    }
                } else {
                    result = msg.sender;
                }
            }

            // Execute the update of the field `next` of the mint of `insertion`
            if (mints[insertion].next != msg.sender && insertion != address(0) && insertion != address(1)) {
                mints[insertion].next = msg.sender;
            }
        }
        // Execute the update the field `next` of the mint of `msg.sender`
        if (result != msg.sender) {
            mints[msg.sender].next = result;
        }

        return excess;
    }

    function _sortMintsAfterUserWithdrawal() internal {
        // Get the timestamp of the start of the current slot
        uint256 currentSlot = calculateCurrentSlotStartTime();
        // Check if `msg.sender` is `headOfCurrentSlot`
        if (mints[mints[msg.sender].next].slot == currentSlot) {
            if (msg.sender == headOfCurrentSlot) {
                headOfCurrentSlot = mints[msg.sender].next;
            } else {
                address current = headOfCurrentSlot;
                uint256 slotOfUser = mints[msg.sender].slot;
                if (slotOfUser == currentSlot) {
                    while (mints[current].next != msg.sender) {
                        current = mints[current].next;
                    }
                    mints[current].next = mints[msg.sender].next;
                }
            }
        }
    }

    function getLastFinalistData()
        public
        view
        afterLocked
        returns (
            address lastFinalist,
            uint256 _mintablePrice,
            uint256 amountBeforeLastFinalist,
            uint256 mintedAmount,
            uint256 refund
        )
    {
        address current = headOfCurrentSlot;
        uint256 updatedAmount = totalConfirmedAmount + mints[current].amount;
        // After the token issuance steps into "locked" phase, two assumptions:
        // First, `mints[headOfCurrentSlot].next` can not be `address(0)`
        // Second, the mint which reaches `maxSupply` is within the last slot of the entire token issuance
        while (updatedAmount < maxSupply) {
            updatedAmount += mints[mints[current].next].amount;
            current = mints[current].next;
        }
        lastFinalist = current;
        _mintablePrice = mints[current].price + mintPriceIncrement;
        amountBeforeLastFinalist = updatedAmount - mints[current].amount;
        if (updatedAmount > maxSupply) {
            // Refund the payment corresponding to the excessive amount to `msg.sender`
            refund = (updatedAmount - maxSupply) * mints[msg.sender].price;
        }
        mintedAmount = maxSupply - amountBeforeLastFinalist;
    }

    function getIssuanceStatus() public view returns (string memory status) {
        if (block.timestamp < issuanceStartTime) {
            return "notStarted";
        }
        if (block.timestamp >= issuanceStartTime && totalMintedAmount < maxSupply) {
            return "ongoing";
        }
        if (totalMintedAmount >= maxSupply && block.timestamp < issuanceEndTime) {
            return "locked";
        }
        if (issuanceEndTime != 0 && block.timestamp >= issuanceEndTime) {
            return "closed";
        }
    }
}
