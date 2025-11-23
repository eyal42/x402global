// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title YieldPoolShare
 * @notice Represents yield-bearing pool shares that can be sold OTC
 * @dev Implements EIP-2612 for gasless approvals, uses 18 decimals for yield tokens
 */
contract YieldPoolShare is ERC20, ERC20Permit, Ownable {
    // ============ Events ============
    
    /// @notice Emitted when shares are minted
    event SharesMinted(address indexed to, uint256 amount);
    
    /// @notice Emitted when shares are burned
    event SharesBurned(address indexed from, uint256 amount);
    
    // ============ Constructor ============
    
    /**
     * @notice Deploy YieldPoolShare token
     * @param initialOwner Initial owner address
     */
    constructor(address initialOwner) 
        ERC20("Yield Pool Share", "YPS")
        ERC20Permit("Yield Pool Share")
        Ownable(initialOwner)
    {
        // Mint initial supply to owner for testing
        _mint(initialOwner, 1_000_000 * 10**18); // 1M tokens
    }
    
    // ============ Public Functions ============
    
    /**
     * @notice Mint new shares (owner only for demo purposes)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit SharesMinted(to, amount);
    }
    
    /**
     * @notice Burn shares from caller's balance
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit SharesBurned(msg.sender, amount);
    }
    
    /**
     * @notice Returns 18 decimals (standard for yield tokens)
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}

