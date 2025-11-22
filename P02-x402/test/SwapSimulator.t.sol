// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/SwapSimulator.sol";

/**
 * @title SwapSimulatorTest
 * @notice Tests for SwapSimulator contract
 */
contract SwapSimulatorTest is Test {
    SwapSimulator public simulator;
    
    address public owner;
    address public tokenIn;
    address public tokenOut;
    
    function setUp() public {
        owner = address(this);
        tokenIn = address(0x1);
        tokenOut = address(0x2);
        
        simulator = new SwapSimulator(owner);
        
        // Set exchange rate: 1 tokenIn = 1.05 tokenOut
        simulator.setExchangeRate(tokenIn, tokenOut, 1.05e18, 18);
    }
    
    function testSetExchangeRate() public {
        (uint256 rate, uint256 decimals, uint256 lastUpdate) = simulator.getExchangeRate(tokenIn, tokenOut);
        
        assertEq(rate, 1.05e18);
        assertEq(decimals, 18);
        assertTrue(lastUpdate > 0);
    }
    
    function testCalculateOutput() public {
        uint256 amountIn = 100e6; // 100 tokens with 6 decimals
        uint256 amountOut = simulator.calculateOutput(tokenIn, tokenOut, amountIn);
        
        // Expected: 100 * 1.05 = 105
        assertEq(amountOut, 105e6);
    }
    
    function testInstantSwap() public {
        bytes32 swapId = keccak256("swap1");
        uint256 amountIn = 100e6;
        
        uint256 amountOut = simulator.instantSwap(swapId, tokenIn, tokenOut, amountIn);
        
        assertEq(amountOut, 105e6);
        
        SwapSimulator.Swap memory swap = simulator.getSwap(swapId);
        assertTrue(swap.fulfilled);
        assertEq(swap.amountIn, amountIn);
        assertEq(swap.amountOut, amountOut);
    }
    
    function testCannotSwapWithoutRate() public {
        address unknownTokenIn = address(0x3);
        address unknownTokenOut = address(0x4);
        
        vm.expectRevert("Exchange rate not set");
        simulator.calculateOutput(unknownTokenIn, unknownTokenOut, 100e6);
    }
}

