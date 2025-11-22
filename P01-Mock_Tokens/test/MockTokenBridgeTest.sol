// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/MockUSDC.sol";

/**
 * @title MockTokenBridgeTest
 * @notice Tests bridge integration hooks
 */
contract MockTokenBridgeTest is Test {
    MockUSDC public token;
    
    address public admin = address(1);
    address public bridge = address(2);
    address public user1 = address(3);
    address public user2 = address(4);
    address public minter = address(5);
    address public masterMinter = address(6);
    address public unauthorized = address(7);
    
    bytes32 public constant CHAIN_ARBITRUM = keccak256("arbitrum");
    bytes32 public constant CHAIN_POLYGON = keccak256("polygon");
    
    event BridgeBurn(
        address indexed from,
        bytes32 indexed dstChain,
        bytes indexed dstRecipient,
        uint256 amount,
        bytes data
    );
    
    event BridgeMint(
        bytes32 indexed srcChain,
        bytes indexed srcSender,
        address indexed to,
        uint256 amount,
        bytes data
    );
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    function setUp() public {
        token = new MockUSDC(admin);
        
        // Grant roles
        vm.startPrank(admin);
        token.grantRole(token.BRIDGE_ROLE(), bridge);
        token.grantRole(token.MASTER_MINTER_ROLE(), masterMinter);
        token.grantRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();
        
        // Configure minter and mint tokens
        vm.prank(masterMinter);
        token.configureMinter(minter, 1_000_000e6);
        
        vm.prank(minter);
        token.mint(user1, 1000e6);
    }
    
    // ============ Role Tests ============
    
    function test_BridgeRole() public view {
        assertTrue(token.hasRole(token.BRIDGE_ROLE(), bridge));
    }
    
    // ============ Bridge Burn Tests ============
    
    function test_BridgeBurn() public {
        uint256 burnAmount = 100e6;
        bytes memory dstRecipient = abi.encodePacked(user2);
        bytes memory data = abi.encode("test-data");
        
        uint256 balanceBefore = token.balanceOf(bridge);
        uint256 supplyBefore = token.totalSupply();
        
        // First transfer tokens to bridge
        vm.prank(user1);
        token.transfer(bridge, burnAmount);
        
        vm.prank(bridge);
        vm.expectEmit(true, true, true, true);
        emit BridgeBurn(bridge, CHAIN_POLYGON, dstRecipient, burnAmount, data);
        token.bridgeBurn(CHAIN_POLYGON, dstRecipient, burnAmount, data);
        
        assertEq(token.balanceOf(bridge), balanceBefore);
        assertEq(token.totalSupply(), supplyBefore - burnAmount);
    }
    
    function test_BridgeBurn_EmptyData() public {
        uint256 burnAmount = 100e6;
        bytes memory dstRecipient = abi.encodePacked(user2);
        bytes memory data = "";
        
        vm.prank(user1);
        token.transfer(bridge, burnAmount);
        
        vm.prank(bridge);
        token.bridgeBurn(CHAIN_POLYGON, dstRecipient, burnAmount, data);
        
        assertEq(token.balanceOf(bridge), 0);
    }
    
    function test_BridgeBurn_MultipleBurns() public {
        vm.prank(user1);
        token.transfer(bridge, 300e6);
        
        bytes memory dstRecipient = abi.encodePacked(user2);
        bytes memory data = "";
        
        vm.startPrank(bridge);
        token.bridgeBurn(CHAIN_POLYGON, dstRecipient, 100e6, data);
        token.bridgeBurn(CHAIN_ARBITRUM, dstRecipient, 100e6, data);
        token.bridgeBurn(CHAIN_POLYGON, dstRecipient, 100e6, data);
        vm.stopPrank();
        
        assertEq(token.balanceOf(bridge), 0);
        assertEq(token.totalSupply(), 700e6);
    }
    
    function test_BridgeBurn_RevertNotBridge() public {
        bytes memory dstRecipient = abi.encodePacked(user2);
        bytes memory data = "";
        
        vm.prank(user1);
        vm.expectRevert();
        token.bridgeBurn(CHAIN_POLYGON, dstRecipient, 100e6, data);
    }
    
    function test_BridgeBurn_RevertZeroAmount() public {
        bytes memory dstRecipient = abi.encodePacked(user2);
        bytes memory data = "";
        
        vm.prank(bridge);
        vm.expectRevert();
        token.bridgeBurn(CHAIN_POLYGON, dstRecipient, 0, data);
    }
    
    function test_BridgeBurn_RevertZeroRecipient() public {
        bytes memory dstRecipient = "";
        bytes memory data = "";
        
        vm.prank(bridge);
        vm.expectRevert();
        token.bridgeBurn(CHAIN_POLYGON, dstRecipient, 100e6, data);
    }
    
    function test_BridgeBurn_RevertInsufficientBalance() public {
        bytes memory dstRecipient = abi.encodePacked(user2);
        bytes memory data = "";
        
        vm.prank(bridge);
        vm.expectRevert();
        token.bridgeBurn(CHAIN_POLYGON, dstRecipient, 100e6, data);
    }
    
    // ============ Bridge Mint Tests ============
    
    function test_BridgeMint() public {
        uint256 mintAmount = 100e6;
        bytes memory srcSender = abi.encodePacked(user1);
        bytes memory data = abi.encode("test-data");
        
        uint256 balanceBefore = token.balanceOf(user2);
        uint256 supplyBefore = token.totalSupply();
        
        vm.prank(bridge);
        vm.expectEmit(true, true, true, true);
        emit BridgeMint(CHAIN_POLYGON, srcSender, user2, mintAmount, data);
        token.bridgeMint(CHAIN_POLYGON, srcSender, user2, mintAmount, data);
        
        assertEq(token.balanceOf(user2), balanceBefore + mintAmount);
        assertEq(token.totalSupply(), supplyBefore + mintAmount);
    }
    
    function test_BridgeMint_EmptyData() public {
        uint256 mintAmount = 100e6;
        bytes memory srcSender = abi.encodePacked(user1);
        bytes memory data = "";
        
        vm.prank(bridge);
        token.bridgeMint(CHAIN_POLYGON, srcSender, user2, mintAmount, data);
        
        assertEq(token.balanceOf(user2), mintAmount);
    }
    
    function test_BridgeMint_MultipleMints() public {
        bytes memory srcSender = abi.encodePacked(user1);
        bytes memory data = "";
        
        vm.startPrank(bridge);
        token.bridgeMint(CHAIN_POLYGON, srcSender, user2, 100e6, data);
        token.bridgeMint(CHAIN_ARBITRUM, srcSender, user2, 200e6, data);
        token.bridgeMint(CHAIN_POLYGON, srcSender, user2, 300e6, data);
        vm.stopPrank();
        
        assertEq(token.balanceOf(user2), 600e6);
    }
    
    function test_BridgeMint_RevertNotBridge() public {
        bytes memory srcSender = abi.encodePacked(user1);
        bytes memory data = "";
        
        vm.prank(user1);
        vm.expectRevert();
        token.bridgeMint(CHAIN_POLYGON, srcSender, user2, 100e6, data);
    }
    
    function test_BridgeMint_RevertZeroAmount() public {
        bytes memory srcSender = abi.encodePacked(user1);
        bytes memory data = "";
        
        vm.prank(bridge);
        vm.expectRevert();
        token.bridgeMint(CHAIN_POLYGON, srcSender, user2, 0, data);
    }
    
    function test_BridgeMint_RevertZeroAddress() public {
        bytes memory srcSender = abi.encodePacked(user1);
        bytes memory data = "";
        
        vm.prank(bridge);
        vm.expectRevert();
        token.bridgeMint(CHAIN_POLYGON, srcSender, address(0), 100e6, data);
    }
    
    function test_BridgeMint_RevertToBlacklisted() public {
        bytes memory srcSender = abi.encodePacked(user1);
        bytes memory data = "";
        
        vm.prank(admin);
        token.setBlacklisted(user2, true);
        
        vm.prank(bridge);
        vm.expectRevert();
        token.bridgeMint(CHAIN_POLYGON, srcSender, user2, 100e6, data);
    }
    
    // ============ Round-Trip Tests ============
    
    function test_BridgeRoundTrip() public {
        uint256 amount = 100e6;
        bytes memory dstRecipient = abi.encodePacked(user2);
        bytes memory srcSender = abi.encodePacked(user1);
        bytes memory data = "";
        
        uint256 initialSupply = token.totalSupply();
        
        // Transfer to bridge and burn
        vm.prank(user1);
        token.transfer(bridge, amount);
        
        vm.prank(bridge);
        token.bridgeBurn(CHAIN_POLYGON, dstRecipient, amount, data);
        
        assertEq(token.totalSupply(), initialSupply - amount);
        
        // Mint on destination
        vm.prank(bridge);
        token.bridgeMint(CHAIN_POLYGON, srcSender, user2, amount, data);
        
        assertEq(token.totalSupply(), initialSupply);
        assertEq(token.balanceOf(user2), amount);
    }
}

