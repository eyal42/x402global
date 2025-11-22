// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/MockUSDC.sol";

/**
 * @title MockTokenMintingTest
 * @notice Tests role-based minting with allowances
 */
contract MockTokenMintingTest is Test {
    MockUSDC public token;
    
    address public admin = address(1);
    address public masterMinter = address(2);
    address public minter1 = address(3);
    address public minter2 = address(4);
    address public user1 = address(5);
    address public unauthorized = address(6);
    
    event MinterConfigured(address indexed minter, uint256 allowance);
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    function setUp() public {
        token = new MockUSDC(admin);
        
        // Grant roles
        vm.startPrank(admin);
        token.grantRole(token.MASTER_MINTER_ROLE(), masterMinter);
        token.grantRole(token.MINTER_ROLE(), minter1);
        token.grantRole(token.MINTER_ROLE(), minter2);
        vm.stopPrank();
    }
    
    // ============ Role Tests ============
    
    function test_Roles_DefaultAdmin() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
    }
    
    function test_Roles_MasterMinter() public view {
        assertTrue(token.hasRole(token.MASTER_MINTER_ROLE(), masterMinter));
    }
    
    function test_Roles_Minter() public view {
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter1));
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter2));
    }
    
    // ============ Configure Minter Tests ============
    
    function test_ConfigureMinter() public {
        uint256 allowance = 1_000_000e6;
        
        vm.prank(masterMinter);
        vm.expectEmit(true, false, false, true);
        emit MinterConfigured(minter1, allowance);
        token.configureMinter(minter1, allowance);
        
        assertEq(token.minterAllowance(minter1), allowance);
    }
    
    function test_ConfigureMinter_UpdateAllowance() public {
        // Set initial allowance
        vm.prank(masterMinter);
        token.configureMinter(minter1, 1_000_000e6);
        
        // Update allowance
        vm.prank(masterMinter);
        token.configureMinter(minter1, 2_000_000e6);
        
        assertEq(token.minterAllowance(minter1), 2_000_000e6);
    }
    
    function test_ConfigureMinter_SetToZero() public {
        vm.prank(masterMinter);
        token.configureMinter(minter1, 1_000_000e6);
        
        vm.prank(masterMinter);
        token.configureMinter(minter1, 0);
        
        assertEq(token.minterAllowance(minter1), 0);
    }
    
    function test_ConfigureMinter_RevertNotMasterMinter() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        token.configureMinter(minter1, 1_000_000e6);
    }
    
    function test_ConfigureMinter_RevertZeroAddress() public {
        vm.prank(masterMinter);
        vm.expectRevert();
        token.configureMinter(address(0), 1_000_000e6);
    }
    
    // ============ Mint Tests ============
    
    function test_Mint() public {
        uint256 mintAmount = 100e6;
        
        vm.prank(masterMinter);
        token.configureMinter(minter1, 1_000_000e6);
        
        vm.prank(minter1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, mintAmount);
        token.mint(user1, mintAmount);
        
        assertEq(token.balanceOf(user1), mintAmount);
        assertEq(token.totalSupply(), mintAmount);
        assertEq(token.minterAllowance(minter1), 1_000_000e6 - mintAmount);
    }
    
    function test_Mint_MultipleMints() public {
        vm.prank(masterMinter);
        token.configureMinter(minter1, 1_000_000e6);
        
        vm.startPrank(minter1);
        token.mint(user1, 100e6);
        token.mint(user1, 200e6);
        token.mint(user1, 300e6);
        vm.stopPrank();
        
        assertEq(token.balanceOf(user1), 600e6);
        assertEq(token.minterAllowance(minter1), 1_000_000e6 - 600e6);
    }
    
    function test_Mint_MultipleMinters() public {
        vm.startPrank(masterMinter);
        token.configureMinter(minter1, 1_000_000e6);
        token.configureMinter(minter2, 500_000e6);
        vm.stopPrank();
        
        vm.prank(minter1);
        token.mint(user1, 100e6);
        
        vm.prank(minter2);
        token.mint(user1, 50e6);
        
        assertEq(token.balanceOf(user1), 150e6);
        assertEq(token.minterAllowance(minter1), 1_000_000e6 - 100e6);
        assertEq(token.minterAllowance(minter2), 500_000e6 - 50e6);
    }
    
    function test_Mint_RevertNotMinter() public {
        vm.prank(masterMinter);
        token.configureMinter(minter1, 1_000_000e6);
        
        vm.prank(unauthorized);
        vm.expectRevert();
        token.mint(user1, 100e6);
    }
    
    function test_Mint_RevertInsufficientAllowance() public {
        vm.prank(masterMinter);
        token.configureMinter(minter1, 100e6);
        
        vm.prank(minter1);
        vm.expectRevert();
        token.mint(user1, 200e6);
    }
    
    function test_Mint_RevertZeroAmount() public {
        vm.prank(masterMinter);
        token.configureMinter(minter1, 1_000_000e6);
        
        vm.prank(minter1);
        vm.expectRevert();
        token.mint(user1, 0);
    }
    
    function test_Mint_RevertZeroAddress() public {
        vm.prank(masterMinter);
        token.configureMinter(minter1, 1_000_000e6);
        
        vm.prank(minter1);
        vm.expectRevert();
        token.mint(address(0), 100e6);
    }
    
    function test_Mint_RevertToBlacklisted() public {
        vm.prank(masterMinter);
        token.configureMinter(minter1, 1_000_000e6);
        
        vm.prank(admin);
        token.setBlacklisted(user1, true);
        
        vm.prank(minter1);
        vm.expectRevert();
        token.mint(user1, 100e6);
    }
    
    // ============ Burn Tests ============
    
    function test_Burn() public {
        vm.prank(masterMinter);
        token.configureMinter(minter1, 1_000_000e6);
        
        vm.prank(minter1);
        token.mint(user1, 100e6);
        
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, address(0), 50e6);
        token.burn(50e6);
        
        assertEq(token.balanceOf(user1), 50e6);
        assertEq(token.totalSupply(), 50e6);
    }
    
    function test_Burn_FullBalance() public {
        vm.prank(masterMinter);
        token.configureMinter(minter1, 1_000_000e6);
        
        vm.prank(minter1);
        token.mint(user1, 100e6);
        
        vm.prank(user1);
        token.burn(100e6);
        
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.totalSupply(), 0);
    }
    
    function test_Burn_RevertZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert();
        token.burn(0);
    }
    
    function test_Burn_RevertInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert();
        token.burn(100e6);
    }
}

