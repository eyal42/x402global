// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title YieldPoolShare
 * @notice On-chain asset token representing yield-bearing pool shares
 * @dev This is the asset that the server sells via the x402 OTC API
 */
contract YieldPoolShare is ERC20, Ownable {
    
    // ============ Events ============
    
    /// @notice Emitted when shares are minted
    event SharesMinted(address indexed to, uint256 amount);
    
    /// @notice Emitted when shares are burned
    event SharesBurned(address indexed from, uint256 amount);
    
    // ============ Constructor ============
    
    /**
     * @notice Initialize YieldPoolShare token
     * @param initialOwner Initial owner who can mint/burn shares
     */
    constructor(address initialOwner) 
        ERC20("Yield Pool Share", "YPS") 
        Ownable(initialOwner)
    {}
    
    // ============ Public Functions ============
    
    /**
     * @notice Mint new shares
     * @param to Recipient address
     * @param amount Amount of shares to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "YPS: mint to zero address");
        require(amount > 0, "YPS: mint zero amount");
        _mint(to, amount);
        emit SharesMinted(to, amount);
    }
    
    /**
     * @notice Burn shares from an address
     * @param from Address to burn from
     * @param amount Amount of shares to burn
     */
    function burn(address from, uint256 amount) external onlyOwner {
        require(from != address(0), "YPS: burn from zero address");
        require(amount > 0, "YPS: burn zero amount");
        _burn(from, amount);
        emit SharesBurned(from, amount);
    }
    
    /**
     * @notice Returns 18 decimals (standard ERC20)
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}

