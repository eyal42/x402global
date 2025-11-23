// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {FacilitatorHook} from "../src/FacilitatorHook.sol";
import {PoolSettlementVault} from "../src/PoolSettlementVault.sol";
import {Facilitator} from "../src/Facilitator.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";

/**
 * @title Deploy
 * @notice Deployment script for hook, vault, and facilitator contracts
 * @dev Run with: forge script script/Deploy.s.sol --rpc-url $POLYGON_AMOY_RPC_URL --broadcast
 */
contract DeployScript is Script {
    // Configuration from environment
    address poolManager;
    address swapRouter;
    address deployer;

    function setUp() public {
        // Load configuration from environment
        poolManager = vm.envAddress("POOL_MANAGER_ADDRESS");
        swapRouter = vm.envAddress("SWAP_ROUTER_ADDRESS");
        deployer = vm.envAddress("DEPLOYER_ADDRESS");

        console.log("=== Deployment Configuration ===");
        console.log("Pool Manager:", poolManager);
        console.log("Swap Router:", swapRouter);
        console.log("Deployer:", deployer);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        console.log("\n=== Deploying Contracts ===");

        // 1. Deploy FacilitatorHook
        console.log("\n1. Deploying FacilitatorHook...");
        FacilitatorHook hook = new FacilitatorHook(
            IPoolManager(poolManager),
            deployer
        );
        console.log("  FacilitatorHook deployed at:", address(hook));

        // 2. Deploy PoolSettlementVault
        console.log("\n2. Deploying PoolSettlementVault...");
        PoolSettlementVault vault = new PoolSettlementVault(deployer);
        console.log("  PoolSettlementVault deployed at:", address(vault));

        // 3. Deploy Facilitator
        console.log("\n3. Deploying Facilitator...");
        Facilitator facilitator = new Facilitator(
            poolManager,
            swapRouter,
            deployer
        );
        console.log("  Facilitator deployed at:", address(facilitator));

        // 4. Configure relationships
        console.log("\n=== Configuring Contracts ===");

        console.log("4. Setting vault address in hook...");
        hook.setVault(address(vault));

        console.log("5. Authorizing facilitator in hook...");
        hook.setFacilitator(address(facilitator), true);

        console.log("6. Setting pool manager in vault...");
        vault.setPoolManager(poolManager);

        console.log("7. Setting facilitator in vault...");
        vault.setFacilitator(address(facilitator));

        console.log("8. Setting vault in facilitator...");
        facilitator.setVault(address(vault));

        vm.stopBroadcast();

        // Print summary
        console.log("\n=== Deployment Summary ===");
        console.log("FacilitatorHook:", address(hook));
        console.log("PoolSettlementVault:", address(vault));
        console.log("Facilitator:", address(facilitator));
        console.log("\nAdd these to your .env file:");
        console.log("HOOK_ADDRESS=%s", address(hook));
        console.log("VAULT_ADDRESS=%s", address(vault));
        console.log("FACILITATOR_ADDRESS=%s", address(facilitator));
    }
}
