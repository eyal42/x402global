// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {FacilitatorHook} from "../src/FacilitatorHook.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {BalanceDelta, toBalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/types/BeforeSwapDelta.sol";
import {SwapParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {Hooks} from "@uniswap/v4-core/libraries/Hooks.sol";

/**
 * @title FacilitatorHookTest
 * @notice Comprehensive tests for the FacilitatorHook contract
 */
contract FacilitatorHookTest is Test {
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;
    
    FacilitatorHook public hook;
    
    address public owner = address(0x1);
    address public poolManager = address(0x2);
    address public vault = address(0x3);
    address public facilitator = address(0x4);
    address public unauthorizedCaller = address(0x5);
    
    address public token0 = address(0x10);
    address public token1 = address(0x11);
    
    PoolKey public poolKey;
    
    function setUp() public {
        // Deploy hook
        vm.prank(owner);
        hook = new FacilitatorHook(IPoolManager(poolManager), owner);
        
        // Configure hook
        vm.startPrank(owner);
        hook.setVault(vault);
        hook.setFacilitator(facilitator, true);
        hook.setFeeRate(30); // 0.3%
        vm.stopPrank();
        
        // Set up pool key
        poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
    }
    
    // ============ Configuration Tests ============
    
    function test_InitialConfiguration() public view {
        assertEq(address(hook.poolManager()), poolManager);
        assertEq(hook.vault(), vault);
        assertEq(hook.authorizedFacilitators(facilitator), true);
        assertEq(hook.facilitatorFeeRate(), 30);
        assertEq(hook.owner(), owner);
    }
    
    function test_SetVault() public {
        address newVault = address(0x100);
        
        vm.prank(owner);
        hook.setVault(newVault);
        
        assertEq(hook.vault(), newVault);
    }
    
    function test_SetVault_RevertInvalidAddress() public {
        vm.prank(owner);
        vm.expectRevert(FacilitatorHook.InvalidVault.selector);
        hook.setVault(address(0));
    }
    
    function test_SetVault_RevertUnauthorized() public {
        vm.prank(unauthorizedCaller);
        vm.expectRevert();
        hook.setVault(address(0x100));
    }
    
    function test_SetFacilitator() public {
        address newFacilitator = address(0x200);
        
        vm.prank(owner);
        hook.setFacilitator(newFacilitator, true);
        
        assertEq(hook.authorizedFacilitators(newFacilitator), true);
        
        vm.prank(owner);
        hook.setFacilitator(newFacilitator, false);
        
        assertEq(hook.authorizedFacilitators(newFacilitator), false);
    }
    
    function test_SetFeeRate() public {
        vm.prank(owner);
        hook.setFeeRate(100); // 1%
        
        assertEq(hook.facilitatorFeeRate(), 100);
    }
    
    function test_SetFeeRate_RevertExceedsMax() public {
        vm.prank(owner);
        vm.expectRevert(FacilitatorHook.InvalidFeeRate.selector);
        hook.setFeeRate(1001); // > 10%
    }
    
    // ============ Hook Permission Tests ============
    
    function test_GetHookPermissions() public view {
        Hooks.Permissions memory perms = hook.getHookPermissions();
        
        assertTrue(perms.beforeInitialize);
        assertTrue(perms.afterInitialize);
        assertTrue(perms.beforeAddLiquidity);
        assertFalse(perms.afterAddLiquidity);
        assertTrue(perms.beforeRemoveLiquidity);
        assertFalse(perms.afterRemoveLiquidity);
        assertTrue(perms.beforeSwap);
        assertTrue(perms.afterSwap);
        assertTrue(perms.beforeDonate);
        assertTrue(perms.afterDonate);
        assertFalse(perms.beforeSwapReturnDelta);
        assertFalse(perms.afterSwapReturnDelta);
    }
    
    // ============ BeforeSwap Tests ============
    
    function test_BeforeSwap_AuthorizedFacilitator() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1000,
            sqrtPriceLimitX96: 0
        });
        
        vm.prank(facilitator);
        (bytes4 selector, BeforeSwapDelta delta, uint24 fee) = hook.beforeSwap(
            facilitator,
            poolKey,
            params,
            ""
        );
        
        assertEq(selector, IHooks.beforeSwap.selector);
        assertEq(BeforeSwapDelta.unwrap(delta), BeforeSwapDelta.unwrap(BeforeSwapDeltaLibrary.ZERO_DELTA));
        assertEq(fee, 0);
    }
    
    function test_BeforeSwap_RevertUnauthorized() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1000,
            sqrtPriceLimitX96: 0
        });
        
        vm.prank(unauthorizedCaller);
        vm.expectRevert(abi.encodeWithSelector(FacilitatorHook.UnauthorizedCaller.selector, unauthorizedCaller));
        hook.beforeSwap(unauthorizedCaller, poolKey, params, "");
    }
    
    // ============ AfterSwap Tests ============
    
    function test_AfterSwap_CalculatesFee() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1000,
            sqrtPriceLimitX96: 0
        });
        
        // Create a balance delta representing a swap
        // Input: 1000 token0, Output: -950 token1 (negative = owed to trader)
        BalanceDelta delta = toBalanceDelta(1000, -950);
        
        vm.prank(facilitator);
        (bytes4 selector, int128 unspecifiedDelta) = hook.afterSwap(
            facilitator,
            poolKey,
            params,
            delta,
            ""
        );
        
        assertEq(selector, IHooks.afterSwap.selector);
        assertEq(unspecifiedDelta, 0);
    }
    
    function test_AfterSwap_ReverseDirection() public {
        SwapParams memory params = SwapParams({
            zeroForOne: false,
            amountSpecified: -1000,
            sqrtPriceLimitX96: 0
        });
        
        // Reverse swap: Input: 1000 token1, Output: -950 token0
        BalanceDelta delta = toBalanceDelta(-950, 1000);
        
        vm.prank(facilitator);
        (bytes4 selector, int128 unspecifiedDelta) = hook.afterSwap(
            facilitator,
            poolKey,
            params,
            delta,
            ""
        );
        
        assertEq(selector, IHooks.afterSwap.selector);
        assertEq(unspecifiedDelta, 0);
    }
    
    // ============ Other Hook Tests ============
    
    function test_BeforeInitialize() public view {
        bytes4 selector = hook.beforeInitialize(address(0), poolKey, 0);
        assertEq(selector, IHooks.beforeInitialize.selector);
    }
    
    function test_AfterInitialize() public view {
        bytes4 selector = hook.afterInitialize(address(0), poolKey, 0, 0);
        assertEq(selector, IHooks.afterInitialize.selector);
    }
    
    function test_BeforeAddLiquidity() public {
        bytes4 selector = hook.beforeAddLiquidity(
            address(0),
            poolKey,
            ModifyLiquidityParams({tickLower: 0, tickUpper: 0, liquidityDelta: 0, salt: bytes32(0)}),
            ""
        );
        assertEq(selector, IHooks.beforeAddLiquidity.selector);
    }
    
    function test_BeforeDonate() public view {
        bytes4 selector = hook.beforeDonate(address(0), poolKey, 0, 0, "");
        assertEq(selector, IHooks.beforeDonate.selector);
    }
    
    function test_AfterDonate() public view {
        bytes4 selector = hook.afterDonate(address(0), poolKey, 0, 0, "");
        assertEq(selector, IHooks.afterDonate.selector);
    }
}

// Helper to import ModifyLiquidityParams
import {ModifyLiquidityParams} from "@uniswap/v4-core/types/PoolOperation.sol";

