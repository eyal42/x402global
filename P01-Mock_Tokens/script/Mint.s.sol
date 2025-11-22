// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/MockTokenBase.sol";

/**
 * @title Mint
 * @notice Mint tokens to a user
 * @dev Reads MINTER, USER and CCY addresses from command line, has MINTER mint CCY to USER
 * @dev Usage: forge script script/Mint.s.sol:Mint --rpc-url <rpc-url> --broadcast --sig "run(address,address,uint256)" <token-address> <user-address> <amount>
 */
contract Mint is Script {
    function run(address tokenAddress, address userAddress, uint256 amount) external {
        MockTokenBase token = MockTokenBase(tokenAddress);
        
        vm.startBroadcast();
        
        console.log("Minting", amount, "tokens to", userAddress);
        token.mint(userAddress, amount);
        
        vm.stopBroadcast();
        
        console.log("\n=== Mint Complete ===");
        console.log("Token:", tokenAddress);
        console.log("User:", userAddress);
        console.log("Amount:", amount);
        console.log("New Balance:", token.balanceOf(userAddress));
        console.log("=====================\n");
    }
}
