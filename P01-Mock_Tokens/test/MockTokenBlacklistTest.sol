// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/MockUSDC.sol";

/**
 * @title MockTokenBlacklistTest
 * @notice Tests blacklist compliance controls
 */
contract MockTokenBlacklistTest is Test {
    MockUSDC public token;
    
    address public admin = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public user3 = address(4);
    address public minter = address(5);
    address public masterMinter = address(6);
    
    event BlacklistedSet(address indexed account, bool isBlacklisted);
    event BlacklistedWiped(address indexed account, uint256 amount);
    
    function setUp() public {
        token = new MockUSDC(admin);
        
        // Setup roles
        vm.startPrank(admin);
        token.grantRole(token.MASTER_MINTER_ROLE(), masterMinter);
        token.grantRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();
        
        // Configure minter
        vm.prank(masterMinter);
        token.configureMinter(minter, 1_000_000e6);
        
        // Mint tokens to users
        vm.startPrank(minter);
        token.mint(user1, 100e6);
        token.mint(user2, 50e6);
        vm.stopPrank();
    }
    
    // ============ Blacklist Set/Unset Tests ============
    
    function test_SetBlacklisted() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit BlacklistedSet(user1, true);
        token.setBlacklisted(user1, true);
        
        assertTrue(token.isBlacklisted(user1));
    }
    
    function test_SetBlacklisted_Unblacklist() public {
        // First blacklist
        vm.prank(admin);
        token.setBlacklisted(user1, true);
        
        // Then unblacklist
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit BlacklistedSet(user1, false);
        token.setBlacklisted(user1, false);
        
        assertFalse(token.isBlacklisted(user1));
    }
    
    function test_SetBlacklisted_RevertNotAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        token.setBlacklisted(user2, true);
    }
    
    function test_SetBlacklisted_RevertZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert();
        token.setBlacklisted(address(0), true);
    }
    
    // ============ Transfer Blocking Tests ============
    
    function test_Transfer_RevertFromBlacklisted() public {
        vm.prank(admin);
        token.setBlacklisted(user1, true);
        
        vm.prank(user1);
        vm.expectRevert();
        token.transfer(user2, 10e6);
    }
    
    function test_Transfer_RevertToBlacklisted() public {
        vm.prank(admin);
        token.setBlacklisted(user2, true);
        
        vm.prank(user1);
        vm.expectRevert();
        token.transfer(user2, 10e6);
    }
    
    function test_Transfer_SuccessAfterUnblacklist() public {
        // Blacklist
        vm.prank(admin);
        token.setBlacklisted(user1, true);
        
        // Unblacklist
        vm.prank(admin);
        token.setBlacklisted(user1, false);
        
        // Transfer should work
        vm.prank(user1);
        token.transfer(user2, 10e6);
        
        assertEq(token.balanceOf(user1), 90e6);
        assertEq(token.balanceOf(user2), 60e6);
    }
    
    function test_TransferFrom_RevertFromBlacklisted() public {
        vm.prank(user1);
        token.approve(user3, 50e6);
        
        vm.prank(admin);
        token.setBlacklisted(user1, true);
        
        vm.prank(user3);
        vm.expectRevert();
        token.transferFrom(user1, user2, 10e6);
    }
    
    function test_TransferFrom_RevertToBlacklisted() public {
        vm.prank(user1);
        token.approve(user3, 50e6);
        
        vm.prank(admin);
        token.setBlacklisted(user2, true);
        
        vm.prank(user3);
        vm.expectRevert();
        token.transferFrom(user1, user2, 10e6);
    }
    
    // ============ Mint Blocking Tests ============
    
    function test_Mint_RevertToBlacklisted() public {
        vm.prank(admin);
        token.setBlacklisted(user3, true);
        
        vm.prank(minter);
        vm.expectRevert();
        token.mint(user3, 10e6);
    }
    
    // ============ Wipe Blacklisted Tests ============
    
    function test_WipeBlacklisted() public {
        uint256 balanceBefore = token.balanceOf(user1);
        
        vm.prank(admin);
        token.setBlacklisted(user1, true);
        
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit BlacklistedWiped(user1, balanceBefore);
        token.wipeBlacklisted(user1);
        
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.totalSupply(), 50e6); // Only user2's balance remains
    }
    
    function test_WipeBlacklisted_ZeroBalance() public {
        vm.prank(admin);
        token.setBlacklisted(user3, true);
        
        vm.prank(admin);
        token.wipeBlacklisted(user3);
        
        assertEq(token.balanceOf(user3), 0);
    }
    
    function test_WipeBlacklisted_RevertNotBlacklisted() public {
        vm.prank(admin);
        vm.expectRevert();
        token.wipeBlacklisted(user1);
    }
    
    function test_WipeBlacklisted_RevertNotAdmin() public {
        vm.prank(admin);
        token.setBlacklisted(user1, true);
        
        vm.prank(user2);
        vm.expectRevert();
        token.wipeBlacklisted(user1);
    }
    
    // ============ Edge Cases ============
    
    function test_Blacklist_MultipleUsers() public {
        vm.startPrank(admin);
        token.setBlacklisted(user1, true);
        token.setBlacklisted(user2, true);
        vm.stopPrank();
        
        assertTrue(token.isBlacklisted(user1));
        assertTrue(token.isBlacklisted(user2));
        assertFalse(token.isBlacklisted(user3));
    }
}

