// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/MockUSDC.sol";
import "../src/MockEURC.sol";

/**
 * @title Deploy
 * @notice Deployment script for MockUSDC and MockEURC tokens
 * @dev Usage: forge script script/Deploy.s.sol:Deploy --rpc-url <rpc-url> --broadcast
 */
contract Deploy is Script {
    function run() external {
        address admin = vm.envAddress("DEPLOYER_WALLET");
        
        vm.startBroadcast();
        
        // Deploy MockUSDC
        MockUSDC usdc = new MockUSDC(admin);
        console.log("MockUSDC deployed at:", address(usdc));
        
        // Deploy MockEURC
        MockEURC eurc = new MockEURC(admin);
        console.log("MockEURC deployed at:", address(eurc));
        
        vm.stopBroadcast();
        
        // Print deployment info
        console.log("\n=== Deployment Summary ===");
        console.log("Admin:", admin);
        console.log("MockUSDC:", address(usdc));
        console.log("MockEURC:", address(eurc));
        console.log("==========================\n");
    }
}
