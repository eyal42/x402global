// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";

/**
 * @title Verify
 * @notice Verification script to check if contracts are deployed
 */
contract Verify is Script {
    function run() public view {
        console.log("Checking deployed contracts on Polygon Amoy...\n");
        
        // Load addresses
        address yieldPoolShare = vm.envAddress("YIELD_POOL_SHARE_ADDRESS");
        address vault = vm.envAddress("SETTLEMENT_VAULT_ADDRESS");
        address permitPuller = vm.envAddress("PERMIT_PULLER_ADDRESS");
        address facilitatorHook = vm.envAddress("FACILITATOR_HOOK_ADDRESS");
        
        // Check each contract
        console.log("YieldPoolShare:", yieldPoolShare);
        console.log("  Code size:", _getCodeSize(yieldPoolShare));
        
        console.log("\nSettlementVault:", vault);
        console.log("  Code size:", _getCodeSize(vault));
        
        console.log("\nPermitPuller:", permitPuller);
        console.log("  Code size:", _getCodeSize(permitPuller));
        
        console.log("\nFacilitatorHook:", facilitatorHook);
        console.log("  Code size:", _getCodeSize(facilitatorHook));
        
        // Summary
        console.log("\n========================================");
        bool allDeployed = 
            _getCodeSize(yieldPoolShare) > 0 &&
            _getCodeSize(vault) > 0 &&
            _getCodeSize(permitPuller) > 0 &&
            _getCodeSize(facilitatorHook) > 0;
        
        if (allDeployed) {
            console.log("SUCCESS: All contracts are deployed!");
        } else {
            console.log("WARNING: Some contracts are not deployed!");
            console.log("You may need to run deployment again with --broadcast");
        }
        console.log("========================================");
    }
    
    function _getCodeSize(address target) internal view returns (uint256 size) {
        assembly {
            size := extcodesize(target)
        }
    }
}

