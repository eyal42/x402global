// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../../src/MockUSDC.sol";

/**
 * @title TokenHandler
 * @notice Handler contract for invariant testing with fuzzing
 */
contract TokenHandler is Test {
    MockUSDC public token;
    address public admin;
    address public minter;
    address public masterMinter;
    
    address[] public actors;
    address internal currentActor;
    
    // Call counters for reporting
    uint256 public ghost_mintSum;
    uint256 public ghost_burnSum;
    uint256 public ghost_transferSum;
    uint256 public ghost_mintCalls;
    uint256 public ghost_burnCalls;
    uint256 public ghost_transferCalls;
    
    constructor(MockUSDC _token, address _admin, address _minter, address _masterMinter) {
        token = _token;
        admin = _admin;
        minter = _minter;
        masterMinter = _masterMinter;
        
        // Create test actors
        actors.push(address(0x1111));
        actors.push(address(0x2222));
        actors.push(address(0x3333));
        actors.push(address(0x4444));
        actors.push(address(0x5555));
    }
    
    function actorsLength() external view returns (uint256) {
        return actors.length;
    }
    
    modifier useActor(uint256 actorIndexSeed) {
        currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }
    
    function mint(uint256 actorIndexSeed, uint256 amount) public useActor(actorIndexSeed) {
        amount = bound(amount, 0, 1_000_000e6);
        
        vm.stopPrank();
        vm.startPrank(minter);
        
        try token.mint(currentActor, amount) {
            ghost_mintSum += amount;
            ghost_mintCalls++;
        } catch {
            // Mint can fail if insufficient allowance
        }
        
        vm.stopPrank();
    }
    
    function burn(uint256 actorIndexSeed, uint256 amount) public useActor(actorIndexSeed) {
        amount = bound(amount, 0, token.balanceOf(currentActor));
        
        if (amount == 0) return;
        
        try token.burn(amount) {
            ghost_burnSum += amount;
            ghost_burnCalls++;
        } catch {
            // Burn can fail if insufficient balance
        }
    }
    
    function transfer(
        uint256 actorIndexSeed,
        uint256 toActorIndexSeed,
        uint256 amount
    ) public useActor(actorIndexSeed) {
        address to = actors[bound(toActorIndexSeed, 0, actors.length - 1)];
        amount = bound(amount, 0, token.balanceOf(currentActor));
        
        if (amount == 0) return;
        
        try token.transfer(to, amount) returns (bool success) {
            if (success) {
                ghost_transferSum += amount;
                ghost_transferCalls++;
            }
        } catch {
            // Transfer can fail if blacklisted
        }
    }
    
    function approve(
        uint256 actorIndexSeed,
        uint256 spenderIndexSeed,
        uint256 amount
    ) public useActor(actorIndexSeed) {
        address spender = actors[bound(spenderIndexSeed, 0, actors.length - 1)];
        amount = bound(amount, 0, type(uint256).max);
        
        try token.approve(spender, amount) {
            // Success
        } catch {
            // Should not fail
        }
    }
    
    function transferFrom(
        uint256 actorIndexSeed,
        uint256 fromActorIndexSeed,
        uint256 toActorIndexSeed,
        uint256 amount
    ) public useActor(actorIndexSeed) {
        address from = actors[bound(fromActorIndexSeed, 0, actors.length - 1)];
        address to = actors[bound(toActorIndexSeed, 0, actors.length - 1)];
        amount = bound(amount, 0, token.balanceOf(from));
        
        if (amount == 0) return;
        
        try token.transferFrom(from, to, amount) {
            // Success
        } catch {
            // Can fail if insufficient allowance or blacklisted
        }
    }
    
    function callSummary() external view {
        console.log("Call Summary:");
        console.log("-------------------");
        console.log("Mint calls:", ghost_mintCalls);
        console.log("Mint sum:", ghost_mintSum);
        console.log("Burn calls:", ghost_burnCalls);
        console.log("Burn sum:", ghost_burnSum);
        console.log("Transfer calls:", ghost_transferCalls);
        console.log("Transfer sum:", ghost_transferSum);
        console.log("-------------------");
    }
    
    function forEachActor(function(address) external func) public {
        for (uint256 i = 0; i < actors.length; i++) {
            func(actors[i]);
        }
    }
    
    function reduceActors(
        uint256 acc,
        function(uint256, address) external returns (uint256) func
    ) public returns (uint256) {
        for (uint256 i = 0; i < actors.length; i++) {
            acc = func(acc, actors[i]);
        }
        return acc;
    }
}

