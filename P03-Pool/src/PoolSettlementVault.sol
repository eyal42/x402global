// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";

/**
 * @title PoolSettlementVault
 * @notice Vault contract for handling asset settlement with Uniswap v4 pool integration
 * @dev Manages the flow: asset deposit → EURC deposit → swap to USDC → settlement
 */
contract PoolSettlementVault is Ownable, ReentrancyGuard {
    
    // ============ Events ============
    
    event VaultCreated(
        bytes32 indexed vaultId,
        address indexed client,
        address indexed seller,
        address assetToken,
        uint256 assetAmount,
        uint256 requiredUSDC,
        uint256 deadline
    );
    
    event AssetDeposited(
        bytes32 indexed vaultId,
        address indexed seller,
        address assetToken,
        uint256 amount
    );
    
    event EURCDeposited(
        bytes32 indexed vaultId,
        address indexed client,
        uint256 amount
    );
    
    event USDCReceived(
        bytes32 indexed vaultId,
        uint256 amount
    );
    
    event VaultOpened(
        bytes32 indexed vaultId,
        address indexed client,
        address indexed seller
    );
    
    event VaultSettled(
        bytes32 indexed vaultId,
        uint256 usdcToSeller,
        uint256 eurcRefundToSeller,
        uint256 assetToClient
    );
    
    event VaultTimedOut(
        bytes32 indexed vaultId
    );
    
    event VaultReversed(
        bytes32 indexed vaultId,
        uint256 assetReturned,
        uint256 eurcReturned
    );
    
    event PoolManagerSet(address indexed poolManager);
    event FacilitatorSet(address indexed facilitator);

    // ============ Structs ============
    
    enum VaultStatus {
        None,
        Created,
        AssetDeposited,
        EURCDeposited,
        USDCReceived,
        Opened,
        TimedOut,
        Reversed
    }
    
    struct Vault {
        address client;
        address seller;
        address assetToken;
        uint256 assetAmount;
        address eurcToken;
        uint256 eurcDeposited;
        address usdcToken;
        uint256 requiredUSDC;
        uint256 usdcReceived;
        uint256 deadline;
        VaultStatus status;
        uint256 createdAt;
    }

    // ============ State Variables ============
    
    /// @notice Mapping of vault IDs to Vault structs
    mapping(bytes32 => Vault) public vaults;
    
    /// @notice Uniswap v4 PoolManager address
    address public poolManager;
    
    /// @notice Authorized facilitator contract
    address public facilitator;
    
    /// @notice Timeout period (e.g., 24 hours)
    uint256 public constant TIMEOUT_PERIOD = 24 hours;

    // ============ Errors ============
    
    error VaultAlreadyExists();
    error VaultNotFound();
    error InvalidStatus(VaultStatus current, VaultStatus required);
    error InvalidAmount();
    error InvalidAddress();
    error TransferFailed();
    error NotTimedOut();
    error Unauthorized();
    error DeadlinePassed();

    // ============ Constructor ============
    
    /**
     * @notice Initialize the PoolSettlementVault
     * @param initialOwner Owner address
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    // ============ Configuration ============
    
    /**
     * @notice Set the PoolManager address
     * @param _poolManager Address of Uniswap v4 PoolManager
     */
    function setPoolManager(address _poolManager) external onlyOwner {
        if (_poolManager == address(0)) revert InvalidAddress();
        poolManager = _poolManager;
        emit PoolManagerSet(_poolManager);
    }
    
    /**
     * @notice Set the facilitator address
     * @param _facilitator Address of facilitator contract
     */
    function setFacilitator(address _facilitator) external onlyOwner {
        if (_facilitator == address(0)) revert InvalidAddress();
        facilitator = _facilitator;
        emit FacilitatorSet(_facilitator);
    }

    // ============ Core Functions ============
    
    /**
     * @notice Create a new vault
     * @param vaultId Unique vault identifier
     * @param client Client address (asset recipient)
     * @param seller Seller address (USDC recipient)
     * @param assetToken Token being sold
     * @param assetAmount Amount of asset
     * @param eurcToken MockEURC address
     * @param usdcToken MockUSDC address
     * @param requiredUSDC Required USDC amount for settlement
     * @param deadline Deadline timestamp
     */
    function createVault(
        bytes32 vaultId,
        address client,
        address seller,
        address assetToken,
        uint256 assetAmount,
        address eurcToken,
        address usdcToken,
        uint256 requiredUSDC,
        uint256 deadline
    ) external onlyOwner {
        if (vaults[vaultId].status != VaultStatus.None) revert VaultAlreadyExists();
        if (client == address(0) || seller == address(0)) revert InvalidAddress();
        if (assetAmount == 0 || requiredUSDC == 0) revert InvalidAmount();
        if (deadline <= block.timestamp) revert DeadlinePassed();
        
        vaults[vaultId] = Vault({
            client: client,
            seller: seller,
            assetToken: assetToken,
            assetAmount: assetAmount,
            eurcToken: eurcToken,
            eurcDeposited: 0,
            usdcToken: usdcToken,
            requiredUSDC: requiredUSDC,
            usdcReceived: 0,
            deadline: deadline,
            status: VaultStatus.Created,
            createdAt: block.timestamp
        });
        
        emit VaultCreated(vaultId, client, seller, assetToken, assetAmount, requiredUSDC, deadline);
    }
    
    /**
     * @notice Deposit asset into vault (must be first)
     * @param vaultId Vault identifier
     */
    function depositAsset(bytes32 vaultId) external nonReentrant {
        Vault storage vault = vaults[vaultId];
        if (vault.status == VaultStatus.None) revert VaultNotFound();
        if (vault.status != VaultStatus.Created) {
            revert InvalidStatus(vault.status, VaultStatus.Created);
        }
        if (msg.sender != vault.seller) revert Unauthorized();
        if (block.timestamp > vault.deadline) revert DeadlinePassed();
        
        // Transfer asset from seller to vault
        if (!IERC20(vault.assetToken).transferFrom(msg.sender, address(this), vault.assetAmount)) {
            revert TransferFailed();
        }
        
        vault.status = VaultStatus.AssetDeposited;
        emit AssetDeposited(vaultId, msg.sender, vault.assetToken, vault.assetAmount);
    }
    
    /**
     * @notice Deposit EURC into vault (after asset deposited)
     * @param vaultId Vault identifier
     * @param amount Amount of EURC to deposit
     */
    function depositEURC(bytes32 vaultId, uint256 amount) external nonReentrant {
        Vault storage vault = vaults[vaultId];
        if (vault.status != VaultStatus.AssetDeposited) {
            revert InvalidStatus(vault.status, VaultStatus.AssetDeposited);
        }
        if (msg.sender != vault.client) revert Unauthorized();
        if (amount == 0) revert InvalidAmount();
        if (block.timestamp > vault.deadline) revert DeadlinePassed();
        
        // Transfer EURC from client to vault
        if (!IERC20(vault.eurcToken).transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }
        
        vault.eurcDeposited += amount;
        vault.status = VaultStatus.EURCDeposited;
        emit EURCDeposited(vaultId, msg.sender, amount);
    }
    
    /**
     * @notice Allow PoolManager to withdraw EURC for swap (called by facilitator)
     * @param vaultId Vault identifier
     * @param amount Amount to withdraw
     */
    function withdrawEURCForSwap(bytes32 vaultId, uint256 amount) external nonReentrant {
        if (msg.sender != facilitator && msg.sender != poolManager) revert Unauthorized();
        
        Vault storage vault = vaults[vaultId];
        if (vault.status != VaultStatus.EURCDeposited) {
            revert InvalidStatus(vault.status, VaultStatus.EURCDeposited);
        }
        if (amount > vault.eurcDeposited) revert InvalidAmount();
        
        // Transfer EURC to PoolManager
        if (!IERC20(vault.eurcToken).transfer(msg.sender, amount)) {
            revert TransferFailed();
        }
    }
    
    /**
     * @notice Record USDC received from swap
     * @param vaultId Vault identifier
     * @param amount Amount of USDC received
     */
    function recordUSDCReceived(bytes32 vaultId, uint256 amount) external {
        if (msg.sender != facilitator && msg.sender != owner()) revert Unauthorized();
        
        Vault storage vault = vaults[vaultId];
        if (vault.status != VaultStatus.EURCDeposited) {
            revert InvalidStatus(vault.status, VaultStatus.EURCDeposited);
        }
        
        vault.usdcReceived += amount;
        
        // Check if we have enough USDC
        if (vault.usdcReceived >= vault.requiredUSDC) {
            vault.status = VaultStatus.USDCReceived;
        }
        
        emit USDCReceived(vaultId, amount);
    }
    
    /**
     * @notice Open vault and settle (once USDC requirement met)
     * @param vaultId Vault identifier
     */
    function openVault(bytes32 vaultId) external nonReentrant {
        Vault storage vault = vaults[vaultId];
        if (vault.status != VaultStatus.USDCReceived) {
            revert InvalidStatus(vault.status, VaultStatus.USDCReceived);
        }
        if (vault.usdcReceived < vault.requiredUSDC) revert InvalidAmount();
        
        vault.status = VaultStatus.Opened;
        emit VaultOpened(vaultId, vault.client, vault.seller);
        
        // Transfer asset to client
        if (!IERC20(vault.assetToken).transfer(vault.client, vault.assetAmount)) {
            revert TransferFailed();
        }
        
        // Transfer USDC to seller
        if (!IERC20(vault.usdcToken).transfer(vault.seller, vault.requiredUSDC)) {
            revert TransferFailed();
        }
        
        // Return any residual EURC to seller
        uint256 residualEURC = IERC20(vault.eurcToken).balanceOf(address(this));
        if (residualEURC > 0) {
            if (!IERC20(vault.eurcToken).transfer(vault.seller, residualEURC)) {
                revert TransferFailed();
            }
        }
        
        emit VaultSettled(vaultId, vault.requiredUSDC, residualEURC, vault.assetAmount);
    }
    
    /**
     * @notice Timeout and reverse vault (if deadline passed)
     * @param vaultId Vault identifier
     */
    function timeoutVault(bytes32 vaultId) external nonReentrant {
        Vault storage vault = vaults[vaultId];
        if (vault.status == VaultStatus.None || vault.status == VaultStatus.Opened) {
            revert VaultNotFound();
        }
        if (block.timestamp <= vault.deadline) revert NotTimedOut();
        
        vault.status = VaultStatus.TimedOut;
        emit VaultTimedOut(vaultId);
        
        // Return asset to seller if deposited
        if (vault.assetAmount > 0) {
            uint256 assetBalance = IERC20(vault.assetToken).balanceOf(address(this));
            if (assetBalance >= vault.assetAmount) {
                if (!IERC20(vault.assetToken).transfer(vault.seller, vault.assetAmount)) {
                    revert TransferFailed();
                }
            }
        }
        
        // Return EURC to client if deposited
        if (vault.eurcDeposited > 0) {
            uint256 eurcBalance = IERC20(vault.eurcToken).balanceOf(address(this));
            if (eurcBalance > 0) {
                if (!IERC20(vault.eurcToken).transfer(vault.client, eurcBalance)) {
                    revert TransferFailed();
                }
            }
        }
        
        vault.status = VaultStatus.Reversed;
        emit VaultReversed(vaultId, vault.assetAmount, vault.eurcDeposited);
    }

    // ============ View Functions ============
    
    /**
     * @notice Get vault details
     * @param vaultId Vault identifier
     * @return Vault struct
     */
    function getVault(bytes32 vaultId) external view returns (Vault memory) {
        return vaults[vaultId];
    }
    
    /**
     * @notice Check if vault can be opened
     * @param vaultId Vault identifier
     * @return bool indicating if vault can be opened
     */
    function canOpenVault(bytes32 vaultId) external view returns (bool) {
        Vault storage vault = vaults[vaultId];
        return vault.status == VaultStatus.USDCReceived && vault.usdcReceived >= vault.requiredUSDC;
    }
    
    /**
     * @notice Check if vault can be timed out
     * @param vaultId Vault identifier
     * @return bool indicating if vault can be timed out
     */
    function canTimeoutVault(bytes32 vaultId) external view returns (bool) {
        Vault storage vault = vaults[vaultId];
        return block.timestamp > vault.deadline && 
               vault.status != VaultStatus.None && 
               vault.status != VaultStatus.Opened;
    }

    // ============ Emergency Functions ============
    
    /**
     * @notice Emergency withdraw (owner only)
     * @param token Token to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (!IERC20(token).transfer(owner(), amount)) revert TransferFailed();
    }
}

