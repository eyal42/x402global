// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/YieldPoolShare.sol";
import "../src/SwapSimulator.sol";
import "../src/SettlementVault.sol";

/**
 * @title DeployAll
 * @notice Deployment script for all contracts in the x402 OTC API system
 */
contract DeployAll is Script {
    function run() external {
        // Use FACILITATOR key for deployment (they will own and operate the contracts)
        uint256 facilitatorPrivateKey = vm.envUint("FACILITATOR_PRIVATE_KEY");
        address facilitator = vm.addr(facilitatorPrivateKey);

        // Get MockEURC and MockUSDC addresses from environment
        address mockEURC = vm.envAddress("MOCK_EURC_ADDRESS_POLYGON");
        address mockUSDC = vm.envAddress("MOCK_USDC_ADDRESS_POLYGON");

        console.log("=== Deploying x402 OTC API System ===");
        console.log("Deployer (Facilitator):", facilitator);
        console.log("Network: Polygon Amoy");
        console.log("MockEURC:", mockEURC);
        console.log("MockUSDC:", mockUSDC);
        console.log("");

        vm.startBroadcast(facilitatorPrivateKey);

        // 1. Deploy YieldPoolShare (the asset being sold)
        console.log("1. Deploying YieldPoolShare...");
        YieldPoolShare yps = new YieldPoolShare(facilitator);
        console.log("   YieldPoolShare deployed at:", address(yps));
        console.log("   Owner (Facilitator):", facilitator);

        // 2. Deploy SwapSimulator
        console.log("2. Deploying SwapSimulator...");
        SwapSimulator simulator = new SwapSimulator(facilitator);
        console.log("   SwapSimulator deployed at:", address(simulator));
        console.log("   Owner (Facilitator):", facilitator);

        // 3. Deploy SettlementVault
        console.log("3. Deploying SettlementVault...");
        SettlementVault vault = new SettlementVault(facilitator);
        console.log("   SettlementVault deployed at:", address(vault));
        console.log("   Owner (Facilitator):", facilitator);

        // 4. Configure SwapSimulator with exchange rate
        console.log("4. Configuring SwapSimulator...");
        // Set EUR/USD rate: 1 EUR = 1.05 USD (rate = 1.05e18, decimals = 18)
        simulator.setExchangeRate(mockEURC, mockUSDC, 1.05e18, 18);
        console.log("   Exchange rate set: 1 EURC = 1.05 USDC");

        // 5. Configure SettlementVault with SwapSimulator
        console.log("5. Configuring SettlementVault...");
        vault.setSwapSimulator(address(simulator));
        console.log("   SwapSimulator linked to SettlementVault");

        // 6. Mint initial YieldPoolShare tokens to vault for selling
        console.log("6. Minting initial YieldPoolShares to vault...");
        uint256 initialSupply = 1000000 * 1e18; // 1M shares
        yps.mint(address(vault), initialSupply);
        console.log("   Minted", initialSupply / 1e18, "YPS tokens to vault");

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("YieldPoolShare:", address(yps));
        console.log("SwapSimulator:", address(simulator));
        console.log("SettlementVault:", address(vault));
        console.log("MockEURC:", mockEURC);
        console.log("MockUSDC:", mockUSDC);
        console.log("");
        console.log("Save these addresses for the Python scripts!");
    }
}
