// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ECommerce Marketplace Contract
/// @author rocknwa
/// @notice This contract allows sellers to list products, buyers to purchase with USDC, and handles fees, penalties, and reporting.
/// @dev All percentages are stored as integers (e.g. 5 = 5%). USDC is assumed to use 6 decimals.
contract ECommerce is Ownable(msg.sender) {
    IERC20 public usdc;
    uint8 public constant USDC_DECIMALS = 6;

    // =========================
    // ======= Errors ==========
    // =========================

    error ZeroAddress();
    error SellerNameRequired();
    error ProfileURIRequired();
    error LocationRequired();
    error PhoneNumberRequired();
    error SellerAlreadyRegistered();
    error ProductNameRequired();
    error ProductImageRequired();
    error ProductPriceZero();
    error ProductInventoryZero();
    error ErrSellerBlocked();
    error SellerNotRegistered();
    error ProductDoesNotExist();
    error ProductOutOfStock();
    error SellerCannotBuyOwnProduct();
    error ProductAlreadyPurchased();
    error USDCTransferFailed();
    error NoPaymentForProduct();
    error ProductAlreadyConfirmed();
    error RefundToBuyerFailed();
    error PenaltyToSellerFailed();
    error ProductNotPaid();
    error ProductAlreadySold();
    error BuyerDidNotCancel();
    error AlreadyReported();
    error InvalidWithdrawAddress();
    error FeeTransferFailed();
    error SellerHasNoConfirmedPurchases();
    error SellerRatingExceeded();
    error SellerIsBlocked();
    error ErrSellerNotBlocked();

    // =========================
    // ======= Constants =======
    // =========================

    uint256 public constant FEE_PERCENTAGE = 5;  // 5%
    uint256 public constant PENALTY_PERCENTAGE = 3;  // 3%
    uint256 public constant CANCELLATION_PENALTY_PERCENTAGE = 10;  // 10%
    uint256 public constant SELLER_BLOCK_REPORTS_THRESHOLD = 3; // Reports to block seller

    // =========================
    // ======= Structs =========
    // =========================

    /// @notice Product struct to represent listed products
    struct Product {
        uint id;
        string name;
        string imageUrl;
        uint price; // price in USDC (with 6 decimals)
        address payable seller;
        string sellerName;
        string description;
        uint inventory;
        uint totalSold;
    }

    /// @notice Purchase struct to track individual purchases
    struct Purchase {
        uint productId;
        address payable buyer;
        bool isPaid;
        bool isSold;
    }

    /// @notice Seller struct to track seller statistics
    struct Seller {
        string name;
        string profileURI;
        uint256 confirmedPurchases;
        uint256 canceledPurchases;
        uint256 reportedPurchases;
        uint256 rating;
    }

    /// @notice Seller contact information
    struct SellerContact {
        string location;
        string phoneNumber;
    }

    /// @notice Blocked seller information
    struct BlockedSeller {
        address sellerAddress;
        string reason;
    }

    // =========================
    // ======= Storage =========
    // =========================

    uint public productCount = 0;
    mapping(uint => Product) public products;
    mapping(address => Seller) public sellers;
    mapping(address => SellerContact) public sellerContacts;
    mapping(address => BlockedSeller) public blockedSellers;
    mapping(address => bool) public isSellerBlocked;
    mapping(uint => mapping(address => bool)) public hasReported;
    mapping(uint => mapping(address => Purchase)) public purchases;
    mapping(uint => mapping(address => bool)) public buyerCanceled;

    uint public totalFeesCollected = 0; // in USDC (6 decimals)

    // =========================
    // ======= Events ==========
    // =========================

    /// @notice Emitted when a new product is created
    event ProductCreated(
        uint id,
        string name,
        string imageUrl,
        uint price,
        address payable seller,
        string sellerName,
        uint inventory
    );

    /// @notice Emitted when a product is purchased
    event ProductPurchased(
        uint id,
        string name,
        uint price,
        address payable seller,
        address payable buyer,
        bool isPaid
    );

    /// @notice Emitted when a payment is confirmed by the buyer
    event PaymentConfirmed(
        uint id,
        string name,
        uint price,
        address payable seller,
        address payable buyer
    );

    /// @notice Emitted when a seller is registered
    event SellerRegistered(
        address indexed sellerAddress,
        string name,
        string profileURI
    );

    /// @notice Emitted when a seller is rated
    event SellerRated(
        address indexed sellerAddress,
        uint256 rating
    );

    /// @notice Emitted when a seller is blocked
    event SellerBlocked(address indexed sellerAddress, string reason);

    /// @notice Emitted when a seller is unblocked
    event SellerUnblocked(address indexed sellerAddress);

    /// @notice Contract constructor
    /// @param _usdc The address of the USDC token contract
    constructor(address _usdc) {
        if (_usdc == address(0)) revert ZeroAddress();
        usdc = IERC20(_usdc);
    }

    /// @notice Register a new seller with contact information
    /// @param _name Seller's name
    /// @param _profileURI URI for seller's profile
    /// @param _location Seller's location
    /// @param _phoneNumber Seller's phone number
    function registerSeller(
        string memory _name,
        string memory _profileURI,
        string memory _location,
        string memory _phoneNumber
    ) public {
        if (bytes(_name).length == 0) revert SellerNameRequired();
        if (bytes(_profileURI).length == 0) revert ProfileURIRequired();
        if (bytes(_location).length == 0) revert LocationRequired();
        if (bytes(_phoneNumber).length == 0) revert PhoneNumberRequired();
        if (bytes(sellers[msg.sender].name).length != 0) revert SellerAlreadyRegistered();

        sellers[msg.sender] = Seller(_name, _profileURI, 0, 0, 0, 0);
        sellerContacts[msg.sender] = SellerContact(_location, _phoneNumber);

        emit SellerRegistered(msg.sender, _name, _profileURI);
    }

    /// @notice Create a new product listing
    /// @param _name Name of the product
    /// @param _imageUrl URL to the product image
    /// @param _price Price in USDC (6 decimals)
    /// @param _description Product description
    /// @param _inventory Number of available units
    function createProduct(
        string memory _name,
        string memory _imageUrl,
        uint _price,
        string memory _description,
        uint _inventory
    ) public {
        if (bytes(_name).length == 0) revert ProductNameRequired();
        if (bytes(_imageUrl).length == 0) revert ProductImageRequired();
        if (_price == 0) revert ProductPriceZero();
        if (_inventory == 0) revert ProductInventoryZero();
        if (isSellerBlocked[msg.sender]) revert ErrSellerBlocked();
        if (bytes(sellers[msg.sender].name).length == 0) revert SellerNotRegistered();

        productCount++;
        products[productCount] = Product(
            productCount, _name, _imageUrl, _price, payable(msg.sender),
            sellers[msg.sender].name, _description, _inventory, 0
        );

        emit ProductCreated(
            productCount, _name, _imageUrl, _price, payable(msg.sender),
            sellers[msg.sender].name, _inventory
        );
    }

    /// @notice Purchase a product using USDC. Must approve USDC before calling.
    /// @param _id The product ID to purchase
    function purchaseProduct(uint _id) public {
        Product storage _product = products[_id];
        if (_product.id == 0 || _product.id > productCount) revert ProductDoesNotExist();
        if (_product.inventory == 0) revert ProductOutOfStock();
        if (_product.seller == msg.sender) revert SellerCannotBuyOwnProduct();
        if (purchases[_id][msg.sender].isPaid) revert ProductAlreadyPurchased();
        
         _product.inventory -= 1;
        purchases[_id][msg.sender] = Purchase(_id, payable(msg.sender), true, false);

        emit ProductPurchased(_id, _product.name, _product.price, _product.seller, payable(msg.sender), true);
        // Transfer USDC from buyer to contract
        bool success = usdc.transferFrom(msg.sender, address(this), _product.price);
        if (!success) revert USDCTransferFailed();
    }

    /// @notice Confirm receipt/payment and release funds to seller
    /// @param _id The product ID purchased
    function confirmPayment(uint _id) public {
        Product storage _product = products[_id];
        Purchase storage purchase = purchases[_id][msg.sender];
        if (!purchase.isPaid) revert NoPaymentForProduct();
        if (purchase.isSold) revert ProductAlreadyConfirmed();

        uint fee = (_product.price * FEE_PERCENTAGE) / 100;
        uint paymentToSeller = _product.price - fee;

        totalFeesCollected += fee;
        purchase.isSold = true;
        _product.totalSold += 1;

        // Update seller's confirmed purchases
        sellers[_product.seller].confirmedPurchases += 1;

        emit PaymentConfirmed(_id, _product.name, _product.price, _product.seller, payable(msg.sender));
         // Transfer USDC to the seller
        bool success = usdc.transfer(_product.seller, paymentToSeller);
        if (!success) revert USDCTransferFailed();
    }

    /// @notice Cancel a purchase. Buyer receives refund minus penalty, seller receives penalty.
    /// @param _id The product ID purchased
    function cancelPurchase(uint _id) public {
        Product storage _product = products[_id];
        Purchase storage purchase = purchases[_id][msg.sender];

        if (!purchase.isPaid) revert ProductNotPaid();
        if (purchase.isSold) revert ProductAlreadySold();

        uint penalty = (_product.price * CANCELLATION_PENALTY_PERCENTAGE) / 100;
        uint refundToBuyer = _product.price - penalty;
        uint fee = (penalty * PENALTY_PERCENTAGE) / 100;
        uint paymentToSeller = penalty - fee;

        totalFeesCollected += fee;
        purchase.isPaid = false;

        // Update seller's canceled purchases
        sellers[_product.seller].canceledPurchases += 1;

        // Mark that the buyer has canceled this product
        buyerCanceled[_id][msg.sender] = true;

        // Return product to stock
        _product.inventory += 1;

   // Transfer USDC back to the buyer and to the seller as penalty
        bool refundSuccess = usdc.transfer(purchase.buyer, refundToBuyer);
        if (!refundSuccess) revert RefundToBuyerFailed();
        bool penaltySuccess = usdc.transfer(_product.seller, paymentToSeller);
        if (!penaltySuccess) revert PenaltyToSellerFailed();
    }

    /// @notice Report a cancelled purchase (for possible seller block)
    /// @param _id The product ID
    function reportCanceledPurchase(uint _id) public {
        if (!buyerCanceled[_id][msg.sender]) revert BuyerDidNotCancel();
        if (hasReported[_id][msg.sender]) revert AlreadyReported();

        // Mark as reported
        hasReported[_id][msg.sender] = true;

        // Update seller's reported purchases
        Product storage _product = products[_id];
        sellers[_product.seller].reportedPurchases += 1;

        // Check if seller should be blocked
        if (
            sellers[_product.seller].reportedPurchases >= SELLER_BLOCK_REPORTS_THRESHOLD
            && sellers[_product.seller].confirmedPurchases == 0
        ) {
            blockSeller(_product.seller, "Multiple reports with no confirmed purchases");
        }
    }

    /// @notice Rate a seller after successful purchase
    /// @param _seller The address of the seller to rate
    function rateSeller(address _seller) public {
        if (sellers[_seller].confirmedPurchases == 0) revert SellerHasNoConfirmedPurchases();
        if (sellers[_seller].rating >= sellers[_seller].confirmedPurchases) revert SellerRatingExceeded();

        // Increment the seller's rating
        sellers[_seller].rating++;

        emit SellerRated(_seller, sellers[_seller].rating);
    }

    /// @notice Get blocked seller details
    /// @param _seller The address of the blocked seller
    /// @return BlockedSeller struct containing reason and address
    function getBlockedSellerDetails(address _seller) public view returns (BlockedSeller memory) {
        if (!isSellerBlocked[_seller]) revert ErrSellerNotBlocked();
        return blockedSellers[_seller];
    }

    /// @notice Get seller contact details for a product (only for buyers who have paid)
    /// @param _id Product ID
    /// @return SellerContact struct with location and phone number
    function getSellerDetails(uint _id) public view returns (SellerContact memory) {
        if (!purchases[_id][msg.sender].isPaid) revert NoPaymentForProduct();
        return sellerContacts[products[_id].seller];
    }

    /// @notice Get product details by ID
    /// @param _id Product ID
    /// @return Product struct
    function getProduct(uint _id) public view returns (Product memory) {
        return products[_id];
    }

    /// @notice Get purchase details for a product and buyer
    /// @param _id Product ID
    /// @param _buyer Buyer address
    /// @return Purchase struct
    function getPurchase(uint _id, address _buyer) public view returns (Purchase memory) {
        return purchases[_id][_buyer];
    }

    /// @notice Withdraw collected fees (USDC) to a specified address. Only owner can call.
    /// @param to The address to which fees will be transferred
    function withdrawFees(address to) public onlyOwner {
        if (to == address(0)) revert InvalidWithdrawAddress();
        uint amount = totalFeesCollected;
        totalFeesCollected = 0;
        bool success = usdc.transfer(to, amount);
        if (!success) revert FeeTransferFailed();
    }

    /// @notice Block a seller for repeated reports or other reasons (internal)
    /// @param _seller Seller address to block
    /// @param _reason Reason for blocking the seller
    function blockSeller(address _seller, string memory _reason) internal {
        if (isSellerBlocked[_seller]) revert ErrSellerBlocked();

        blockedSellers[_seller] = BlockedSeller(_seller, _reason);
        isSellerBlocked[_seller] = true;

        emit SellerBlocked(_seller, _reason);
    }

    /// @notice Unblock a seller (only owner can call)
    /// @param _seller Seller address to unblock
    function unblockSeller(address _seller) public onlyOwner {
        if (!isSellerBlocked[_seller]) revert ErrSellerNotBlocked();

        isSellerBlocked[_seller] = false;
        delete blockedSellers[_seller];

        emit SellerUnblocked(_seller);
    }

    /// @notice Get the total fees collected in USDC
    /// @return Total fees collected
    function getTotalFeesCollected() public view returns (uint256) {
        return totalFeesCollected;
    }

    function blockSellerByOwner(address _seller, string memory _reason) public onlyOwner {
    if (isSellerBlocked[_seller]) revert ErrSellerBlocked();
    blockedSellers[_seller] = BlockedSeller(_seller, _reason);
    isSellerBlocked[_seller] = true;
    emit SellerBlocked(_seller, _reason);
}
}