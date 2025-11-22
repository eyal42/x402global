// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/MockTokenBase.sol";

/**
 * @title SmokeTest
 * @notice On-chain verification tests for deployed contracts
 * @dev Usage: forge script script/SmokeTest.s.sol:SmokeTest --rpc-url <rpc-url> --sig "run(address)" <token-address>
 */
contract SmokeTest is Script {
    function run(address tokenAddress) external view {
        MockTokenBase token = MockTokenBase(tokenAddress);
        
        console.log("\n=== Smoke Test for", tokenAddress, "===\n");
        
        // Test 1: Basic Info
        console.log("[TEST 1] Basic Token Info");
        try token.name() returns (string memory name) {
            console.log("  Name:", name);
            console.log("  PASS");
        } catch {
            console.log("  FAIL: Could not read name");
        }
        
        try token.symbol() returns (string memory symbol) {
            console.log("  Symbol:", symbol);
            console.log("  PASS");
        } catch {
            console.log("  FAIL: Could not read symbol");
        }
        
        try token.decimals() returns (uint8 decimals) {
            console.log("  Decimals:", decimals);
            if (decimals == 6) {
                console.log("  PASS: Correct decimals (6)");
            } else {
                console.log("  FAIL: Wrong decimals, expected 6");
            }
        } catch {
            console.log("  FAIL: Could not read decimals");
        }
        
        // Test 2: Supply
        console.log("\n[TEST 2] Total Supply");
        try token.totalSupply() returns (uint256 supply) {
            console.log("  Total Supply:", supply);
            console.log("  PASS");
        } catch {
            console.log("  FAIL: Could not read total supply");
        }
        
        // Test 3: Roles
        console.log("\n[TEST 3] Role Constants");
        try token.DEFAULT_ADMIN_ROLE() returns (bytes32 role) {
            console.log("  DEFAULT_ADMIN_ROLE exists");
            console.log("  PASS");
        } catch {
            console.log("  FAIL: Could not read DEFAULT_ADMIN_ROLE");
        }
        
        try token.MASTER_MINTER_ROLE() returns (bytes32 role) {
            console.log("  MASTER_MINTER_ROLE exists");
            console.log("  PASS");
        } catch {
            console.log("  FAIL: Could not read MASTER_MINTER_ROLE");
        }
        
        try token.MINTER_ROLE() returns (bytes32 role) {
            console.log("  MINTER_ROLE exists");
            console.log("  PASS");
        } catch {
            console.log("  FAIL: Could not read MINTER_ROLE");
        }
        
        try token.BRIDGE_ROLE() returns (bytes32 role) {
            console.log("  BRIDGE_ROLE exists");
            console.log("  PASS");
        } catch {
            console.log("  FAIL: Could not read BRIDGE_ROLE");
        }
        
        // Test 4: Blacklist Function
        console.log("\n[TEST 4] Blacklist Functionality");
        address testAddr = address(0x1234);
        try token.isBlacklisted(testAddr) returns (bool blacklisted) {
            console.log("  Can check blacklist status");
            console.log("  PASS");
        } catch {
            console.log("  FAIL: Could not check blacklist");
        }
        
        // Test 5: Minter Allowance
        console.log("\n[TEST 5] Minter Allowance");
        try token.minterAllowance(testAddr) returns (uint256 allowance) {
            console.log("  Can check minter allowance");
            console.log("  PASS");
        } catch {
            console.log("  FAIL: Could not check minter allowance");
        }
        
        // Test 6: EIP-2612 (Permit)
        console.log("\n[TEST 6] EIP-2612 Permit Support");
        try token.DOMAIN_SEPARATOR() returns (bytes32 separator) {
            console.log("  DOMAIN_SEPARATOR exists");
            console.log("  PASS");
        } catch {
            console.log("  FAIL: Could not read DOMAIN_SEPARATOR");
        }
        
        try token.nonces(testAddr) returns (uint256 nonce) {
            console.log("  Can read nonces");
            console.log("  PASS");
        } catch {
            console.log("  FAIL: Could not read nonces");
        }
        
        console.log("\n=== Smoke Test Complete ===\n");
    }
}

