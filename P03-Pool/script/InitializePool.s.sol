// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/types/Currency.sol";
import {TickMath} from "@uniswap/v4-core/libraries/TickMath.sol";

/**
 * @title InitializePool
 * @notice Script to initialize a Uniswap v4 pool for MockEURC/MockUSDC
 * @dev Run with: forge script script/InitializePool.s.sol --rpc-url $POLYGON_AMOY_RPC_URL --broadcast
 */
contract InitializePoolScript is Script {
    using CurrencyLibrary for Currency;
    
    // Configuration
    address poolManager;
    address hookAddress;
    address mockEURC;
    address mockUSDC;
    
    // Pool parameters
    uint24 fee = 3000; // 0.3%
    int24 tickSpacing = 60;
    
    function setUp() public {
        poolManager = vm.envAddress("POOL_MANAGER_ADDRESS");
        hookAddress = vm.envAddress("HOOK_ADDRESS");
        mockEURC = vm.envAddress("MOCK_EURC_ADDRESS_POLYGON");
        mockUSDC = vm.envAddress("MOCK_USDC_ADDRESS_POLYGON");
        
        console.log("=== Pool Initialization Configuration ===");
        console.log("Pool Manager:", poolManager);
        console.log("Hook:", hookAddress);
        console.log("MockEURC:", mockEURC);
        console.log("MockUSDC:", mockUSDC);
        console.log("Fee:", fee);
        console.log("Tick Spacing:", uint256(uint24(tickSpacing)));
    }
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("\n=== Initializing Pool ===");
        
        // Determine currency order (lower address first)
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
        
        // Calculate initial price: 1:1 (assuming both tokens have 6 decimals)
        // sqrtPriceX96 = sqrt(price) * 2^96
        // For 1:1 price: sqrt(1) * 2^96 = 2^96 = 79228162514264337593543950336
        uint160 sqrtPriceX96 = 79228162514264337593543950336;
        
        console.log("\nInitializing pool with sqrtPriceX96:", sqrtPriceX96);
        console.log("(This represents a 1:1 price ratio)");
        
        // Initialize the pool
        IPoolManager(poolManager).initialize(key, sqrtPriceX96);
        
        console.log("\n=== Pool Initialized Successfully ===");
        console.log("Pool Key:");
        console.log("  Currency0 (MockUSDC):", Currency.unwrap(key.currency0));
        console.log("  Currency1 (MockEURC):", Currency.unwrap(key.currency1));
        console.log("  Fee:", key.fee);
        console.log("  Tick Spacing:", uint256(uint24(key.tickSpacing)));
        console.log("  Hooks:", address(key.hooks));
        console.log("  Initial Price: 1:1 (EURC:USDC)");
        
        vm.stopBroadcast();
    }
}

