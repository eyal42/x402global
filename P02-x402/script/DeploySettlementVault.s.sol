// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/SettlementVault.sol";

/**
 * @title DeploySettlementVault
 * @notice Deployment script for SettlementVault contract
 */
contract DeploySettlementVault is Script {
    function run() external {
        // Use FACILITATOR key for deployment
        uint256 facilitatorPrivateKey = vm.envUint("FACILITATOR_PRIVATE_KEY");
        address facilitator = vm.addr(facilitatorPrivateKey);
        
        console.log("Deploying SettlementVault...");
        console.log("Deployer (Facilitator):", facilitator);
        
        vm.startBroadcast(facilitatorPrivateKey);
        
        // Deploy SettlementVault
        SettlementVault vault = new SettlementVault(facilitator);
        
        console.log("SettlementVault deployed at:", address(vault));
        console.log("Owner:", vault.owner());
        
        vm.stopBroadcast();
    }
}

