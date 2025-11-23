// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {PoolSettlementVault} from "../src/PoolSettlementVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Mock ERC20 for testing
contract MockERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 6;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
}

/**
 * @title PoolSettlementVaultTest
 * @notice Comprehensive tests for the PoolSettlementVault contract
 */
contract PoolSettlementVaultTest is Test {
    PoolSettlementVault public vault;
    MockERC20 public assetToken;
    MockERC20 public eurcToken;
    MockERC20 public usdcToken;
    
    address public owner = address(0x1);
    address public client = address(0x2);
    address public seller = address(0x3);
    address public facilitator = address(0x4);
    address public poolManager = address(0x5);
    
    bytes32 public vaultId = keccak256("VAULT_1");
    
    uint256 constant ASSET_AMOUNT = 1000 * 10**6;
    uint256 constant REQUIRED_USDC = 500 * 10**6;
    uint256 constant EURC_AMOUNT = 550 * 10**6;
    
    function setUp() public {
        // Deploy tokens
        assetToken = new MockERC20("Asset", "ASSET");
        eurcToken = new MockERC20("MockEURC", "EURC");
        usdcToken = new MockERC20("MockUSDC", "USDC");
        
        // Deploy vault
        vm.prank(owner);
        vault = new PoolSettlementVault(owner);
        
        // Configure vault
        vm.startPrank(owner);
        vault.setPoolManager(poolManager);
        vault.setFacilitator(facilitator);
        vm.stopPrank();
        
        // Mint tokens to participants
        assetToken.mint(seller, ASSET_AMOUNT);
        eurcToken.mint(client, EURC_AMOUNT);
        usdcToken.mint(facilitator, REQUIRED_USDC);
    }
    
    // ============ Configuration Tests ============
    
    function test_InitialConfiguration() public view {
        assertEq(vault.owner(), owner);
        assertEq(vault.poolManager(), poolManager);
        assertEq(vault.facilitator(), facilitator);
    }
    
    function test_SetPoolManager() public {
        address newManager = address(0x100);
        
        vm.prank(owner);
        vault.setPoolManager(newManager);
        
        assertEq(vault.poolManager(), newManager);
    }
    
    function test_SetFacilitator() public {
        address newFacilitator = address(0x200);
        
        vm.prank(owner);
        vault.setFacilitator(newFacilitator);
        
        assertEq(vault.facilitator(), newFacilitator);
    }
    
    // ============ Vault Creation Tests ============
    
    function test_CreateVault() public {
        uint256 deadline = block.timestamp + 1 days;
        
        vm.prank(owner);
        vault.createVault(
            vaultId,
            client,
            seller,
            address(assetToken),
            ASSET_AMOUNT,
            address(eurcToken),
            address(usdcToken),
            REQUIRED_USDC,
            deadline
        );
        
        PoolSettlementVault.Vault memory v = vault.getVault(vaultId);
        
        assertEq(v.client, client);
        assertEq(v.seller, seller);
        assertEq(v.assetAmount, ASSET_AMOUNT);
        assertEq(v.requiredUSDC, REQUIRED_USDC);
        assertEq(uint256(v.status), uint256(PoolSettlementVault.VaultStatus.Created));
    }
    
    function test_CreateVault_RevertInvalidClient() public {
        vm.prank(owner);
        vm.expectRevert(PoolSettlementVault.InvalidAddress.selector);
        vault.createVault(
            vaultId,
            address(0),
            seller,
            address(assetToken),
            ASSET_AMOUNT,
            address(eurcToken),
            address(usdcToken),
            REQUIRED_USDC,
            block.timestamp + 1 days
        );
    }
    
    function test_CreateVault_RevertAlreadyExists() public {
        uint256 deadline = block.timestamp + 1 days;
        
        vm.startPrank(owner);
        vault.createVault(
            vaultId,
            client,
            seller,
            address(assetToken),
            ASSET_AMOUNT,
            address(eurcToken),
            address(usdcToken),
            REQUIRED_USDC,
            deadline
        );
        
        vm.expectRevert(PoolSettlementVault.VaultAlreadyExists.selector);
        vault.createVault(
            vaultId,
            client,
            seller,
            address(assetToken),
            ASSET_AMOUNT,
            address(eurcToken),
            address(usdcToken),
            REQUIRED_USDC,
            deadline
        );
        vm.stopPrank();
    }
    
    // ============ Asset Deposit Tests ============
    
    function test_DepositAsset() public {
        // Create vault
        uint256 deadline = block.timestamp + 1 days;
        vm.prank(owner);
        vault.createVault(
            vaultId,
            client,
            seller,
            address(assetToken),
            ASSET_AMOUNT,
            address(eurcToken),
            address(usdcToken),
            REQUIRED_USDC,
            deadline
        );
        
        // Seller approves and deposits asset
        vm.startPrank(seller);
        assetToken.approve(address(vault), ASSET_AMOUNT);
        vault.depositAsset(vaultId);
        vm.stopPrank();
        
        PoolSettlementVault.Vault memory v = vault.getVault(vaultId);
        assertEq(uint256(v.status), uint256(PoolSettlementVault.VaultStatus.AssetDeposited));
        assertEq(assetToken.balanceOf(address(vault)), ASSET_AMOUNT);
    }
    
    function test_DepositAsset_RevertUnauthorized() public {
        uint256 deadline = block.timestamp + 1 days;
        vm.prank(owner);
        vault.createVault(
            vaultId,
            client,
            seller,
            address(assetToken),
            ASSET_AMOUNT,
            address(eurcToken),
            address(usdcToken),
            REQUIRED_USDC,
            deadline
        );
        
        vm.prank(client);
        vm.expectRevert(PoolSettlementVault.Unauthorized.selector);
        vault.depositAsset(vaultId);
    }
    
    // ============ EURC Deposit Tests ============
    
    function test_DepositEURC() public {
        // Create and deposit asset
        uint256 deadline = block.timestamp + 1 days;
        vm.prank(owner);
        vault.createVault(
            vaultId,
            client,
            seller,
            address(assetToken),
            ASSET_AMOUNT,
            address(eurcToken),
            address(usdcToken),
            REQUIRED_USDC,
            deadline
        );
        
        vm.startPrank(seller);
        assetToken.approve(address(vault), ASSET_AMOUNT);
        vault.depositAsset(vaultId);
        vm.stopPrank();
        
        // Client deposits EURC
        vm.startPrank(client);
        eurcToken.approve(address(vault), EURC_AMOUNT);
        vault.depositEURC(vaultId, EURC_AMOUNT);
        vm.stopPrank();
        
        PoolSettlementVault.Vault memory v = vault.getVault(vaultId);
        assertEq(uint256(v.status), uint256(PoolSettlementVault.VaultStatus.EURCDeposited));
        assertEq(v.eurcDeposited, EURC_AMOUNT);
        assertEq(eurcToken.balanceOf(address(vault)), EURC_AMOUNT);
    }
    
    // ============ Vault Opening Tests ============
    
    function test_OpenVault_HappyPath() public {
        // Setup complete vault
        uint256 deadline = block.timestamp + 1 days;
        vm.prank(owner);
        vault.createVault(
            vaultId,
            client,
            seller,
            address(assetToken),
            ASSET_AMOUNT,
            address(eurcToken),
            address(usdcToken),
            REQUIRED_USDC,
            deadline
        );
        
        // Deposit asset
        vm.startPrank(seller);
        assetToken.approve(address(vault), ASSET_AMOUNT);
        vault.depositAsset(vaultId);
        vm.stopPrank();
        
        // Deposit EURC
        vm.startPrank(client);
        eurcToken.approve(address(vault), EURC_AMOUNT);
        vault.depositEURC(vaultId, EURC_AMOUNT);
        vm.stopPrank();
        
        // Simulate USDC received from swap
        vm.prank(facilitator);
        vault.recordUSDCReceived(vaultId, REQUIRED_USDC);
        
        // Transfer USDC to vault
        vm.prank(facilitator);
        usdcToken.transfer(address(vault), REQUIRED_USDC);
        
        // Open vault
        uint256 clientAssetBefore = assetToken.balanceOf(client);
        uint256 sellerUSDCBefore = usdcToken.balanceOf(seller);
        
        vm.prank(client);
        vault.openVault(vaultId);
        
        // Check transfers
        assertEq(assetToken.balanceOf(client), clientAssetBefore + ASSET_AMOUNT);
        assertEq(usdcToken.balanceOf(seller), sellerUSDCBefore + REQUIRED_USDC);
        
        PoolSettlementVault.Vault memory v = vault.getVault(vaultId);
        assertEq(uint256(v.status), uint256(PoolSettlementVault.VaultStatus.Opened));
    }
    
    // ============ Timeout Tests ============
    
    function test_TimeoutVault() public {
        // Create vault with short deadline
        uint256 deadline = block.timestamp + 100;
        vm.prank(owner);
        vault.createVault(
            vaultId,
            client,
            seller,
            address(assetToken),
            ASSET_AMOUNT,
            address(eurcToken),
            address(usdcToken),
            REQUIRED_USDC,
            deadline
        );
        
        // Deposit asset
        vm.startPrank(seller);
        assetToken.approve(address(vault), ASSET_AMOUNT);
        vault.depositAsset(vaultId);
        vm.stopPrank();
        
        // Deposit EURC
        vm.startPrank(client);
        eurcToken.approve(address(vault), EURC_AMOUNT);
        vault.depositEURC(vaultId, EURC_AMOUNT);
        vm.stopPrank();
        
        // Fast forward past deadline
        vm.warp(deadline + 1);
        
        // Timeout vault
        uint256 sellerAssetBefore = assetToken.balanceOf(seller);
        uint256 clientEURCBefore = eurcToken.balanceOf(client);
        
        vm.prank(owner);
        vault.timeoutVault(vaultId);
        
        // Check reversals
        assertEq(assetToken.balanceOf(seller), sellerAssetBefore + ASSET_AMOUNT);
        assertEq(eurcToken.balanceOf(client), clientEURCBefore + EURC_AMOUNT);
        
        PoolSettlementVault.Vault memory v = vault.getVault(vaultId);
        assertEq(uint256(v.status), uint256(PoolSettlementVault.VaultStatus.Reversed));
    }
    
    // ============ View Function Tests ============
    
    function test_CanOpenVault() public {
        uint256 deadline = block.timestamp + 1 days;
        vm.prank(owner);
        vault.createVault(
            vaultId,
            client,
            seller,
            address(assetToken),
            ASSET_AMOUNT,
            address(eurcToken),
            address(usdcToken),
            REQUIRED_USDC,
            deadline
        );
        
        assertFalse(vault.canOpenVault(vaultId));
        
        // Complete flow
        vm.startPrank(seller);
        assetToken.approve(address(vault), ASSET_AMOUNT);
        vault.depositAsset(vaultId);
        vm.stopPrank();
        
        vm.startPrank(client);
        eurcToken.approve(address(vault), EURC_AMOUNT);
        vault.depositEURC(vaultId, EURC_AMOUNT);
        vm.stopPrank();
        
        vm.prank(facilitator);
        vault.recordUSDCReceived(vaultId, REQUIRED_USDC);
        
        assertTrue(vault.canOpenVault(vaultId));
    }
    
    function test_CanTimeoutVault() public {
        uint256 deadline = block.timestamp + 100;
        vm.prank(owner);
        vault.createVault(
            vaultId,
            client,
            seller,
            address(assetToken),
            ASSET_AMOUNT,
            address(eurcToken),
            address(usdcToken),
            REQUIRED_USDC,
            deadline
        );
        
        assertFalse(vault.canTimeoutVault(vaultId));
        
        // Fast forward
        vm.warp(deadline + 1);
        
        assertTrue(vault.canTimeoutVault(vaultId));
    }
}

