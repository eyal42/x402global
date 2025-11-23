// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/YieldPoolShare.sol";
import "../src/SettlementVault.sol";
import "../src/PermitPuller.sol";
import "../src/FacilitatorHook.sol";

/**
 * @title Interact
 * @notice Interaction script for testing the OTC flow
 */
contract Interact is Script {
    YieldPoolShare public yieldPoolShare;
    SettlementVault public vault;
    PermitPuller public permitPuller;
    FacilitatorHook public facilitatorHook;
    
    address mockUSDC;
    address mockEURC;
    
    function setUp() public {
        // Load addresses
        yieldPoolShare = YieldPoolShare(vm.envAddress("YIELD_POOL_SHARE_ADDRESS"));
        vault = SettlementVault(vm.envAddress("SETTLEMENT_VAULT_ADDRESS"));
        permitPuller = PermitPuller(vm.envAddress("PERMIT_PULLER_ADDRESS"));
        facilitatorHook = FacilitatorHook(vm.envAddress("FACILITATOR_HOOK_ADDRESS"));
        
        mockUSDC = vm.envAddress("MOCK_USDC_ADDRESS_POLYGON");
        mockEURC = vm.envAddress("MOCK_EURC_ADDRESS_POLYGON");
    }
    
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        
        // Example: Check balances
        address user = vm.addr(privateKey);
        console.log("User:", user);
        console.log("YieldPoolShare balance:", yieldPoolShare.balanceOf(user));
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Mint test tokens for a user (seller gets YPS, buyer gets MockEURC)
     */
    function mintTestTokens() public {
        uint256 sellerKey = vm.envUint("SELLER_PRIVATE_KEY");
        uint256 buyerKey = vm.envUint("BUYER_PRIVATE_KEY");
        
        address seller = vm.addr(sellerKey);
        address buyer = vm.addr(buyerKey);
        
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        console.log("Deployer:", deployer);
        console.log("Seller:", seller);
        console.log("Buyer:", buyer);
        console.log("YieldPoolShare contract:", address(yieldPoolShare));
        
        // Check contract exists
        uint256 codeSize;
        address target = address(yieldPoolShare);
        assembly {
            codeSize := extcodesize(target)
        }
        console.log("Contract code size:", codeSize);
        
        if (codeSize == 0) {
            console.log("ERROR: YieldPoolShare contract not found at address!");
            console.log("Please verify deployment was successful");
            return;
        }
        
        // Check who is the owner
        address owner = yieldPoolShare.owner();
        console.log("YieldPoolShare owner:", owner);
        
        if (owner != deployer) {
            console.log("ERROR: Deployer is not the owner!");
            console.log("Expected:", deployer);
            console.log("Actual:", owner);
            return;
        }
        
        vm.startBroadcast(deployerKey);
        
        // Mint YieldPoolShares to seller
        console.log("\nMinting 1000 YPS to seller:", seller);
        yieldPoolShare.mint(seller, 1000 * 10**18);
        
        console.log("Seller YPS balance:", yieldPoolShare.balanceOf(seller));
        
        vm.stopBroadcast();
        
        console.log("\nNote: Buyer needs MockEURC tokens from the token faucet/minter");
        console.log("Buyer address:", buyer);
    }
    
    /**
     * @notice Create a test settlement
     */
    function createTestSettlement() public {
        uint256 facilitatorKey = vm.envUint("PRIVATE_KEY");
        address seller = vm.addr(vm.envUint("SELLER_PRIVATE_KEY"));
        address buyer = vm.addr(vm.envUint("BUYER_PRIVATE_KEY"));
        
        vm.startBroadcast(facilitatorKey);
        
        // Create settlement: buyer wants 100 YPS, seller wants 110 USDC
        bytes32 settlementId = vault.createSettlement(
            buyer,                          // client
            seller,                         // seller
            address(yieldPoolShare),        // assetToken
            100 * 10**18,                   // 100 YPS
            110 * 10**6,                    // 110 USDC (6 decimals)
            121 * 10**6                     // max 121 EURC (110 * 1.10)
        );
        
        console.log("Settlement created:");
        console.log("Settlement ID:", vm.toString(settlementId));
        console.log("Buyer:", buyer);
        console.log("Seller:", seller);
        console.log("Asset Amount: 100 YPS");
        console.log("Required USDC: 110");
        console.log("Max EURC: 121");
        
        vm.stopBroadcast();
    }
}

