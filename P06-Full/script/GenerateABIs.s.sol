// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/interfaces/IMockToken.sol";

/**
 * @title GenerateABIs
 * @notice Script to ensure all necessary ABIs are compiled
 * @dev This forces compilation of interfaces we need ABIs for
 */
contract GenerateABIs is Script {
    function run() public pure {
        // Just importing the interface ensures ABI is generated
        // No actual execution needed
    }
}

