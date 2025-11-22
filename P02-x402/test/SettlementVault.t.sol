// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/SettlementVault.sol";
import "../src/YieldPoolShare.sol";
import "../src/SwapSimulator.sol";
import "mock-tokens/MockEURC.sol";
import "mock-tokens/MockUSDC.sol";

/**
 * @title SettlementVaultTest
 * @notice Tests for SettlementVault contract
 */
contract SettlementVaultTest is Test {
    SettlementVault public vault;
    YieldPoolShare public yps;
    SwapSimulator public simulator;
    MockEURC public mockEURC;
    MockUSDC public mockUSDC;
    
    address public owner;
    address public client;
    address public seller;
    
    function setUp() public {
        owner = address(this);
        client = address(0x1);
        seller = address(0x2);
        
        // Deploy contracts
        yps = new YieldPoolShare(owner);
        simulator = new SwapSimulator(owner);
        vault = new SettlementVault(owner);
        mockEURC = new MockEURC(owner);
        mockUSDC = new MockUSDC(owner);
        
        // Setup
        vault.setSwapSimulator(address(simulator));
        simulator.setExchangeRate(address(mockEURC), address(mockUSDC), 1.05e18, 18);
        
        // Mint tokens
        yps.mint(address(vault), 1000 * 1e18);
    }
    
    function testCreatePaymentRequest() public {
        bytes32 orderId = keccak256("order1");
        uint256 deadline = block.timestamp + 1 hours;
        
        vault.createPaymentRequest(
            orderId,
            client,
            seller,
            address(yps),
            10 * 1e18,
            address(mockUSDC),
            100 * 1e6,
            deadline
        );
        
        SettlementVault.Order memory order = vault.getOrder(orderId);
        assertEq(order.client, client);
        assertEq(order.seller, seller);
        assertEq(order.assetAmount, 10 * 1e18);
        assertEq(order.settlementAmount, 100 * 1e6);
    }
    
    function testCannotCreateDuplicateOrder() public {
        bytes32 orderId = keccak256("order1");
        uint256 deadline = block.timestamp + 1 hours;
        
        vault.createPaymentRequest(
            orderId,
            client,
            seller,
            address(yps),
            10 * 1e18,
            address(mockUSDC),
            100 * 1e6,
            deadline
        );
        
        vm.expectRevert("Order already exists");
        vault.createPaymentRequest(
            orderId,
            client,
            seller,
            address(yps),
            10 * 1e18,
            address(mockUSDC),
            100 * 1e6,
            deadline
        );
    }
}

