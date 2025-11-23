// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SettlementVault
 * @notice Escrows funds and assets during OTC settlement process
 * @dev Holds MockEURC, MockUSDC, and asset tokens during the swap and finality waiting period
 */
contract SettlementVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ============ Structs ============
    
    struct Settlement {
        address client;              // Buyer address
        address seller;              // Seller address
        address assetToken;          // Asset being sold
        uint256 assetAmount;         // Amount of asset
        uint256 requiredUSDC;        // Required MockUSDC amount
        uint256 maxEURC;             // Maximum MockEURC client will pay
        uint256 actualEURC;          // Actual MockEURC pulled from client
        uint256 actualUSDC;          // Actual MockUSDC obtained from swap
        uint256 residualEURC;        // Leftover MockEURC to refund
        uint256 blockNumber;         // Block where vault was funded
        bytes32 txHash;              // Transaction hash of funding
        SettlementState state;       // Current state
        uint256 timestamp;           // Settlement creation timestamp
    }
    
    enum SettlementState {
        None,           // Settlement doesn't exist
        Pending,        // Funds/assets deposited, awaiting swap
        Funded,         // Swap complete, vault has required USDC, awaiting finality
        Finalized,      // Finality confirmed, ready to settle
        Settled,        // Assets/funds distributed to parties
        Cancelled       // Settlement was cancelled
    }
    
    // ============ State Variables ============
    
    /// @notice MockEURC token (payment from client)
    IERC20 public immutable mockEURC;
    
    /// @notice MockUSDC token (final settlement to seller)
    IERC20 public immutable mockUSDC;
    
    /// @notice Address authorized to execute settlements (facilitator)
    address public facilitator;
    
    /// @notice Mapping of settlement ID to settlement data
    mapping(bytes32 => Settlement) public settlements;
    
    /// @notice Counter for generating settlement IDs
    uint256 public settlementNonce;
    
    // ============ Events ============
    
    event SettlementCreated(
        bytes32 indexed settlementId,
        address indexed client,
        address indexed seller,
        address assetToken,
        uint256 assetAmount,
        uint256 requiredUSDC,
        uint256 maxEURC
    );
    
    event FundsPulled(
        bytes32 indexed settlementId,
        uint256 eurcAmount,
        uint256 assetAmount
    );
    
    event SwapCompleted(
        bytes32 indexed settlementId,
        uint256 eurcSwapped,
        uint256 usdcReceived,
        uint256 residualEURC
    );
    
    event VaultFunded(
        bytes32 indexed settlementId,
        address indexed client,
        uint256 assetAmount,
        uint256 usdcAmount,
        uint256 blockNumber,
        bytes32 txHash
    );
    
    event FinalityConfirmed(
        bytes32 indexed settlementId,
        uint256 confirmedBlock
    );
    
    event SettlementExecuted(
        bytes32 indexed settlementId,
        address indexed client,
        address indexed seller,
        uint256 assetAmount,
        uint256 usdcAmount,
        uint256 refundedEURC
    );
    
    event SettlementCancelled(
        bytes32 indexed settlementId,
        string reason
    );
    
    event FacilitatorUpdated(address indexed oldFacilitator, address indexed newFacilitator);
    
    // ============ Errors ============
    
    error Unauthorized();
    error InvalidSettlement();
    error InvalidState();
    error InsufficientFunds();
    error ZeroAddress();
    error ZeroAmount();
    
    // ============ Modifiers ============
    
    modifier onlyFacilitator() {
        if (msg.sender != facilitator) revert Unauthorized();
        _;
    }
    
    // ============ Constructor ============
    
    constructor(
        address _mockEURC,
        address _mockUSDC,
        address _facilitator,
        address initialOwner
    ) Ownable(initialOwner) {
        if (_mockEURC == address(0) || _mockUSDC == address(0)) revert ZeroAddress();
        
        mockEURC = IERC20(_mockEURC);
        mockUSDC = IERC20(_mockUSDC);
        facilitator = _facilitator;
    }
    
    // ============ Public Functions ============
    
    /**
     * @notice Create a new settlement
     * @param client Buyer address
     * @param seller Seller address
     * @param assetToken Token being sold
     * @param assetAmount Amount of asset
     * @param requiredUSDC Required MockUSDC for settlement
     * @param maxEURC Maximum MockEURC client will pay
     * @return settlementId Unique settlement identifier
     */
    function createSettlement(
        address client,
        address seller,
        address assetToken,
        uint256 assetAmount,
        uint256 requiredUSDC,
        uint256 maxEURC
    ) external onlyFacilitator returns (bytes32 settlementId) {
        if (client == address(0) || seller == address(0) || assetToken == address(0)) revert ZeroAddress();
        if (assetAmount == 0 || requiredUSDC == 0 || maxEURC == 0) revert ZeroAmount();
        
        settlementId = keccak256(abi.encodePacked(
            client,
            seller,
            assetToken,
            assetAmount,
            requiredUSDC,
            block.timestamp,
            settlementNonce++
        ));
        
        settlements[settlementId] = Settlement({
            client: client,
            seller: seller,
            assetToken: assetToken,
            assetAmount: assetAmount,
            requiredUSDC: requiredUSDC,
            maxEURC: maxEURC,
            actualEURC: 0,
            actualUSDC: 0,
            residualEURC: 0,
            blockNumber: 0,
            txHash: bytes32(0),
            state: SettlementState.Pending,
            timestamp: block.timestamp
        });
        
        emit SettlementCreated(
            settlementId,
            client,
            seller,
            assetToken,
            assetAmount,
            requiredUSDC,
            maxEURC
        );
    }
    
    /**
     * @notice Record that funds and assets have been pulled into vault
     * @param settlementId Settlement identifier
     * @param eurcAmount Amount of MockEURC pulled
     * @param assetAmount Amount of asset pulled
     */
    function recordFundsPulled(
        bytes32 settlementId,
        uint256 eurcAmount,
        uint256 assetAmount
    ) external onlyFacilitator {
        Settlement storage settlement = settlements[settlementId];
        if (settlement.state != SettlementState.Pending) revert InvalidState();
        
        settlement.actualEURC = eurcAmount;
        
        emit FundsPulled(settlementId, eurcAmount, assetAmount);
    }
    
    /**
     * @notice Record swap completion and mark vault as funded
     * @param settlementId Settlement identifier
     * @param eurcSwapped Amount of MockEURC used in swap
     * @param usdcReceived Amount of MockUSDC received
     */
    function recordSwapCompleted(
        bytes32 settlementId,
        uint256 eurcSwapped,
        uint256 usdcReceived
    ) external onlyFacilitator {
        Settlement storage settlement = settlements[settlementId];
        if (settlement.state != SettlementState.Pending) revert InvalidState();
        if (usdcReceived < settlement.requiredUSDC) revert InsufficientFunds();
        
        settlement.actualUSDC = usdcReceived;
        settlement.residualEURC = settlement.actualEURC - eurcSwapped;
        settlement.blockNumber = block.number;
        settlement.txHash = blockhash(block.number - 1);
        settlement.state = SettlementState.Funded;
        
        emit SwapCompleted(settlementId, eurcSwapped, usdcReceived, settlement.residualEURC);
        emit VaultFunded(
            settlementId,
            settlement.client,
            settlement.assetAmount,
            usdcReceived,
            block.number,
            settlement.txHash
        );
    }
    
    /**
     * @notice Confirm finality and allow settlement execution
     * @param settlementId Settlement identifier
     */
    function confirmFinality(bytes32 settlementId) external onlyFacilitator {
        Settlement storage settlement = settlements[settlementId];
        if (settlement.state != SettlementState.Funded) revert InvalidState();
        
        settlement.state = SettlementState.Finalized;
        
        emit FinalityConfirmed(settlementId, block.number);
    }
    
    /**
     * @notice Execute settlement after finality is confirmed
     * @param settlementId Settlement identifier
     */
    function executeSettlement(bytes32 settlementId) external onlyFacilitator nonReentrant {
        Settlement storage settlement = settlements[settlementId];
        if (settlement.state != SettlementState.Finalized) revert InvalidState();
        
        settlement.state = SettlementState.Settled;
        
        // Transfer MockUSDC to seller
        mockUSDC.safeTransfer(settlement.seller, settlement.actualUSDC);
        
        // Transfer asset to client
        IERC20(settlement.assetToken).safeTransfer(settlement.client, settlement.assetAmount);
        
        // Refund residual MockEURC to client (if any)
        if (settlement.residualEURC > 0) {
            mockEURC.safeTransfer(settlement.client, settlement.residualEURC);
        }
        
        emit SettlementExecuted(
            settlementId,
            settlement.client,
            settlement.seller,
            settlement.assetAmount,
            settlement.actualUSDC,
            settlement.residualEURC
        );
    }
    
    /**
     * @notice Cancel a settlement and refund all parties
     * @param settlementId Settlement identifier
     * @param reason Cancellation reason
     */
    function cancelSettlement(
        bytes32 settlementId,
        string calldata reason
    ) external onlyFacilitator nonReentrant {
        Settlement storage settlement = settlements[settlementId];
        if (settlement.state == SettlementState.Settled || 
            settlement.state == SettlementState.None) revert InvalidState();
        
        settlement.state = SettlementState.Cancelled;
        
        // Refund any MockEURC
        uint256 eurcBalance = settlement.actualEURC;
        if (eurcBalance > 0) {
            mockEURC.safeTransfer(settlement.client, eurcBalance);
        }
        
        // Refund any MockUSDC
        uint256 usdcBalance = settlement.actualUSDC;
        if (usdcBalance > 0) {
            mockUSDC.safeTransfer(settlement.client, usdcBalance);
        }
        
        // Return asset to seller
        uint256 assetBalance = IERC20(settlement.assetToken).balanceOf(address(this));
        if (assetBalance >= settlement.assetAmount) {
            IERC20(settlement.assetToken).safeTransfer(settlement.seller, settlement.assetAmount);
        }
        
        emit SettlementCancelled(settlementId, reason);
    }
    
    /**
     * @notice Update facilitator address
     * @param newFacilitator New facilitator address
     */
    function setFacilitator(address newFacilitator) external onlyOwner {
        if (newFacilitator == address(0)) revert ZeroAddress();
        address oldFacilitator = facilitator;
        facilitator = newFacilitator;
        emit FacilitatorUpdated(oldFacilitator, newFacilitator);
    }
    
    /**
     * @notice Get settlement details
     * @param settlementId Settlement identifier
     * @return settlement Settlement data
     */
    function getSettlement(bytes32 settlementId) external view returns (Settlement memory) {
        return settlements[settlementId];
    }
}

