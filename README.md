 # ECommerce Smart Contract Project

A robust, upgradeable ECommerce marketplace smart contract system for the Ethereum blockchain. This project allows sellers to register and list products, buyers to purchase using USDC, and features secure payment, automated fee and penalty handling, reporting, and seller management.

## Features

- **Seller Registration:** Sellers can register with profile and contact information.
- **Product Listings:** Sellers can create, update, and manage product listings with inventory.
- **USDC Payments:** Buyers purchase products using the USDC ERC20 token.
- **Marketplace Fees:** Platform fee, seller penalty, and cancellation penalty are all configurable.
- **Order Lifecycle:** Buyers can confirm payments, cancel purchases (with penalties), and rate sellers.
- **Seller Reputation:** Buyers can report sellers for canceled purchases. Sellers can be automatically or manually blocked/unblocked.
- **Admin Controls:** Owner can block/unblock sellers and withdraw accumulated platform fees.
- **Upgradeable and Secure:** Designed with security in mind, using OpenZeppelin's libraries.

## Contracts

- `ECommerce.sol` — Main marketplace contract.
- `MockUSDC.sol` — Mock USDC ERC20 token for development and testing.

## Getting Started

### Installation

```bash
git clone https://github.com/PeerMart/Smart-Contract-.git
cd Smart-Contract
forge install
```

### Compile Contracts

```bash
forge build
```

### Run Tests

```bash
forge test
```


## Contract Overview

### ECommerce.sol

- **registerSeller(...)**: Sellers register with details.
- **createProduct(...)**: List new products.
- **purchaseProduct(...)**: Buyers purchase with USDC.
- **confirmPayment(...)**: Buyer confirms and seller receives funds.
- **cancelPurchase(...)**: Buyer cancels (refund minus penalty).
- **reportCanceledPurchase(...)**: Report canceled purchase.
- **rateSeller(...)**: Rate sellers after confirmed purchase.
- **blockSellerByOwner(...) / unblockSeller(...)**: Admin controls.
- **withdrawFees(...)**: Owner withdraws platform fees.

### MockUSDC.sol

A simple ERC20 token mimicking USDC for testing.

## Security

- Uses [OpenZeppelin](https://openzeppelin.com/) contracts for access control and token standards.
- Protects against reentrancy(CEI), double-spending, and unauthorized access.
- All critical actions and state changes are covered by unit tests.

 

[0x7fddE93c75669792002c8dBd49D0F6e869D15C96](https://hashscan.io/testnet/contract/0x7fddE93c75669792002c8dBd49D0F6e869D15C96/)

https://hashscan.io/testnet/contract/0xAdB02aaC89051778f505f7FC6A905E21283a62d3