// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Facilitator} from "../src/Facilitator.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/types/Currency.sol";

/**
 * @title SetPoolKey
 * @notice Script to set the pool key in the facilitator after pool initialization
 * @dev Run after InitializePool.s.sol
 */
contract SetPoolKeyScript is Script {
    using CurrencyLibrary for Currency;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address facilitatorAddress = vm.envAddress("FACILITATOR_ADDRESS");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address mockEURC = vm.envAddress("MOCK_EURC_ADDRESS_POLYGON");
        address mockUSDC = vm.envAddress("MOCK_USDC_ADDRESS_POLYGON");
        
        console.log("=== Setting Pool Key in Facilitator ===");
        console.log("Facilitator:", facilitatorAddress);
        console.log("Hook:", hookAddress);
        console.log("MockEURC:", mockEURC);
        console.log("MockUSDC:", mockUSDC);
        
        vm.startBroadcast(deployerPrivateKey);
        
        Facilitator facilitator = Facilitator(facilitatorAddress);
        
        // Determine currency order (lower address first)
        (Currency currency0, Currency currency1) = mockEURC < mockUSDC
            ? (Currency.wrap(mockEURC), Currency.wrap(mockUSDC))
            : (Currency.wrap(mockUSDC), Currency.wrap(mockEURC));
        
        console.log("\nCurrency0:", Currency.unwrap(currency0));
        console.log("Currency1:", Currency.unwrap(currency1));
        
        // Set pool key
        facilitator.setPoolKey(
            currency0,
            currency1,
            3000,  // 0.3% fee
            60,    // tick spacing
            hookAddress
        );
        
        console.log("\n[SUCCESS] Pool key set successfully!");
        
        vm.stopBroadcast();
    }
}
