// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/types/Currency.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {SwapParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {PoolSwapTest} from "@uniswap/v4-core/test/PoolSwapTest.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Facilitator
 * @notice Orchestrates swaps against Uniswap v4 pool for vault settlement
 * @dev Interfaces with PoolManager, Hook, and Vault contracts
 */
contract Facilitator is Ownable, ReentrancyGuard {
    using CurrencyLibrary for Currency;

    // ============ Events ============
    
    event FacilitatedSwapRequested(
        bytes32 indexed vaultId,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    );
    
    event FacilitatedSwapCompleted(
        bytes32 indexed vaultId,
        uint256 amountIn,
        uint256 amountOut,
        int256 amount0Delta,
        int256 amount1Delta
    );
    
    event PoolKeySet(
        address currency0,
        address currency1,
        uint24 fee,
        int24 tickSpacing,
        address hooks
    );
    
    event VaultSet(address indexed vault);

    // ============ Errors ============
    
    error InvalidPoolManager();
    error InvalidVault();
    error InvalidAmount();
    error SlippageTooHigh();
    error SwapFailed();
    error TransferFailed();
    error PoolKeyNotSet();

    // ============ State Variables ============
    
    /// @notice Uniswap v4 PoolManager
    IPoolManager public immutable poolManager;
    
    /// @notice PoolSwapTest router for executing swaps
    PoolSwapTest public swapRouter;
    
    /// @notice The vault contract
    address public vault;
    
    /// @notice Pool key for EURC/USDC pool
    PoolKey public poolKey;
    
    /// @notice Whether pool key is set
    bool public poolKeySet;

    // ============ Constructor ============
    
    /**
     * @notice Deploy Facilitator
     * @param _poolManager Address of Uniswap v4 PoolManager
     * @param _swapRouter Address of PoolSwapTest router
     * @param initialOwner Initial owner address
     */
    constructor(
        address _poolManager,
        address _swapRouter,
        address initialOwner
    ) Ownable(initialOwner) {
        if (_poolManager == address(0)) revert InvalidPoolManager();
        poolManager = IPoolManager(_poolManager);
        swapRouter = PoolSwapTest(_swapRouter);
    }

    // ============ Configuration ============
    
    /**
     * @notice Set the vault address
     * @param _vault Vault contract address
     */
    function setVault(address _vault) external onlyOwner {
        if (_vault == address(0)) revert InvalidVault();
        vault = _vault;
        emit VaultSet(_vault);
    }
    
    /**
     * @notice Set the pool key for EURC/USDC pool
     * @param _currency0 Currency 0 (lower address)
     * @param _currency1 Currency 1 (higher address)
     * @param _fee Fee tier
     * @param _tickSpacing Tick spacing
     * @param _hooks Hook contract address
     */
    function setPoolKey(
        Currency _currency0,
        Currency _currency1,
        uint24 _fee,
        int24 _tickSpacing,
        address _hooks
    ) external onlyOwner {
        poolKey = PoolKey({
            currency0: _currency0,
            currency1: _currency1,
            fee: _fee,
            tickSpacing: _tickSpacing,
            hooks: IHooks(_hooks)
        });
        poolKeySet = true;
        
        emit PoolKeySet(
            Currency.unwrap(_currency0),
            Currency.unwrap(_currency1),
            _fee,
            _tickSpacing,
            _hooks
        );
    }

    // ============ Core Functions ============
    
    /**
     * @notice Execute a facilitated swap for a vault
     * @param vaultId Vault identifier
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Amount of input token
     * @param minAmountOut Minimum output amount (slippage protection)
     * @param zeroForOne Direction of swap (true = token0 -> token1)
     * @return amountOut Amount of output token received
     */
    function facilitatedSwap(
        bytes32 vaultId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        bool zeroForOne
    ) external nonReentrant onlyOwner returns (uint256 amountOut) {
        if (!poolKeySet) revert PoolKeyNotSet();
        if (amountIn == 0) revert InvalidAmount();
        
        emit FacilitatedSwapRequested(vaultId, tokenIn, tokenOut, amountIn, minAmountOut);
        
        // Transfer tokens from vault to this contract
        if (!IERC20(tokenIn).transferFrom(vault, address(this), amountIn)) {
            revert TransferFailed();
        }
        
        // Approve PoolManager/SwapRouter to spend tokens
        if (!IERC20(tokenIn).approve(address(swapRouter), amountIn)) {
            revert TransferFailed();
        }
        
        // Prepare swap params
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn), // Negative = exact input
            sqrtPriceLimitX96: zeroForOne ? 4295128739 : 1461446703485210103287273052203988822378723970342
        });
        
        // Execute swap through PoolSwapTest
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });
        
        BalanceDelta delta = swapRouter.swap(poolKey, params, testSettings, "");
        
        // Calculate output amount
        int128 amount0 = delta.amount0();
        int128 amount1 = delta.amount1();
        
        // Output is the negative value (tokens owed to us)
        int128 outputDelta = zeroForOne ? amount1 : amount0;
        
        if (outputDelta >= 0) revert SwapFailed();
        amountOut = uint256(uint128(-outputDelta));
        
        // Check slippage
        if (amountOut < minAmountOut) revert SlippageTooHigh();
        
        // Transfer output tokens to vault
        if (!IERC20(tokenOut).transfer(vault, amountOut)) {
            revert TransferFailed();
        }
        
        emit FacilitatedSwapCompleted(vaultId, amountIn, amountOut, amount0, amount1);
    }
    
    /**
     * @notice Simpler swap function without vault integration (for testing)
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Amount of input token
     * @param minAmountOut Minimum output amount
     * @param zeroForOne Direction of swap
     * @param recipient Recipient address
     * @return amountOut Amount of output token received
     */
    function simpleSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        bool zeroForOne,
        address recipient
    ) external nonReentrant onlyOwner returns (uint256 amountOut) {
        if (!poolKeySet) revert PoolKeyNotSet();
        if (amountIn == 0) revert InvalidAmount();
        
        // Transfer tokens from sender
        if (!IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn)) {
            revert TransferFailed();
        }
        
        // Approve swap router
        if (!IERC20(tokenIn).approve(address(swapRouter), amountIn)) {
            revert TransferFailed();
        }
        
        // Execute swap
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn),
            sqrtPriceLimitX96: zeroForOne ? 4295128739 : 1461446703485210103287273052203988822378723970342
        });
        
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });
        
        BalanceDelta delta = swapRouter.swap(poolKey, params, testSettings, "");
        
        // Calculate output
        int128 outputDelta = zeroForOne ? delta.amount1() : delta.amount0();
        if (outputDelta >= 0) revert SwapFailed();
        amountOut = uint256(uint128(-outputDelta));
        
        if (amountOut < minAmountOut) revert SlippageTooHigh();
        
        // Transfer to recipient
        if (!IERC20(tokenOut).transfer(recipient, amountOut)) {
            revert TransferFailed();
        }
    }

    // ============ View Functions ============
    
    /**
     * @notice Get the current pool key
     * @return PoolKey struct
     */
    function getPoolKey() external view returns (PoolKey memory) {
        return poolKey;
    }

    // ============ Emergency Functions ============
    
    /**
     * @notice Emergency token recovery
     * @param token Token address
     * @param amount Amount to recover
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (!IERC20(token).transfer(owner(), amount)) revert TransferFailed();
    }
}

