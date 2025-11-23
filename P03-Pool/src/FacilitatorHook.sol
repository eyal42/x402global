// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/types/BeforeSwapDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {Hooks} from "@uniswap/v4-core/libraries/Hooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FacilitatorHook
 * @notice Uniswap v4 hook that enables facilitator-controlled swaps with vault integration
 * @dev Implements beforeSwap and afterSwap hooks to manage liquidity flow from vault
 */
contract FacilitatorHook is IHooks, Ownable {
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;

    // ============ Events ============
    
    event BeforeSwapExecuted(
        address indexed facilitator,
        Currency indexed currency0,
        Currency indexed currency1,
        uint256 amount
    );
    
    event AfterSwapExecuted(
        address indexed facilitator,
        BalanceDelta delta,
        uint256 feeCharged
    );
    
    event FacilitatorFeeCharged(
        address indexed facilitator,
        uint256 fee,
        Currency currency
    );
    
    event VaultSet(address indexed vault);
    event FacilitatorSet(address indexed facilitator, bool authorized);
    event FeeRateSet(uint24 feeRate);

    // ============ Errors ============
    
    error UnauthorizedCaller(address caller);
    error InvalidVault();
    error InvalidFeeRate();
    error TransferFailed();

    // ============ State Variables ============
    
    /// @notice The Uniswap v4 PoolManager
    IPoolManager public immutable poolManager;
    
    /// @notice The vault contract that holds liquidity
    address public vault;
    
    /// @notice Authorized facilitator contracts
    mapping(address => bool) public authorizedFacilitators;
    
    /// @notice Fee rate in basis points (100 = 1%)
    uint24 public facilitatorFeeRate;
    
    /// @notice Maximum fee rate (10% = 1000 basis points)
    uint24 public constant MAX_FEE_RATE = 1000;

    // ============ Constructor ============
    
    /**
     * @notice Deploy the FacilitatorHook
     * @param _poolManager Address of Uniswap v4 PoolManager
     * @param _owner Initial owner address
     */
    constructor(IPoolManager _poolManager, address _owner) Ownable(_owner) {
        poolManager = _poolManager;
        facilitatorFeeRate = 30; // Default 0.3%
    }

    // ============ Configuration Functions ============
    
    /**
     * @notice Set the vault address
     * @param _vault Address of the vault contract
     */
    function setVault(address _vault) external onlyOwner {
        if (_vault == address(0)) revert InvalidVault();
        vault = _vault;
        emit VaultSet(_vault);
    }
    
    /**
     * @notice Authorize or deauthorize a facilitator
     * @param _facilitator Facilitator address
     * @param _authorized Authorization status
     */
    function setFacilitator(address _facilitator, bool _authorized) external onlyOwner {
        authorizedFacilitators[_facilitator] = _authorized;
        emit FacilitatorSet(_facilitator, _authorized);
    }
    
    /**
     * @notice Set the facilitator fee rate
     * @param _feeRate Fee rate in basis points
     */
    function setFeeRate(uint24 _feeRate) external onlyOwner {
        if (_feeRate > MAX_FEE_RATE) revert InvalidFeeRate();
        facilitatorFeeRate = _feeRate;
        emit FeeRateSet(_feeRate);
    }

    // ============ Hook Functions ============
    
    /**
     * @notice Hook called before pool initialization
     */
    function beforeInitialize(address, /* sender */ PoolKey calldata, /* key */ uint160 /* sqrtPriceX96 */)
        external
        pure
        returns (bytes4)
    {
        return IHooks.beforeInitialize.selector;
    }

    /**
     * @notice Hook called after pool initialization
     */
    function afterInitialize(address, /* sender */ PoolKey calldata, /* key */ uint160, /* sqrtPriceX96 */ int24 /* tick */)
        external
        pure
        returns (bytes4)
    {
        return IHooks.afterInitialize.selector;
    }

    /**
     * @notice Hook called before adding liquidity
     */
    function beforeAddLiquidity(
        address, /* sender */
        PoolKey calldata, /* key */
        ModifyLiquidityParams calldata, /* params */
        bytes calldata /* hookData */
    ) external pure returns (bytes4) {
        return IHooks.beforeAddLiquidity.selector;
    }

    /**
     * @notice Hook called after adding liquidity
     */
    function afterAddLiquidity(
        address, /* sender */
        PoolKey calldata, /* key */
        ModifyLiquidityParams calldata, /* params */
        BalanceDelta, /* delta */
        BalanceDelta, /* feeDelta */
        bytes calldata /* hookData */
    ) external pure returns (bytes4, BalanceDelta) {
        return (IHooks.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }

    /**
     * @notice Hook called before removing liquidity
     */
    function beforeRemoveLiquidity(
        address, /* sender */
        PoolKey calldata, /* key */
        ModifyLiquidityParams calldata, /* params */
        bytes calldata /* hookData */
    ) external pure returns (bytes4) {
        return IHooks.beforeRemoveLiquidity.selector;
    }

    /**
     * @notice Hook called after removing liquidity
     */
    function afterRemoveLiquidity(
        address, /* sender */
        PoolKey calldata, /* key */
        ModifyLiquidityParams calldata, /* params */
        BalanceDelta, /* delta */
        BalanceDelta, /* feeDelta */
        bytes calldata /* hookData */
    ) external pure returns (bytes4, BalanceDelta) {
        return (IHooks.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
    }

    /**
     * @notice Hook called before swap - validates facilitator and pulls liquidity from vault
     * @param sender The swap initiator
     * @param key The pool key
     * @param params The swap parameters
     * @param hookData Arbitrary data passed to the hook
     */
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4, BeforeSwapDelta, uint24) {
        // Validate that caller is authorized facilitator
        if (!authorizedFacilitators[sender]) {
            revert UnauthorizedCaller(sender);
        }

        // Emit event for tracking
        emit BeforeSwapExecuted(
            sender,
            key.currency0,
            key.currency1,
            params.amountSpecified < 0 ? uint256(-params.amountSpecified) : uint256(params.amountSpecified)
        );

        // Return selector, no delta modification, and no fee override
        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /**
     * @notice Hook called after swap - charges facilitator fee and manages vault transfers
     * @param sender The swap initiator
     * @param key The pool key
     * @param params The swap parameters
     * @param delta The balance changes from the swap
     * @param hookData Arbitrary data passed to the hook
     */
    function afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4, int128) {
        // Calculate fee on output amount
        int128 amount0 = delta.amount0();
        int128 amount1 = delta.amount1();
        
        // The output amount is negative (owed to trader)
        int128 outputAmount = params.zeroForOne ? amount1 : amount0;
        
        // Calculate fee (only if there's an output)
        uint256 fee = 0;
        if (outputAmount < 0) {
            uint256 absOutput = uint256(uint128(-outputAmount));
            fee = (absOutput * facilitatorFeeRate) / 10000;
            
            // Emit fee event
            Currency feeCurrency = params.zeroForOne ? key.currency1 : key.currency0;
            emit FacilitatorFeeCharged(sender, fee, feeCurrency);
        }

        emit AfterSwapExecuted(sender, delta, fee);

        // Return selector and no unspecified delta
        return (IHooks.afterSwap.selector, 0);
    }

    /**
     * @notice Hook called before donate
     */
    function beforeDonate(
        address, /* sender */
        PoolKey calldata, /* key */
        uint256, /* amount0 */
        uint256, /* amount1 */
        bytes calldata /* hookData */
    ) external pure returns (bytes4) {
        return IHooks.beforeDonate.selector;
    }

    /**
     * @notice Hook called after donate
     */
    function afterDonate(
        address, /* sender */
        PoolKey calldata, /* key */
        uint256, /* amount0 */
        uint256, /* amount1 */
        bytes calldata /* hookData */
    ) external pure returns (bytes4) {
        return IHooks.afterDonate.selector;
    }

    // ============ Helper Functions ============
    
    /**
     * @notice Get hook permissions
     * @return Hooks.Permissions struct with enabled hooks
     */
    function getHookPermissions() external pure returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: true,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: true,
            afterDonate: true,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
}

