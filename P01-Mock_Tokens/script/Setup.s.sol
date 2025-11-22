// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/MockTokenBase.sol";

/**
 * @title Setup
 * @notice Post-deployment configuration script
 * @dev Reads MINTER address and CCY from command line, sets up Minter to mint CCY
 * @dev Usage: forge script script/Setup.s.sol:Setup --rpc-url <rpc-url> --broadcast --sig "run(address,address)" <token-address> <minter-address>
 */
contract Setup is Script {
    function run(address tokenAddress, address minterAddress) external {
        MockTokenBase token = MockTokenBase(tokenAddress);
        
        vm.startBroadcast();
        
        address deployer = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        
        // Grant MASTER_MINTER_ROLE to deployer (if not already granted)
        if (!token.hasRole(token.MASTER_MINTER_ROLE(), deployer)) {
            console.log("Granting MASTER_MINTER_ROLE to:", deployer);
            token.grantRole(token.MASTER_MINTER_ROLE(), deployer);
        } else {
            console.log("MASTER_MINTER_ROLE already granted to:", deployer);
        }
        
        // Grant MINTER_ROLE to minter (if not already granted)
        if (!token.hasRole(token.MINTER_ROLE(), minterAddress)) {
            console.log("Granting MINTER_ROLE to:", minterAddress);
            token.grantRole(token.MINTER_ROLE(), minterAddress);
        } else {
            console.log("MINTER_ROLE already granted to:", minterAddress);
        }
        
        // Configure minter allowance (1 billion tokens = 1,000,000,000 * 10^6)
        uint256 allowance = 1_000_000_000e6;
        console.log("Configuring minter allowance:", allowance);
        token.configureMinter(minterAddress, allowance);
        
        vm.stopBroadcast();
        
        console.log("\n=== Setup Complete ===");
        console.log("Token:", tokenAddress);
        console.log("Minter:", minterAddress);
        console.log("Allowance:", allowance);
        console.log("======================\n");
    }
}

