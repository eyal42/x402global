// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/types/Currency.sol";
import {PoolModifyLiquidityTest} from "@uniswap/v4-core/test/PoolModifyLiquidityTest.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TickMath} from "@uniswap/v4-core/libraries/TickMath.sol";

/**
 * @title AddLiquidity
 * @notice Script to add liquidity to the MockEURC/MockUSDC pool
 * @dev Run with: forge script script/AddLiquidity.s.sol --rpc-url $POLYGON_AMOY_RPC_URL --broadcast
 */
contract AddLiquidityScript is Script {
    using CurrencyLibrary for Currency;
    
    // Configuration
    address poolManager;
    address hookAddress;
    address liquidityRouter;
    address mockEURC;
    address mockUSDC;
    
    // Pool parameters
    uint24 fee = 3000;
    int24 tickSpacing = 60;
    
    // Liquidity parameters
    int24 tickLower;
    int24 tickUpper;
    uint256 liquidityAmount;
    
    function setUp() public {
        poolManager = vm.envAddress("POOL_MANAGER_ADDRESS");
        hookAddress = vm.envAddress("HOOK_ADDRESS");
        liquidityRouter = vm.envAddress("LIQUIDITY_ROUTER_ADDRESS");
        mockEURC = vm.envAddress("MOCK_EURC_ADDRESS_POLYGON");
        mockUSDC = vm.envAddress("MOCK_USDC_ADDRESS_POLYGON");
        
        // Set up liquidity range (full range for simplicity)
        // Full range: -887220 to 887220 (max ticks)
        tickLower = -887220;
        tickUpper = 887220;
        
        // Adjust ticks to nearest tick spacing multiple
        tickLower = (tickLower / tickSpacing) * tickSpacing;
        tickUpper = (tickUpper / tickSpacing) * tickSpacing;
        
        // Liquidity amount (10000 EURC and 10000 USDC worth)
        // Since both tokens have 6 decimals: 10000 * 10^6
        liquidityAmount = 10000 * 10**6;
        
        console.log("=== Add Liquidity Configuration ===");
        console.log("Pool Manager:", poolManager);
        console.log("Hook:", hookAddress);
        console.log("Liquidity Router:", liquidityRouter);
        console.log("MockEURC:", mockEURC);
        console.log("MockUSDC:", mockUSDC);
        console.log("Tick Lower:", uint256(uint24(tickLower)));
        console.log("Tick Upper:", uint256(uint24(tickUpper)));
        console.log("Liquidity Amount (per token):", liquidityAmount);
    }
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("\n=== Adding Liquidity ===");
        console.log("Liquidity Provider:", deployer);
        
        // Determine currency order
        (Currency currency0, Currency currency1) = mockEURC < mockUSDC
            ? (Currency.wrap(mockEURC), Currency.wrap(mockUSDC))
            : (Currency.wrap(mockUSDC), Currency.wrap(mockEURC));
        
        // Currency0 is MockUSDC (0x68A292c6EbE4becC8a1aE129B6f3b143c9d4E89C)
        // Currency1 is MockEURC (0xa47fd735Ef95394c050f71e31E78Bee89e3EE513)
        console.log("Currency0 (MockUSDC):", Currency.unwrap(currency0));
        console.log("Currency1 (MockEURC):", Currency.unwrap(currency1));
        
        // Create pool key
        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hookAddress)
        });
        
        // Check balances
        uint256 balance0 = IERC20(Currency.unwrap(currency0)).balanceOf(deployer);
        uint256 balance1 = IERC20(Currency.unwrap(currency1)).balanceOf(deployer);
        
        console.log("\nCurrent balances:");
        console.log("  Currency0 (MockUSDC):", balance0);
        console.log("  Currency1 (MockEURC):", balance1);
        
        require(balance0 >= liquidityAmount, "Insufficient Currency0 (MockUSDC) balance");
        require(balance1 >= liquidityAmount, "Insufficient Currency1 (MockEURC) balance");
        
        // Approve tokens
        console.log("\nApproving tokens...");
        IERC20(Currency.unwrap(currency0)).approve(liquidityRouter, liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(liquidityRouter, liquidityAmount);
        
        // Prepare liquidity parameters
        // liquidityDelta is int256, positive means adding liquidity
        int256 liquidityDelta = int256(liquidityAmount);
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: liquidityDelta,
            salt: bytes32(0)
        });
        
        console.log("\nAdding liquidity...");
        console.log("  Tick Range: [%d, %d]", uint256(uint24(tickLower)), uint256(uint24(tickUpper)));
        console.log("  Liquidity Delta:", liquidityAmount);
        
        // Add liquidity via PoolModifyLiquidityTest
        PoolModifyLiquidityTest router = PoolModifyLiquidityTest(liquidityRouter);
        router.modifyLiquidity(key, params, "");
        
        console.log("\n=== Liquidity Added Successfully ===");
        
        // Check new balances
        uint256 newBalance0 = IERC20(Currency.unwrap(currency0)).balanceOf(deployer);
        uint256 newBalance1 = IERC20(Currency.unwrap(currency1)).balanceOf(deployer);
        
        console.log("\nNew balances:");
        console.log("  Currency0 (MockUSDC):", newBalance0);
        console.log("  Currency1 (MockEURC):", newBalance1);
        console.log("\nTokens deposited:");
        console.log("  Currency0 (MockUSDC):", balance0 - newBalance0);
        console.log("  Currency1 (MockEURC):", balance1 - newBalance1);
        
        vm.stopBroadcast();
    }
}

