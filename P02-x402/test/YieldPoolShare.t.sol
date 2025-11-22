// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/YieldPoolShare.sol";

/**
 * @title YieldPoolShareTest
 * @notice Tests for YieldPoolShare token
 */
contract YieldPoolShareTest is Test {
    YieldPoolShare public yps;
    
    address public owner;
    address public user;
    
    function setUp() public {
        owner = address(this);
        user = address(0x1);
        
        yps = new YieldPoolShare(owner);
    }
    
    function testInitialState() public {
        assertEq(yps.name(), "Yield Pool Share");
        assertEq(yps.symbol(), "YPS");
        assertEq(yps.decimals(), 18);
        assertEq(yps.totalSupply(), 0);
    }
    
    function testMint() public {
        uint256 amount = 1000 * 1e18;
        
        yps.mint(user, amount);
        
        assertEq(yps.balanceOf(user), amount);
        assertEq(yps.totalSupply(), amount);
    }
    
    function testBurn() public {
        uint256 amount = 1000 * 1e18;
        yps.mint(user, amount);
        
        yps.burn(user, 500 * 1e18);
        
        assertEq(yps.balanceOf(user), 500 * 1e18);
        assertEq(yps.totalSupply(), 500 * 1e18);
    }
    
    function testCannotMintAsNonOwner() public {
        vm.prank(user);
        vm.expectRevert();
        yps.mint(user, 1000 * 1e18);
    }
    
    function testTransfer() public {
        uint256 amount = 1000 * 1e18;
        yps.mint(user, amount);
        
        vm.prank(user);
        yps.transfer(owner, 500 * 1e18);
        
        assertEq(yps.balanceOf(user), 500 * 1e18);
        assertEq(yps.balanceOf(owner), 500 * 1e18);
    }
}

