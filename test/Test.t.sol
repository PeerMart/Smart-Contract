// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/ECommerce.sol";
import "../src/MockUSDC.sol";

contract ECommerceTest is Test {
    ECommerce public marketplace;
    MockUSDC public usdc;
    
    address public owner;
    address public seller1;
    address public seller2;
    address public buyer1;
    address public buyer2;
    address public feeRecipient;
    
    uint256 public constant INITIAL_USDC_SUPPLY = 1_000_000 * 10**6; // 1M USDC
    uint256 public constant PRODUCT_PRICE = 100 * 10**6; // 100 USDC
    
    event ProductCreated(
        uint id,
        string name,
        string imageUrl,
        uint price,
        address payable seller,
        string sellerName,
        uint inventory
    );
    
    event ProductPurchased(
        uint id,
        string name,
        uint price,
        address payable seller,
        address payable buyer,
        bool isPaid
    );
    
    event PaymentConfirmed(
        uint id,
        string name,
        uint price,
        address payable seller,
        address payable buyer
    );
    
    event SellerRegistered(
        address indexed sellerAddress,
        string name,
        string profileURI
    );
    
    event SellerBlocked(address indexed sellerAddress, string reason);
    event SellerUnblocked(address indexed sellerAddress);
    event SellerRated(address indexed sellerAddress, uint256 rating);

    function setUp() public {
        owner = address(this);
        seller1 = makeAddr("seller1");
        seller2 = makeAddr("seller2");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        feeRecipient = makeAddr("feeRecipient");
        
        // Deploy MockUSDC and ECommerce
        usdc = new MockUSDC(INITIAL_USDC_SUPPLY);
        marketplace = new ECommerce(address(usdc));
        
        // Distribute USDC to test accounts
        usdc.mint(seller1, 10_000 * 10**6);
        usdc.mint(seller2, 10_000 * 10**6);
        usdc.mint(buyer1, 10_000 * 10**6);
        usdc.mint(buyer2, 10_000 * 10**6);
        
        // Register sellers
        vm.startPrank(seller1);
        marketplace.registerSeller("Seller One", "https://profile1.com", "New York", "+1234567890");
        vm.stopPrank();
        
        vm.startPrank(seller2);
        marketplace.registerSeller("Seller Two", "https://profile2.com", "Los Angeles", "+0987654321");
        vm.stopPrank();
    }
    
    // ============= Constructor Tests =============
    
    function testConstructor() public {
        assertEq(address(marketplace.usdc()), address(usdc));
        assertEq(marketplace.owner(), owner);
        assertEq(marketplace.productCount(), 0);
        assertEq(marketplace.getTotalFeesCollected(), 0);
    }
    
    function testConstructorZeroAddress() public {
        vm.expectRevert(ECommerce.ZeroAddress.selector);
        new ECommerce(address(0));
    }
    
    // ============= Seller Registration Tests =============
    
    function testRegisterSeller() public {
        address newSeller = makeAddr("newSeller");
        
        vm.expectEmit(true, false, false, true);
        emit SellerRegistered(newSeller, "New Seller", "https://newprofile.com");
        
        vm.prank(newSeller);
        marketplace.registerSeller("New Seller", "https://newprofile.com", "Miami", "+1111111111");
        
        (string memory name, string memory profileURI, uint256 confirmed, uint256 canceled, uint256 reported, uint256 rating) = marketplace.sellers(newSeller);
        assertEq(name, "New Seller");
        assertEq(profileURI, "https://newprofile.com");
        assertEq(confirmed, 0);
        assertEq(canceled, 0);
        assertEq(reported, 0);
        assertEq(rating, 0);
        
        (string memory location, string memory phone) = marketplace.sellerContacts(newSeller);
        assertEq(location, "Miami");
        assertEq(phone, "+1111111111");
    }
    
    function testRegisterSellerValidationErrors() public {
        address newSeller = makeAddr("newSeller");
        
        vm.startPrank(newSeller);
        
        // Empty name
        vm.expectRevert(ECommerce.SellerNameRequired.selector);
        marketplace.registerSeller("", "https://profile.com", "Location", "Phone");
        
        // Empty profile URI
        vm.expectRevert(ECommerce.ProfileURIRequired.selector);
        marketplace.registerSeller("Name", "", "Location", "Phone");
        
        // Empty location
        vm.expectRevert(ECommerce.LocationRequired.selector);
        marketplace.registerSeller("Name", "https://profile.com", "", "Phone");
        
        // Empty phone
        vm.expectRevert(ECommerce.PhoneNumberRequired.selector);
        marketplace.registerSeller("Name", "https://profile.com", "Location", "");
        
        // Valid registration
        marketplace.registerSeller("Name", "https://profile.com", "Location", "Phone");
        
        // Already registered
        vm.expectRevert(ECommerce.SellerAlreadyRegistered.selector);
        marketplace.registerSeller("New Name", "https://newprofile.com", "New Location", "New Phone");
        
        vm.stopPrank();
    }
    
    // ============= Product Creation Tests =============
    
    function testCreateProduct() public {
        vm.expectEmit(true, false, false, true);
        emit ProductCreated(1, "Test Product", "https://image.com", PRODUCT_PRICE, payable(seller1), "Seller One", 10);
        
        vm.prank(seller1);
        marketplace.createProduct("Test Product", "https://image.com", PRODUCT_PRICE, "Great product", 10);
        
        assertEq(marketplace.productCount(), 1);
        
        ECommerce.Product memory product = marketplace.getProduct(1);
        assertEq(product.id, 1);
        assertEq(product.name, "Test Product");
        assertEq(product.imageUrl, "https://image.com");
        assertEq(product.price, PRODUCT_PRICE);
        assertEq(product.seller, seller1);
        assertEq(product.sellerName, "Seller One");
        assertEq(product.description, "Great product");
        assertEq(product.inventory, 10);
        assertEq(product.totalSold, 0);
    }
    
    function testCreateProductValidationErrors() public {
        vm.startPrank(seller1);
        
        // Empty name
        vm.expectRevert(ECommerce.ProductNameRequired.selector);
        marketplace.createProduct("", "https://image.com", PRODUCT_PRICE, "Description", 10);
        
        // Empty image URL
        vm.expectRevert(ECommerce.ProductImageRequired.selector);
        marketplace.createProduct("Product", "", PRODUCT_PRICE, "Description", 10);
        
        // Zero price
        vm.expectRevert(ECommerce.ProductPriceZero.selector);
        marketplace.createProduct("Product", "https://image.com", 0, "Description", 10);
        
        // Zero inventory
        vm.expectRevert(ECommerce.ProductInventoryZero.selector);
        marketplace.createProduct("Product", "https://image.com", PRODUCT_PRICE, "Description", 0);
        
        vm.stopPrank();
    }
    
    function testCreateProductByUnregisteredSeller() public {
        address unregisteredSeller = makeAddr("unregistered");
        
        vm.prank(unregisteredSeller);
        vm.expectRevert(ECommerce.SellerNotRegistered.selector);
        marketplace.createProduct("Product", "https://image.com", PRODUCT_PRICE, "Description", 10);
    }
    
    function testCreateProductByBlockedSeller() public {
        // Block seller1
        marketplace.blockSellerByOwner(seller1, "Test block");
        
        vm.prank(seller1);
        vm.expectRevert(ECommerce.ErrSellerBlocked.selector);
        marketplace.createProduct("Product", "https://image.com", PRODUCT_PRICE, "Description", 10);
    }
    
    // ============= Product Purchase Tests =============
    
    function testPurchaseProduct() public {
        // Create product
        vm.prank(seller1);
        marketplace.createProduct("Test Product", "https://image.com", PRODUCT_PRICE, "Great product", 10);
        
        // Approve USDC spending
        vm.prank(buyer1);
        usdc.approve(address(marketplace), PRODUCT_PRICE);
        
        // Expect event
        vm.expectEmit(true, false, false, true);
        emit ProductPurchased(1, "Test Product", PRODUCT_PRICE, payable(seller1), payable(buyer1), true);
        
        // Purchase product
        vm.prank(buyer1);
        marketplace.purchaseProduct(1);
        
        // Check purchase details
        ECommerce.Purchase memory purchase = marketplace.getPurchase(1, buyer1);
        assertEq(purchase.productId, 1);
        assertEq(purchase.buyer, buyer1);
        assertTrue(purchase.isPaid);
        assertFalse(purchase.isSold);
        
        // Check inventory decreased
        ECommerce.Product memory product = marketplace.getProduct(1);
        assertEq(product.inventory, 9);
        
        // Check USDC was transferred to contract
        assertEq(usdc.balanceOf(address(marketplace)), PRODUCT_PRICE);
        assertEq(usdc.balanceOf(buyer1), 10_000 * 10**6 - PRODUCT_PRICE);
    }
    
    function testPurchaseProductErrors() public {
        // Create product with limited inventory
        vm.prank(seller1);
        marketplace.createProduct("Test Product", "https://image.com", PRODUCT_PRICE, "Great product", 1);
        
        // Non-existent product
        vm.prank(buyer1);
        vm.expectRevert(ECommerce.ProductDoesNotExist.selector);
        marketplace.purchaseProduct(999);
        
        // Seller cannot buy own product
        vm.prank(seller1);
        vm.expectRevert(ECommerce.SellerCannotBuyOwnProduct.selector);
        marketplace.purchaseProduct(1);
        
        // Purchase the only item
        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), PRODUCT_PRICE);
        marketplace.purchaseProduct(1);
        vm.stopPrank();
        
        // Out of stock
        vm.prank(buyer2);
        vm.expectRevert(ECommerce.ProductOutOfStock.selector);
        marketplace.purchaseProduct(1);
        
        // Already purchased
        vm.prank(buyer1);
        vm.expectRevert();
        marketplace.purchaseProduct(1);
    }
    
    function testPurchaseProductUSDCTransferFail() public {
        vm.prank(seller1);
        marketplace.createProduct("Test Product", "https://image.com", PRODUCT_PRICE, "Great product", 10);
        
        // Don't approve USDC spending
        vm.prank(buyer1);
        vm.expectRevert();
        marketplace.purchaseProduct(1);
    }
    
    // ============= Payment Confirmation Tests =============
    
    function testConfirmPayment() public {
        // Setup purchase
        vm.prank(seller1);
        marketplace.createProduct("Test Product", "https://image.com", PRODUCT_PRICE, "Great product", 10);
        
        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), PRODUCT_PRICE);
        marketplace.purchaseProduct(1);
        vm.stopPrank();
        
        uint256 sellerBalanceBefore = usdc.balanceOf(seller1);
        
        // Expect event
        vm.expectEmit(true, false, false, true);
        emit PaymentConfirmed(1, "Test Product", PRODUCT_PRICE, payable(seller1), payable(buyer1));
        
        // Confirm payment
        vm.prank(buyer1);
        marketplace.confirmPayment(1);
        
        // Check purchase is now sold
        ECommerce.Purchase memory purchase = marketplace.getPurchase(1, buyer1);
        assertTrue(purchase.isSold);
        
        // Check product total sold increased
        ECommerce.Product memory product = marketplace.getProduct(1);
        assertEq(product.totalSold, 1);
        
        // Check seller's confirmed purchases increased
        (, , uint256 confirmed, , ,) = marketplace.sellers(seller1);
        assertEq(confirmed, 1);
        
        // Check fee calculation (5% of 100 USDC = 5 USDC)
        uint256 expectedFee = PRODUCT_PRICE * 5 / 100;
        uint256 expectedPayment = PRODUCT_PRICE - expectedFee;
        
        assertEq(usdc.balanceOf(seller1), sellerBalanceBefore + expectedPayment);
        assertEq(marketplace.getTotalFeesCollected(), expectedFee);
    }
    
    function testConfirmPaymentErrors() public {
        vm.prank(seller1);
        marketplace.createProduct("Test Product", "https://image.com", PRODUCT_PRICE, "Great product", 10);
        
        // No payment for product
        vm.prank(buyer1);
        vm.expectRevert(ECommerce.NoPaymentForProduct.selector);
        marketplace.confirmPayment(1);
        
        // Setup purchase
        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), PRODUCT_PRICE);
        marketplace.purchaseProduct(1);
        marketplace.confirmPayment(1);
        vm.stopPrank();
        
        // Already confirmed
        vm.prank(buyer1);
        vm.expectRevert(ECommerce.ProductAlreadyConfirmed.selector);
        marketplace.confirmPayment(1);
    }
    
    // ============= Purchase Cancellation Tests =============
    
    function testCancelPurchase() public {
        // Setup purchase
        vm.prank(seller1);
        marketplace.createProduct("Test Product", "https://image.com", PRODUCT_PRICE, "Great product", 10);
        
        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), PRODUCT_PRICE);
        marketplace.purchaseProduct(1);
        vm.stopPrank();
        
        uint256 buyer1BalanceBefore = usdc.balanceOf(buyer1);
        uint256 seller1BalanceBefore = usdc.balanceOf(seller1);
        
        // Cancel purchase
        vm.prank(buyer1);
        marketplace.cancelPurchase(1);
        
        // Check purchase is no longer paid
        ECommerce.Purchase memory purchase = marketplace.getPurchase(1, buyer1);
        assertFalse(purchase.isPaid);
        
        // Check inventory was restored
        ECommerce.Product memory product = marketplace.getProduct(1);
        assertEq(product.inventory, 10);
        
        // Check seller's canceled purchases increased
        (, , , uint256 canceled, ,) = marketplace.sellers(seller1);
        assertEq(canceled, 1);
        
        // Check buyer cancellation flag
        assertTrue(marketplace.buyerCanceled(1, buyer1));
        
        // Check refund and penalty (10% penalty = 10 USDC, 3% fee on penalty = 0.3 USDC)
        uint256 penalty = PRODUCT_PRICE * 10 / 100; // 10 USDC
        uint256 refund = PRODUCT_PRICE - penalty; // 90 USDC
        uint256 feeOnPenalty = penalty * 3 / 100; // 0.3 USDC
        uint256 penaltyToSeller = penalty - feeOnPenalty; // 9.7 USDC
        
        assertEq(usdc.balanceOf(buyer1), buyer1BalanceBefore + refund);
        assertEq(usdc.balanceOf(seller1), seller1BalanceBefore + penaltyToSeller);
        assertEq(marketplace.getTotalFeesCollected(), feeOnPenalty);
    }
    
    function testCancelPurchaseErrors() public {
        vm.prank(seller1);
        marketplace.createProduct("Test Product", "https://image.com", PRODUCT_PRICE, "Great product", 10);
        
        // Product not paid
        vm.prank(buyer1);
        vm.expectRevert(ECommerce.ProductNotPaid.selector);
        marketplace.cancelPurchase(1);
        
        // Setup and confirm purchase
        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), PRODUCT_PRICE);
        marketplace.purchaseProduct(1);
        marketplace.confirmPayment(1);
        vm.stopPrank();
        
        // Product already sold
        vm.prank(buyer1);
        vm.expectRevert(ECommerce.ProductAlreadySold.selector);
        marketplace.cancelPurchase(1);
    }
    
    // ============= Reporting Tests =============
    
    function testReportCanceledPurchase() public {
        // Setup and cancel purchase
        vm.prank(seller1);
        marketplace.createProduct("Test Product", "https://image.com", PRODUCT_PRICE, "Great product", 10);
        
        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), PRODUCT_PRICE);
        marketplace.purchaseProduct(1);
        marketplace.cancelPurchase(1);
        marketplace.reportCanceledPurchase(1);
        vm.stopPrank();
        
        // Check seller's reported purchases increased
        (, , , , uint256 reported,) = marketplace.sellers(seller1);
        assertEq(reported, 1);
        
        // Check report flag
        assertTrue(marketplace.hasReported(1, buyer1));
    }
    
    function testReportCanceledPurchaseErrors() public {
        vm.prank(seller1);
        marketplace.createProduct("Test Product", "https://image.com", PRODUCT_PRICE, "Great product", 10);
        
        // Buyer did not cancel
        vm.prank(buyer1);
        vm.expectRevert(ECommerce.BuyerDidNotCancel.selector);
        marketplace.reportCanceledPurchase(1);
        
        // Setup cancellation and report
        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), PRODUCT_PRICE);
        marketplace.purchaseProduct(1);
        marketplace.cancelPurchase(1);
        marketplace.reportCanceledPurchase(1);
        vm.stopPrank();
        
        // Already reported
        vm.prank(buyer1);
        vm.expectRevert(ECommerce.AlreadyReported.selector);
        marketplace.reportCanceledPurchase(1);
    }
    
    function testSellerBlockedAfterReports() public {
        // Create 3 products and have them cancelled and reported
        vm.startPrank(seller1);
        marketplace.createProduct("Product 1", "https://image1.com", PRODUCT_PRICE, "Description 1", 10);
        marketplace.createProduct("Product 2", "https://image2.com", PRODUCT_PRICE, "Description 2", 10);
        marketplace.createProduct("Product 3", "https://image3.com", PRODUCT_PRICE, "Description 3", 10);
        vm.stopPrank();
        
        // Three different buyers cancel and report
        address[] memory buyers = new address[](3);
        buyers[0] = buyer1;
        buyers[1] = buyer2;
        buyers[2] = makeAddr("buyer3");
        
        // Give USDC to third buyer
        usdc.mint(buyers[2], 10_000 * 10**6);
        
        for (uint i = 0; i < 3; i++) {
            vm.startPrank(buyers[i]);
            usdc.approve(address(marketplace), PRODUCT_PRICE);
            marketplace.purchaseProduct(i + 1);
            marketplace.cancelPurchase(i + 1);
            vm.stopPrank();
        }
        
        // First two reports shouldn't block seller
        vm.prank(buyers[0]);
        marketplace.reportCanceledPurchase(1);
        assertFalse(marketplace.isSellerBlocked(seller1));
        
        vm.prank(buyers[1]);
        marketplace.reportCanceledPurchase(2);
        assertFalse(marketplace.isSellerBlocked(seller1));
        
        // Third report should block seller (3 reports, 0 confirmed purchases)
        vm.expectEmit(true, false, false, true);
        emit SellerBlocked(seller1, "Multiple reports with no confirmed purchases");
        
        vm.prank(buyers[2]);
        marketplace.reportCanceledPurchase(3);
        
        assertTrue(marketplace.isSellerBlocked(seller1));
    }
    
    // ============= Seller Rating Tests =============
    
    function testRateSeller() public {
        // Setup confirmed purchase
        vm.prank(seller1);
        marketplace.createProduct("Test Product", "https://image.com", PRODUCT_PRICE, "Great product", 10);
        
        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), PRODUCT_PRICE);
        marketplace.purchaseProduct(1);
        marketplace.confirmPayment(1);
        vm.stopPrank();
        
        // Rate seller
        vm.expectEmit(true, false, false, true);
        emit SellerRated(seller1, 1);
        
        vm.prank(buyer1);
        marketplace.rateSeller(seller1);
        
        // Check rating increased
        (, , , , , uint256 rating) = marketplace.sellers(seller1);
        assertEq(rating, 1);
    }
    
    function testRateSellerErrors() public {
        // No confirmed purchases
        vm.prank(buyer1);
        vm.expectRevert(ECommerce.SellerHasNoConfirmedPurchases.selector);
        marketplace.rateSeller(seller1);
        
        // Setup confirmed purchase and rate
        vm.prank(seller1);
        marketplace.createProduct("Test Product", "https://image.com", PRODUCT_PRICE, "Great product", 10);
        
        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), PRODUCT_PRICE);
        marketplace.purchaseProduct(1);
        marketplace.confirmPayment(1);
        marketplace.rateSeller(seller1);
        vm.stopPrank();
        
        // Rating exceeded confirmed purchases
        vm.prank(buyer2);
        vm.expectRevert(ECommerce.SellerRatingExceeded.selector);
        marketplace.rateSeller(seller1);
    }
    
    // ============= Seller Blocking Tests =============
    
    function testBlockSellerByOwner() public {
        vm.expectEmit(true, false, false, true);
        emit SellerBlocked(seller1, "Manual block by owner");
        
        marketplace.blockSellerByOwner(seller1, "Manual block by owner");
        
        assertTrue(marketplace.isSellerBlocked(seller1));
        
        ECommerce.BlockedSeller memory blocked = marketplace.getBlockedSellerDetails(seller1);
        assertEq(blocked.sellerAddress, seller1);
        assertEq(blocked.reason, "Manual block by owner");
    }
    
    function testBlockSellerByOwnerErrors() public {
        marketplace.blockSellerByOwner(seller1, "Test block");
        
        // Already blocked
        vm.expectRevert(ECommerce.ErrSellerBlocked.selector);
        marketplace.blockSellerByOwner(seller1, "Another reason");
    }
    
    function testUnblockSeller() public {
        // Block seller first
        marketplace.blockSellerByOwner(seller1, "Test block");
        
        vm.expectEmit(true, false, false, false);
        emit SellerUnblocked(seller1);
        
        marketplace.unblockSeller(seller1);
        
        assertFalse(marketplace.isSellerBlocked(seller1));
        
        // Should revert when trying to get blocked seller details
        vm.expectRevert(ECommerce.ErrSellerNotBlocked.selector);
        marketplace.getBlockedSellerDetails(seller1);
    }
    
    function testUnblockSellerErrors() public {
        // Seller not blocked
        vm.expectRevert(ECommerce.ErrSellerNotBlocked.selector);
        marketplace.unblockSeller(seller1);
    }
    
    // ============= View Function Tests =============
    
    function testGetSellerDetails() public {
        vm.prank(seller1);
        marketplace.createProduct("Test Product", "https://image.com", PRODUCT_PRICE, "Great product", 10);
        
        // Should revert if buyer hasn't paid
        vm.prank(buyer1);
        vm.expectRevert(ECommerce.NoPaymentForProduct.selector);
        marketplace.getSellerDetails(1);
        
        // Purchase product
        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), PRODUCT_PRICE);
        marketplace.purchaseProduct(1);
        vm.stopPrank();
        
        // Now buyer can get seller details
        vm.prank(buyer1);
        ECommerce.SellerContact memory contact = marketplace.getSellerDetails(1);
        assertEq(contact.location, "New York");
        assertEq(contact.phoneNumber, "+1234567890");
    }
    
    // ============= Fee Withdrawal Tests =============
    
    function testWithdrawFees() public {
        // Generate some fees by confirming a purchase
        vm.prank(seller1);
        marketplace.createProduct("Test Product", "https://image.com", PRODUCT_PRICE, "Great product", 10);
        
        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), PRODUCT_PRICE);
        marketplace.purchaseProduct(1);
        marketplace.confirmPayment(1);
        vm.stopPrank();
        
        uint256 expectedFees = PRODUCT_PRICE * 5 / 100; // 5% fee
        uint256 recipientBalanceBefore = usdc.balanceOf(feeRecipient);
        
        marketplace.withdrawFees(feeRecipient);
        
        assertEq(usdc.balanceOf(feeRecipient), recipientBalanceBefore + expectedFees);
        assertEq(marketplace.getTotalFeesCollected(), 0);
    }
    
    function testWithdrawFeesErrors() public {
        // Invalid address
        vm.expectRevert(ECommerce.InvalidWithdrawAddress.selector);
        marketplace.withdrawFees(address(0));
        
        // Only owner can withdraw
        vm.prank(seller1);
        vm.expectRevert();
        marketplace.withdrawFees(feeRecipient);
    }
    
    // ============= Integration Tests =============
    
    function testCompleteMarketplaceFlow() public {
        // 1. Seller creates product
        vm.prank(seller1);
        marketplace.createProduct("Amazing Product", "https://image.com", PRODUCT_PRICE, "The best product ever", 5);
        
        // 2. Buyer purchases product
        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), PRODUCT_PRICE);
        marketplace.purchaseProduct(1);
        vm.stopPrank();
        
        // 3. Buyer confirms payment
        vm.prank(buyer1);
        marketplace.confirmPayment(1);
        
        // 4. Buyer rates seller
        vm.prank(buyer1);
        marketplace.rateSeller(seller1);
        
        // 5. Another buyer purchases and cancels
        vm.startPrank(buyer2);
        usdc.approve(address(marketplace), PRODUCT_PRICE);
        marketplace.purchaseProduct(1);
        marketplace.cancelPurchase(1);
        marketplace.reportCanceledPurchase(1);
        vm.stopPrank();
        
        // 6. Owner withdraws fees
        uint256 expectedFees = (PRODUCT_PRICE * 5 / 100) + (PRODUCT_PRICE * 10 / 100 * 3 / 100); // Confirmation fee + cancellation fee
        marketplace.withdrawFees(feeRecipient);
        
        // Verify final state
        assertEq(usdc.balanceOf(feeRecipient), expectedFees);
        
        (, , uint256 confirmed, uint256 canceled, uint256 reported, uint256 rating) = marketplace.sellers(seller1);
        assertEq(confirmed, 1);
        assertEq(canceled, 1);
        assertEq(reported, 1);
        assertEq(rating, 1);
        
        ECommerce.Product memory product = marketplace.getProduct(1);
        assertEq(product.totalSold, 1);
        assertEq(product.inventory, 4); // Started with 5, sold 1, canceled 1 (so back to 4)
    }
    
    // ============= Constants Tests =============
    
    function testConstants() public {
        assertEq(marketplace.FEE_PERCENTAGE(), 5);
        assertEq(marketplace.PENALTY_PERCENTAGE(), 3);
        assertEq(marketplace.CANCELLATION_PENALTY_PERCENTAGE(), 10);
        assertEq(marketplace.SELLER_BLOCK_REPORTS_THRESHOLD(), 3);
        assertEq(marketplace.USDC_DECIMALS(), 6);
    }
}