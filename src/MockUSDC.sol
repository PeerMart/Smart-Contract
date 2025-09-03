// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockUSDC
/// @notice A simple ERC20 token with 6 decimals to simulate USDC for testing
contract MockUSDC is ERC20 {
    uint8 private constant DECIMALS = 6;

    /// @notice Constructor that mints initial supply to the deployer
    /// @param initialSupply Amount of tokens to mint (in smallest units, e.g. 1000000 for 1 USDC)
    constructor(uint256 initialSupply) ERC20("Mock USDC", "mUSDC") {
        _mint(msg.sender, initialSupply);
    }

    /// @notice Returns the number of decimals the token uses (6 for USDC)
    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    /// @notice Mint new tokens (for test convenience)
    /// @param to The address to mint tokens to
    /// @param amount The amount to mint (in smallest units)
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}