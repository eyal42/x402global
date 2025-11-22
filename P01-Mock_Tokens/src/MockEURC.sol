// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./MockTokenBase.sol";

/**
 * @title MockEURC
 * @notice Mock EURC token for testing and development
 * @dev Inherits all features from MockTokenBase
 */
contract MockEURC is MockTokenBase {
    /**
     * @notice Deploy MockEURC token
     * @param admin Initial admin address
     */
    constructor(address admin) 
        MockTokenBase("Mock Euro Coin", "MockEURC", admin) 
    {}
}

