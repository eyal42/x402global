// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/MockUSDC.sol";

/**
 * @title MockTokenPermitTest
 * @notice Tests EIP-2612 permit functionality for gasless approvals
 */
contract MockTokenPermitTest is Test {
    MockUSDC public token;
    
    address public admin = address(1);
    uint256 public ownerPrivateKey = 0xA11CE;
    address public owner;
    address public spender = address(3);
    
    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    function setUp() public {
        owner = vm.addr(ownerPrivateKey);
        token = new MockUSDC(admin);
        DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();
    }
    
    function _getPermitDigest(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 _deadline
    ) internal view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, _owner, _spender, _value, _nonce, _deadline)
        );
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }
    
    // ============ Valid Permit Tests ============
    
    function test_Permit() public {
        uint256 value = 100e6;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes32 digest = _getPermitDigest(owner, spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        
        vm.expectEmit(true, true, false, true);
        emit Approval(owner, spender, value);
        token.permit(owner, spender, value, deadline, v, r, s);
        
        assertEq(token.allowance(owner, spender), value);
        assertEq(token.nonces(owner), 1);
    }
    
    function test_Permit_MaxDeadline() public {
        uint256 value = 100e6;
        uint256 nonce = 0;
        uint256 deadline = type(uint256).max;
        
        bytes32 digest = _getPermitDigest(owner, spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        
        token.permit(owner, spender, value, deadline, v, r, s);
        
        assertEq(token.allowance(owner, spender), value);
    }
    
    function test_Permit_MultiplePermits() public {
        uint256 value1 = 100e6;
        uint256 deadline = block.timestamp + 1 hours;
        
        // First permit
        bytes32 digest1 = _getPermitDigest(owner, spender, value1, 0, deadline);
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(ownerPrivateKey, digest1);
        token.permit(owner, spender, value1, deadline, v1, r1, s1);
        
        // Second permit with different value
        uint256 value2 = 200e6;
        bytes32 digest2 = _getPermitDigest(owner, spender, value2, 1, deadline);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(ownerPrivateKey, digest2);
        token.permit(owner, spender, value2, deadline, v2, r2, s2);
        
        assertEq(token.allowance(owner, spender), value2);
        assertEq(token.nonces(owner), 2);
    }
    
    // ============ Invalid Permit Tests ============
    
    function test_Permit_RevertExpiredDeadline() public {
        uint256 value = 100e6;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp - 1;
        
        bytes32 digest = _getPermitDigest(owner, spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        
        vm.expectRevert();
        token.permit(owner, spender, value, deadline, v, r, s);
    }
    
    function test_Permit_RevertInvalidSignature() public {
        uint256 value = 100e6;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes32 digest = _getPermitDigest(owner, spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        
        // Use wrong owner
        vm.expectRevert();
        token.permit(spender, spender, value, deadline, v, r, s);
    }
    
    function test_Permit_RevertInvalidNonce() public {
        uint256 value = 100e6;
        uint256 deadline = block.timestamp + 1 hours;
        
        // Sign with wrong nonce (1 instead of 0)
        bytes32 digest = _getPermitDigest(owner, spender, value, 1, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        
        vm.expectRevert();
        token.permit(owner, spender, value, deadline, v, r, s);
    }
    
    function test_Permit_RevertReplayAttack() public {
        uint256 value = 100e6;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes32 digest = _getPermitDigest(owner, spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        
        // First permit succeeds
        token.permit(owner, spender, value, deadline, v, r, s);
        
        // Second permit with same signature fails (nonce changed)
        vm.expectRevert();
        token.permit(owner, spender, value, deadline, v, r, s);
    }
    
    // ============ Nonce Tests ============
    
    function test_Nonces() public view {
        assertEq(token.nonces(owner), 0);
    }
    
    function test_Nonces_AfterPermit() public {
        uint256 value = 100e6;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes32 digest = _getPermitDigest(owner, spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        
        token.permit(owner, spender, value, deadline, v, r, s);
        
        assertEq(token.nonces(owner), 1);
    }
}

