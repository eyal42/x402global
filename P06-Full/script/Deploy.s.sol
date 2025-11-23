// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/YieldPoolShare.sol";
import "../src/SettlementVault.sol";
import "../src/PermitPuller.sol";
import "../src/FacilitatorHook.sol";

/**
 * @title Deploy
 * @notice Deployment script for OTC API contracts on Polygon Amoy
 * @dev Run with: forge script script/Deploy.s.sol:Deploy --rpc-url $POLYGON_AMOY_RPC_URL --broadcast --verify
 */
contract Deploy is Script {
    // Mock token addresses from environment
    address mockUSDC;
    address mockEURC;
    
    // Deployed contracts
    YieldPoolShare public yieldPoolShare;
    SettlementVault public vault;
    PermitPuller public permitPuller;
    FacilitatorHook public facilitatorHook;
    
    function setUp() public {
        // Load mock token addresses from environment
        mockUSDC = vm.envAddress("MOCK_USDC_ADDRESS_POLYGON");
        mockEURC = vm.envAddress("MOCK_EURC_ADDRESS_POLYGON");
        
        require(mockUSDC != address(0), "MOCK_USDC_ADDRESS_POLYGON not set");
        require(mockEURC != address(0), "MOCK_EURC_ADDRESS_POLYGON not set");
    }
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts on Polygon Amoy...");
        console.log("Deployer:", deployer);
        console.log("MockUSDC:", mockUSDC);
        console.log("MockEURC:", mockEURC);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy YieldPoolShare (asset token)
        console.log("\n1. Deploying YieldPoolShare...");
        yieldPoolShare = new YieldPoolShare(deployer);
        console.log("YieldPoolShare deployed at:", address(yieldPoolShare));
        
        // 2. Deploy SettlementVault (will set facilitator later)
        console.log("\n2. Deploying SettlementVault...");
        vault = new SettlementVault(
            mockEURC,
            mockUSDC,
            address(0), // Will be set to FacilitatorHook after deployment
            deployer
        );
        console.log("SettlementVault deployed at:", address(vault));
        
        // 3. Deploy PermitPuller
        console.log("\n3. Deploying PermitPuller...");
        permitPuller = new PermitPuller(
            address(vault),
            mockEURC,
            deployer
        );
        console.log("PermitPuller deployed at:", address(permitPuller));
        
        // 4. Deploy FacilitatorHook
        console.log("\n4. Deploying FacilitatorHook...");
        facilitatorHook = new FacilitatorHook(
            address(vault),
            mockEURC,
            mockUSDC,
            deployer
        );
        console.log("FacilitatorHook deployed at:", address(facilitatorHook));
        
        // 5. Configure vault facilitator
        console.log("\n5. Configuring SettlementVault facilitator...");
        vault.setFacilitator(address(facilitatorHook));
        console.log("Facilitator set to FacilitatorHook");
        
        vm.stopBroadcast();
        
        // Print deployment summary
        console.log("\n========================================");
        console.log("DEPLOYMENT SUMMARY");
        console.log("========================================");
        console.log("YieldPoolShare:", address(yieldPoolShare));
        console.log("SettlementVault:", address(vault));
        console.log("PermitPuller:", address(permitPuller));
        console.log("FacilitatorHook:", address(facilitatorHook));
        console.log("========================================");
        
        // Save addresses to file for easy reference
        string memory deploymentInfo = string.concat(
            "# Deployed Contract Addresses\n",
            "YIELD_POOL_SHARE_ADDRESS=", vm.toString(address(yieldPoolShare)), "\n",
            "SETTLEMENT_VAULT_ADDRESS=", vm.toString(address(vault)), "\n",
            "PERMIT_PULLER_ADDRESS=", vm.toString(address(permitPuller)), "\n",
            "FACILITATOR_HOOK_ADDRESS=", vm.toString(address(facilitatorHook)), "\n"
        );
        
        vm.writeFile("deployed_addresses.txt", deploymentInfo);
        console.log("\nDeployment addresses saved to deployed_addresses.txt");
    }
}

