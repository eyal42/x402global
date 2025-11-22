// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/MockUSDC.sol";

/**
 * @title MockTokenBaseTest
 * @notice Tests core ERC-20 functionality
 */
contract MockTokenBaseTest is Test {
    MockUSDC public token;
    
    address public admin = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public minter = address(4);
    address public masterMinter = address(5);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    function setUp() public {
        token = new MockUSDC(admin);
        
        // Setup minter roles
        vm.startPrank(admin);
        token.grantRole(token.MASTER_MINTER_ROLE(), masterMinter);
        token.grantRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();
        
        // Configure minter allowance
        vm.prank(masterMinter);
        token.configureMinter(minter, 1_000_000e6);
        
        // Mint initial tokens to user1
        vm.prank(minter);
        token.mint(user1, 100e6);
    }
    
    // ============ Basic Information Tests ============
    
    function test_Name() public view {
        assertEq(token.name(), "Mock USD Coin");
    }
    
    function test_Symbol() public view {
        assertEq(token.symbol(), "MockUSDC");
    }
    
    function test_Decimals() public view {
        assertEq(token.decimals(), 6);
    }
    
    function test_TotalSupply() public view {
        assertEq(token.totalSupply(), 100e6);
    }
    
    // ============ Balance Tests ============
    
    function test_BalanceOf() public view {
        assertEq(token.balanceOf(user1), 100e6);
        assertEq(token.balanceOf(user2), 0);
    }
    
    // ============ Transfer Tests ============
    
    function test_Transfer() public {
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, 50e6);
        bool success = token.transfer(user2, 50e6);
        
        assertTrue(success);
        assertEq(token.balanceOf(user1), 50e6);
        assertEq(token.balanceOf(user2), 50e6);
    }
    
    function test_Transfer_ZeroAmount() public {
        vm.prank(user1);
        bool success = token.transfer(user2, 0);
        
        assertTrue(success);
        assertEq(token.balanceOf(user1), 100e6);
        assertEq(token.balanceOf(user2), 0);
    }
    
    function test_Transfer_RevertInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert();
        token.transfer(user2, 200e6);
    }
    
    function test_Transfer_ToSelf() public {
        vm.prank(user1);
        bool success = token.transfer(user1, 50e6);
        
        assertTrue(success);
        assertEq(token.balanceOf(user1), 100e6);
    }
    
    // ============ Approval Tests ============
    
    function test_Approve() public {
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, 50e6);
        bool success = token.approve(user2, 50e6);
        
        assertTrue(success);
        assertEq(token.allowance(user1, user2), 50e6);
    }
    
    function test_Approve_ZeroAmount() public {
        // First approve
        vm.prank(user1);
        token.approve(user2, 50e6);
        
        // Then reset to zero
        vm.prank(user1);
        bool success = token.approve(user2, 0);
        
        assertTrue(success);
        assertEq(token.allowance(user1, user2), 0);
    }
    
    // ============ TransferFrom Tests ============
    
    function test_TransferFrom() public {
        vm.prank(user1);
        token.approve(user2, 50e6);
        
        vm.prank(user2);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, 30e6);
        bool success = token.transferFrom(user1, user2, 30e6);
        
        assertTrue(success);
        assertEq(token.balanceOf(user1), 70e6);
        assertEq(token.balanceOf(user2), 30e6);
        assertEq(token.allowance(user1, user2), 20e6);
    }
    
    function test_TransferFrom_RevertInsufficientAllowance() public {
        vm.prank(user1);
        token.approve(user2, 30e6);
        
        vm.prank(user2);
        vm.expectRevert();
        token.transferFrom(user1, user2, 50e6);
    }
    
    function test_TransferFrom_RevertInsufficientBalance() public {
        vm.prank(user1);
        token.approve(user2, 200e6);
        
        vm.prank(user2);
        vm.expectRevert();
        token.transferFrom(user1, user2, 200e6);
    }
}

