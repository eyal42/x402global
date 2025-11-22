// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/SwapSimulator.sol";

/**
 * @title DeploySwapSimulator
 * @notice Deployment script for SwapSimulator contract
 */
contract DeploySwapSimulator is Script {
    function run() external {
        // Use FACILITATOR key for deployment
        uint256 facilitatorPrivateKey = vm.envUint("FACILITATOR_PRIVATE_KEY");
        address facilitator = vm.addr(facilitatorPrivateKey);
        
        console.log("Deploying SwapSimulator...");
        console.log("Deployer (Facilitator):", facilitator);
        
        vm.startBroadcast(facilitatorPrivateKey);
        
        // Deploy SwapSimulator
        SwapSimulator simulator = new SwapSimulator(facilitator);
        
        console.log("SwapSimulator deployed at:", address(simulator));
        console.log("Owner:", simulator.owner());
        console.log("Fulfillment delay:", simulator.fulfillmentDelay());
        
        vm.stopBroadcast();
    }
}

