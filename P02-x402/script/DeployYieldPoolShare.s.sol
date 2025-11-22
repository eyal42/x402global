// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/YieldPoolShare.sol";

/**
 * @title DeployYieldPoolShare
 * @notice Deployment script for YieldPoolShare token
 */
contract DeployYieldPoolShare is Script {
    function run() external {
        // Use FACILITATOR key for deployment
        uint256 facilitatorPrivateKey = vm.envUint("FACILITATOR_PRIVATE_KEY");
        address facilitator = vm.addr(facilitatorPrivateKey);
        
        console.log("Deploying YieldPoolShare...");
        console.log("Deployer (Facilitator):", facilitator);
        
        vm.startBroadcast(facilitatorPrivateKey);
        
        // Deploy YieldPoolShare with facilitator as initial owner
        YieldPoolShare yps = new YieldPoolShare(facilitator);
        
        console.log("YieldPoolShare deployed at:", address(yps));
        console.log("Name:", yps.name());
        console.log("Symbol:", yps.symbol());
        console.log("Decimals:", yps.decimals());
        
        vm.stopBroadcast();
    }
}

