// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/MockTokenBase.sol";

/**
 * @title CheckMasterMinterRole
 * @notice Check if an address has the MASTER_MINTER_ROLE for a token
 * @dev Usage: forge script script/CheckMasterMinterRole.s.sol:CheckMasterMinterRole \
 *      --rpc-url <rpc-url> \
 *      --sig "run(address,address)" <token-address> <address-to-check>
 */
contract CheckMasterMinterRole is Script {
    function run(address tokenAddress, address addressToCheck) external view {
        MockTokenBase token = MockTokenBase(tokenAddress);
        
        // Get the MASTER_MINTER_ROLE hash
        bytes32 masterMinterRole = token.MASTER_MINTER_ROLE();
        
        // Check if address has the role
        bool hasMasterMinterRole = token.hasRole(masterMinterRole, addressToCheck);
        
        // Get token info for context
        string memory name = token.name();
        string memory symbol = token.symbol();
        
        console.log("\n=== Master Minter Role Check ===");
        console.log("Token:", tokenAddress);
        console.log("Token Name:", name);
        console.log("Token Symbol:", symbol);
        console.log("Address:", addressToCheck);
        console.log("--------------------------------");
        
        if (hasMasterMinterRole) {
            console.log("Result: YES - Address HAS Master Minter Role");
            console.log("This address can:");
            console.log("  - Configure minter allowances");
            console.log("  - Grant/revoke MINTER_ROLE (if also admin)");
        } else {
            console.log("Result: NO - Address DOES NOT have Master Minter Role");
        }
        
        // Also check other relevant roles for context
        console.log("\n=== Other Roles ===");
        
        bool hasAdminRole = token.hasRole(token.DEFAULT_ADMIN_ROLE(), addressToCheck);
        console.log("Admin Role:", hasAdminRole ? "YES" : "NO");
        
        bool hasMinterRole = token.hasRole(token.MINTER_ROLE(), addressToCheck);
        console.log("Minter Role:", hasMinterRole ? "YES" : "NO");
        
        bool hasBridgeRole = token.hasRole(token.BRIDGE_ROLE(), addressToCheck);
        console.log("Bridge Role:", hasBridgeRole ? "YES" : "NO");
        
        // If has minter role, show allowance
        if (hasMinterRole) {
            uint256 allowance = token.minterAllowance(addressToCheck);
            console.log("\nMinter Allowance:", allowance);
            console.log("Formatted:", allowance / 1e6, "tokens");
        }
        
        console.log("================================\n");
    }
}

