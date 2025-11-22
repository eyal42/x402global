// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./MockTokenBase.sol";

/**
 * @title MockUSDC
 * @notice Mock USDC token for testing and development
 * @dev Inherits all features from MockTokenBase
 */
contract MockUSDC is MockTokenBase {
    /**
     * @notice Deploy MockUSDC token
     * @param admin Initial admin address
     */
    constructor(address admin) 
        MockTokenBase("Mock USD Coin", "MockUSDC", admin) 
    {}
}

