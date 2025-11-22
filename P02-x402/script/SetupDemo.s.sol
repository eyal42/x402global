// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/YieldPoolShare.sol";
import "../src/SwapSimulator.sol";
import "../src/SettlementVault.sol";

/**
 * @title SetupDemo
 * @notice Setup script to prepare demo environment (mint tokens, set approvals, etc.)
 */
contract SetupDemo is Script {
    function run() external {
        // Use FACILITATOR key for setup
        uint256 facilitatorPrivateKey = vm.envUint("FACILITATOR_PRIVATE_KEY");
        address facilitator = vm.addr(facilitatorPrivateKey);
        
        // Get contract addresses from environment
        address ypsAddress = vm.envAddress("YPS_ADDRESS");
        address simulatorAddress = vm.envAddress("SWAP_SIMULATOR_ADDRESS");
        address vaultAddress = vm.envAddress("SETTLEMENT_VAULT_ADDRESS");
        address mockEURC = vm.envAddress("MOCK_EURC_ADDRESS_POLYGON");
        address mockUSDC = vm.envAddress("MOCK_USDC_ADDRESS_POLYGON");
        
        // Get client address (for demo purposes)
        address clientAddress = vm.envOr("CLIENT_ADDRESS", facilitator);
        
        console.log("=== Setting up Demo Environment ===");
        console.log("Facilitator:", facilitator);
        console.log("Client:", clientAddress);
        console.log("YieldPoolShare:", ypsAddress);
        console.log("SwapSimulator:", simulatorAddress);
        console.log("SettlementVault:", vaultAddress);
        console.log("");
        
        vm.startBroadcast(facilitatorPrivateKey);
        
        YieldPoolShare yps = YieldPoolShare(ypsAddress);
        SettlementVault vault = SettlementVault(vaultAddress);
        
        // 1. Ensure vault has YieldPoolShares to sell
        uint256 vaultBalance = yps.balanceOf(vaultAddress);
        console.log("1. Vault YPS balance:", vaultBalance / 1e18, "tokens");
        
        if (vaultBalance < 1000 * 1e18) {
            console.log("   Minting additional YPS to vault...");
            yps.mint(vaultAddress, 10000 * 1e18);
            console.log("   Minted 10,000 YPS tokens");
        }
        
        // 2. Update exchange rate if needed
        console.log("2. Demo setup complete");
        console.log("");
        console.log("Client can now:");
        console.log("- Mint MockEURC tokens to their address");
        console.log("- Start the Python server");
        console.log("- Make requests to /buy-asset endpoint");
        
        vm.stopBroadcast();
    }
}

