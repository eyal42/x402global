// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./SettlementVault.sol";

/**
 * @title FacilitatorHook
 * @notice Uniswap V4 hook that facilitates MockEURC -> MockUSDC conversion with validation
 * @dev This hook ensures swap output meets minimum requirements and handles vault integration
 * 
 * Note: This is a simplified hook implementation for the OTC system.
 * In production, this would implement IHooks interface from Uniswap V4 and integrate with PoolManager.
 */
contract FacilitatorHook is Ownable {
    using SafeERC20 for IERC20;
    
    // ============ State Variables ============
    
    /// @notice Settlement vault
    SettlementVault public immutable vault;
    
    /// @notice MockEURC token
    IERC20 public immutable mockEURC;
    
    /// @notice MockUSDC token
    IERC20 public immutable mockUSDC;
    
    /// @notice Uniswap V4 PoolManager address (to be set)
    address public poolManager;
    
    /// @notice Swap router address
    address public swapRouter;
    
    /// @notice Active swap context for validation
    mapping(bytes32 => SwapContext) public activeSwaps;
    
    // ============ Structs ============
    
    struct SwapContext {
        bytes32 settlementId;
        uint256 minUSDCOut;      // Minimum USDC required
        uint256 maxEURCIn;       // Maximum EURC to spend
        address initiator;       // Who initiated the swap
        bool active;             // Is this swap active
    }
    
    // ============ Events ============
    
    event SwapRequested(
        bytes32 indexed settlementId,
        bytes32 indexed swapId,
        uint256 maxEURCIn,
        uint256 minUSDCOut
    );
    
    event SwapValidated(
        bytes32 indexed swapId,
        uint256 eurcSpent,
        uint256 usdcReceived,
        bool success
    );
    
    event SwapCompleted(
        bytes32 indexed settlementId,
        uint256 eurcSpent,
        uint256 usdcReceived,
        uint256 residualEURC
    );
    
    event SwapFailed(
        bytes32 indexed settlementId,
        string reason
    );
    
    event PoolManagerUpdated(address indexed oldManager, address indexed newManager);
    event SwapRouterUpdated(address indexed oldRouter, address indexed newRouter);
    
    // ============ Errors ============
    
    error Unauthorized();
    error InvalidSwap();
    error InsufficientOutput();
    error SwapNotActive();
    error ZeroAddress();
    
    // ============ Modifiers ============
    
    modifier onlyAuthorized() {
        if (msg.sender != owner() && msg.sender != address(vault)) revert Unauthorized();
        _;
    }
    
    // ============ Constructor ============
    
    constructor(
        address _vault,
        address _mockEURC,
        address _mockUSDC,
        address initialOwner
    ) Ownable(initialOwner) {
        if (_vault == address(0) || _mockEURC == address(0) || _mockUSDC == address(0)) {
            revert ZeroAddress();
        }
        
        vault = SettlementVault(_vault);
        mockEURC = IERC20(_mockEURC);
        mockUSDC = IERC20(_mockUSDC);
    }
    
    // ============ Public Functions ============
    
    /**
     * @notice Set PoolManager address
     * @param _poolManager PoolManager address
     */
    function setPoolManager(address _poolManager) external onlyOwner {
        if (_poolManager == address(0)) revert ZeroAddress();
        address oldManager = poolManager;
        poolManager = _poolManager;
        emit PoolManagerUpdated(oldManager, _poolManager);
    }
    
    /**
     * @notice Set swap router address
     * @param _swapRouter Swap router address
     */
    function setSwapRouter(address _swapRouter) external onlyOwner {
        if (_swapRouter == address(0)) revert ZeroAddress();
        address oldRouter = swapRouter;
        swapRouter = _swapRouter;
        emit SwapRouterUpdated(oldRouter, _swapRouter);
    }
    
    /**
     * @notice Execute a swap from MockEURC to MockUSDC for a settlement
     * @param settlementId Settlement identifier
     * @param maxEURCIn Maximum MockEURC to spend
     * @param minUSDCOut Minimum MockUSDC required
     * @return swapId Unique swap identifier
     */
    function initiateSwap(
        bytes32 settlementId,
        uint256 maxEURCIn,
        uint256 minUSDCOut
    ) external onlyAuthorized returns (bytes32 swapId) {
        swapId = keccak256(abi.encodePacked(
            settlementId,
            maxEURCIn,
            minUSDCOut,
            block.timestamp
        ));
        
        activeSwaps[swapId] = SwapContext({
            settlementId: settlementId,
            minUSDCOut: minUSDCOut,
            maxEURCIn: maxEURCIn,
            initiator: msg.sender,
            active: true
        });
        
        emit SwapRequested(settlementId, swapId, maxEURCIn, minUSDCOut);
    }
    
    /**
     * @notice Execute swap via Uniswap V4 (simplified for demo)
     * @param settlementId Settlement identifier
     * @param eurcAmount Amount of MockEURC to swap
     * @param minUSDCOut Minimum MockUSDC to receive
     * @return usdcReceived Amount of MockUSDC received
     */
    function executeSwap(
        bytes32 settlementId,
        uint256 eurcAmount,
        uint256 minUSDCOut
    ) external onlyAuthorized returns (uint256 usdcReceived) {
        // Pull MockEURC from vault
        mockEURC.safeTransferFrom(address(vault), address(this), eurcAmount);
        
        // In a real implementation, this would interact with Uniswap V4 PoolManager
        // For now, we'll use a simplified swap simulation
        usdcReceived = _simulateSwap(eurcAmount, minUSDCOut);
        
        // Validate output
        if (usdcReceived < minUSDCOut) {
            revert InsufficientOutput();
        }
        
        // Return MockUSDC to vault
        mockUSDC.safeTransfer(address(vault), usdcReceived);
        
        // Calculate and return residual MockEURC
        uint256 residualEURC = mockEURC.balanceOf(address(this));
        if (residualEURC > 0) {
            mockEURC.safeTransfer(address(vault), residualEURC);
        }
        
        // Update vault with swap results
        vault.recordSwapCompleted(settlementId, eurcAmount - residualEURC, usdcReceived);
        
        emit SwapCompleted(settlementId, eurcAmount - residualEURC, usdcReceived, residualEURC);
    }
    
    /**
     * @notice Validate swap output (called in hook)
     * @param swapId Swap identifier
     * @param eurcSpent Amount of MockEURC spent
     * @param usdcReceived Amount of MockUSDC received
     * @return valid Whether the swap meets requirements
     */
    function validateSwap(
        bytes32 swapId,
        uint256 eurcSpent,
        uint256 usdcReceived
    ) external onlyAuthorized returns (bool valid) {
        SwapContext storage ctx = activeSwaps[swapId];
        if (!ctx.active) revert SwapNotActive();
        
        valid = (usdcReceived >= ctx.minUSDCOut) && (eurcSpent <= ctx.maxEURCIn);
        
        ctx.active = false;
        
        emit SwapValidated(swapId, eurcSpent, usdcReceived, valid);
        
        if (!valid) {
            revert InsufficientOutput();
        }
    }
    
    // ============ Internal Functions ============
    
    /**
     * @notice Simulate swap (placeholder for actual Uniswap V4 integration)
     * @param eurcAmount Amount of MockEURC to swap
     * @param minUSDCOut Minimum MockUSDC required
     * @return usdcReceived Amount of MockUSDC received
     * 
     * @dev In production, this would call Uniswap V4 PoolManager.swap()
     *      For demo purposes, we use a simple exchange rate simulation
     */
    function _simulateSwap(
        uint256 eurcAmount,
        uint256 minUSDCOut
    ) internal pure returns (uint256 usdcReceived) {
        // Simulate EUR/USD exchange rate (~1.10 EUR/USD)
        // MockEURC has 6 decimals, MockUSDC has 6 decimals
        // 1 EUR = ~1.10 USD
        usdcReceived = (eurcAmount * 110) / 100;
        
        // Simulate 0.3% swap fee
        usdcReceived = (usdcReceived * 997) / 1000;
        
        // For testing, ensure we meet minimum output
        if (usdcReceived < minUSDCOut) {
            revert InsufficientOutput();
        }
        
        // In real implementation, MockUSDC would come from the pool
        // For demo, we assume this contract has been provided MockUSDC for testing
    }
    
    /**
     * @notice Emergency function to return tokens to vault
     * @param token Token address
     * @param amount Amount to return
     */
    function returnToVault(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(address(vault), amount);
    }
}

