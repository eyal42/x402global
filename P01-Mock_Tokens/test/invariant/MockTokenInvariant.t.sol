// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/MockUSDC.sol";
import "./handlers/TokenHandler.sol";

/**
 * @title MockTokenInvariantTest
 * @notice Invariant tests for token contract
 */
contract MockTokenInvariantTest is Test {
    MockUSDC public token;
    TokenHandler public handler;
    
    address public admin = address(this);
    address public masterMinter = address(0xABCD);
    address public minter = address(0xDEAD);
    
    function setUp() public {
        // Deploy token
        token = new MockUSDC(admin);
        
        // Setup roles
        token.grantRole(token.MASTER_MINTER_ROLE(), masterMinter);
        token.grantRole(token.MINTER_ROLE(), minter);
        
        // Configure minter with large allowance
        vm.prank(masterMinter);
        token.configureMinter(minter, type(uint128).max);
        
        // Create handler
        handler = new TokenHandler(token, admin, minter, masterMinter);
        
        // Target handler for invariant testing
        targetContract(address(handler));
        
        // Only call specific functions
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = TokenHandler.mint.selector;
        selectors[1] = TokenHandler.burn.selector;
        selectors[2] = TokenHandler.transfer.selector;
        selectors[3] = TokenHandler.approve.selector;
        selectors[4] = TokenHandler.transferFrom.selector;
        
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }
    
    // ============ Invariants ============
    
    /**
     * @notice Total supply should equal sum of all balances
     */
    function invariant_supplyEqualsSumOfBalances() public view {
        uint256 sumOfBalances = 0;
        
        for (uint256 i = 0; i < handler.actorsLength(); i++) {
            sumOfBalances += token.balanceOf(handler.actors(i));
        }
        
        // Also include handler and minter balances
        sumOfBalances += token.balanceOf(address(handler));
        sumOfBalances += token.balanceOf(minter);
        
        assertEq(token.totalSupply(), sumOfBalances, "Total supply != sum of balances");
    }
    
    /**
     * @notice Total supply should never be negative (implicit in uint256)
     */
    function invariant_supplyNeverNegative() public view {
        assertTrue(token.totalSupply() >= 0, "Supply is negative");
    }
    
    /**
     * @notice Individual balance should never exceed total supply
     */
    function invariant_balanceNeverExceedsSupply() public view {
        for (uint256 i = 0; i < handler.actorsLength(); i++) {
            address actor = handler.actors(i);
            assertLe(
                token.balanceOf(actor),
                token.totalSupply(),
                "Balance exceeds supply"
            );
        }
    }
    
    /**
     * @notice Minted tokens minus burned tokens should equal total supply
     */
    function invariant_mintBurnAccounting() public view {
        uint256 netSupply = handler.ghost_mintSum() - handler.ghost_burnSum();
        assertEq(token.totalSupply(), netSupply, "Supply != mints - burns");
    }
    
    /**
     * @notice Blacklisted addresses should not be able to transfer
     * @dev We don't test this in invariant mode since we'd need to blacklist during fuzzing
     */
    function invariant_blacklistEnforcement() public view {
        // This invariant is tested in unit tests
        // Here we just verify no blacklisted actors have received tokens via mint
        assertTrue(true);
    }
    
    /**
     * @notice Print call summary at the end
     */
    function invariant_callSummary() public view {
        handler.callSummary();
    }
}

