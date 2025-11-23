// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Facilitator} from "../src/Facilitator.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/types/Currency.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ExecuteSwap
 * @notice Script to execute swaps through the facilitator
 * @dev Run with: forge script script/ExecuteSwap.s.sol --rpc-url $POLYGON_AMOY_RPC_URL --broadcast
 */
contract ExecuteSwapScript is Script {
    using CurrencyLibrary for Currency;
    
    // Configuration
    address facilitatorAddress;
    address mockEURC;
    address mockUSDC;
    address hookAddress;
    
    // Swap parameters
    uint256 swapAmount = 100 * 10**6; // 100 tokens (6 decimals)
    uint256 minAmountOut = 95 * 10**6; // 5% slippage tolerance
    
    function setUp() public {
        facilitatorAddress = vm.envAddress("FACILITATOR_ADDRESS");
        mockEURC = vm.envAddress("MOCK_EURC_ADDRESS_POLYGON");
        mockUSDC = vm.envAddress("MOCK_USDC_ADDRESS_POLYGON");
        hookAddress = vm.envAddress("HOOK_ADDRESS");
        
        console.log("=== Swap Configuration ===");
        console.log("Facilitator:", facilitatorAddress);
        console.log("MockEURC:", mockEURC);
        console.log("MockUSDC:", mockUSDC);
        console.log("Hook:", hookAddress);
        console.log("Swap Amount:", swapAmount);
        console.log("Min Amount Out:", minAmountOut);
    }
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        Facilitator facilitator = Facilitator(facilitatorAddress);
        
        // Check if pool key is set
        PoolKey memory poolKey = facilitator.getPoolKey();
        console.log("\n=== Pool Key ===");
        // Currency0 is MockUSDC (0x68A292c6EbE4becC8a1aE129B6f3b143c9d4E89C)
        // Currency1 is MockEURC (0xa47fd735Ef95394c050f71e31E78Bee89e3EE513)
        console.log("Currency0 (MockUSDC):", Currency.unwrap(poolKey.currency0));
        console.log("Currency1 (MockEURC):", Currency.unwrap(poolKey.currency1));
        console.log("Fee:", poolKey.fee);
        console.log("Hooks:", address(poolKey.hooks));
        
        // Determine swap direction
        bool isEURCCurrency0 = Currency.unwrap(poolKey.currency0) == mockEURC;
        
        console.log("\n=== Executing EURC -> USDC Swap ===");
        console.log("Direction: EURC -> USDC");
        console.log("Zero for One:", isEURCCurrency0);
        
        // Check balance
        uint256 eurcBalance = IERC20(mockEURC).balanceOf(deployer);
        uint256 usdcBalanceBefore = IERC20(mockUSDC).balanceOf(deployer);
        
        console.log("\nBalances before swap:");
        console.log("  EURC:", eurcBalance);
        console.log("  USDC:", usdcBalanceBefore);
        
        require(eurcBalance >= swapAmount, "Insufficient EURC balance");
        
        // Approve facilitator to spend EURC
        console.log("\nApproving facilitator to spend EURC...");
        IERC20(mockEURC).approve(facilitatorAddress, swapAmount);
        
        // Execute swap
        console.log("\nExecuting swap...");
        uint256 amountOut = facilitator.simpleSwap(
            mockEURC,      // tokenIn
            mockUSDC,      // tokenOut
            swapAmount,    // amountIn
            minAmountOut,  // minAmountOut
            isEURCCurrency0, // zeroForOne
            deployer       // recipient
        );
        
        console.log("\n=== Swap Completed ===");
        console.log("Amount In (EURC):", swapAmount);
        console.log("Amount Out (USDC):", amountOut);
        
        // Check balances after
        uint256 eurcBalanceAfter = IERC20(mockEURC).balanceOf(deployer);
        uint256 usdcBalanceAfter = IERC20(mockUSDC).balanceOf(deployer);
        
        console.log("\nBalances after swap:");
        console.log("  EURC:", eurcBalanceAfter);
        console.log("  USDC:", usdcBalanceAfter);
        
        console.log("\nNet changes:");
        console.log("  EURC spent:", eurcBalance - eurcBalanceAfter);
        console.log("  USDC received:", usdcBalanceAfter - usdcBalanceBefore);
        
        // Calculate effective exchange rate
        uint256 rate = (amountOut * 10000) / swapAmount; // In basis points
        console.log("\nEffective rate: %d.%d%% (USDC per EURC)", rate / 100, rate % 100);
        
        vm.stopBroadcast();
        
        console.log("\n=== Testing Reverse Swap (USDC -> EURC) ===");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Now swap some USDC back to EURC
        uint256 reverseSwapAmount = amountOut / 2; // Swap half back
        uint256 reverseMinOut = (reverseSwapAmount * 95) / 100; // 5% slippage
        
        console.log("Swapping", reverseSwapAmount, "USDC back to EURC");
        
        // Approve
        IERC20(mockUSDC).approve(facilitatorAddress, reverseSwapAmount);
        
        // Execute reverse swap
        uint256 eurcReceived = facilitator.simpleSwap(
            mockUSDC,      // tokenIn
            mockEURC,      // tokenOut
            reverseSwapAmount, // amountIn
            reverseMinOut, // minAmountOut
            !isEURCCurrency0, // zeroForOne (opposite direction)
            deployer       // recipient
        );
        
        console.log("\n=== Reverse Swap Completed ===");
        console.log("Amount In (USDC):", reverseSwapAmount);
        console.log("Amount Out (EURC):", eurcReceived);
        
        // Final balances
        uint256 eurcFinal = IERC20(mockEURC).balanceOf(deployer);
        uint256 usdcFinal = IERC20(mockUSDC).balanceOf(deployer);
        
        console.log("\nFinal balances:");
        console.log("  EURC:", eurcFinal);
        console.log("  USDC:", usdcFinal);
        
        vm.stopBroadcast();
    }
}

