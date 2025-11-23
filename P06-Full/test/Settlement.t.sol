// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/YieldPoolShare.sol";
import "../src/SettlementVault.sol";
import "../src/PermitPuller.sol";
import "../src/FacilitatorHook.sol";

/**
 * @title SettlementTest
 * @notice Tests for the OTC settlement system
 */
contract SettlementTest is Test {
    YieldPoolShare public yieldPoolShare;
    SettlementVault public vault;
    PermitPuller public permitPuller;
    FacilitatorHook public facilitatorHook;
    
    address public mockEURC;
    address public mockUSDC;
    
    address public owner;
    address public seller;
    address public buyer;
    address public facilitator;
    
    function setUp() public {
        owner = address(this);
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");
        facilitator = makeAddr("facilitator");
        
        // Deploy mock tokens (simplified for testing)
        mockEURC = makeAddr("mockEURC");
        mockUSDC = makeAddr("mockUSDC");
        
        // Deploy contracts
        yieldPoolShare = new YieldPoolShare(owner);
        
        vault = new SettlementVault(
            mockEURC,
            mockUSDC,
            facilitator,
            owner
        );
        
        permitPuller = new PermitPuller(
            address(vault),
            mockEURC,
            owner
        );
        
        facilitatorHook = new FacilitatorHook(
            address(vault),
            mockEURC,
            mockUSDC,
            owner
        );
        
        // Configure vault
        vault.setFacilitator(address(facilitatorHook));
        
        // Mint tokens for testing
        yieldPoolShare.mint(seller, 1000 * 10**18);
    }
    
    function testDeployment() public view {
        assertEq(yieldPoolShare.owner(), owner);
        assertEq(address(vault.mockEURC()), mockEURC);
        assertEq(address(vault.mockUSDC()), mockUSDC);
        assertEq(vault.facilitator(), address(facilitatorHook));
    }
    
    function testCreateSettlement() public {
        vm.prank(address(facilitatorHook));
        bytes32 settlementId = vault.createSettlement(
            buyer,
            seller,
            address(yieldPoolShare),
            100 * 10**18,  // 100 YPS
            110 * 10**6,   // 110 USDC
            121 * 10**6    // 121 EURC max
        );
        
        SettlementVault.Settlement memory settlement = vault.getSettlement(settlementId);
        
        assertEq(settlement.client, buyer);
        assertEq(settlement.seller, seller);
        assertEq(settlement.assetAmount, 100 * 10**18);
        assertEq(settlement.requiredUSDC, 110 * 10**6);
        assertEq(settlement.maxEURC, 121 * 10**6);
        assertEq(uint(settlement.state), uint(SettlementVault.SettlementState.Pending));
    }
    
    function testCannotCreateSettlementUnauthorized() public {
        vm.prank(buyer);
        vm.expectRevert(SettlementVault.Unauthorized.selector);
        vault.createSettlement(
            buyer,
            seller,
            address(yieldPoolShare),
            100 * 10**18,
            110 * 10**6,
            121 * 10**6
        );
    }
    
    function testYieldPoolShareMint() public {
        uint256 balanceBefore = yieldPoolShare.balanceOf(seller);
        
        yieldPoolShare.mint(seller, 100 * 10**18);
        
        uint256 balanceAfter = yieldPoolShare.balanceOf(seller);
        assertEq(balanceAfter - balanceBefore, 100 * 10**18);
    }
    
    function testYieldPoolShareBurn() public {
        vm.prank(seller);
        yieldPoolShare.burn(50 * 10**18);
        
        assertEq(yieldPoolShare.balanceOf(seller), 950 * 10**18);
    }
    
    function testSettlementNonceIncrement() public {
        uint256 nonceBefore = vault.settlementNonce();
        
        vm.prank(address(facilitatorHook));
        vault.createSettlement(
            buyer,
            seller,
            address(yieldPoolShare),
            100 * 10**18,
            110 * 10**6,
            121 * 10**6
        );
        
        uint256 nonceAfter = vault.settlementNonce();
        assertEq(nonceAfter, nonceBefore + 1);
    }
    
    function testFacilitatorUpdate() public {
        address newFacilitator = makeAddr("newFacilitator");
        
        vault.setFacilitator(newFacilitator);
        
        assertEq(vault.facilitator(), newFacilitator);
    }
    
    function testCannotSetZeroAddressFacilitator() public {
        vm.expectRevert(SettlementVault.ZeroAddress.selector);
        vault.setFacilitator(address(0));
    }
}

