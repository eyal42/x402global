// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

/**
 * @title IMockToken
 * @notice Interface for MockUSDC and MockEURC tokens with EIP-2612 permit
 */
interface IMockToken is IERC20, IERC20Permit {
    // Additional functions from MockTokenBase
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function decimals() external view returns (uint8);
    function nonces(address owner) external view returns (uint256);
}

