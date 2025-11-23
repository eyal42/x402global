// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./SettlementVault.sol";

/**
 * @title PermitPuller
 * @notice Consumes EIP-2612 permits and pulls funds/assets from both buyer and seller
 * @dev This contract is authorized to pull funds using signed permits
 */
contract PermitPuller is Ownable {
    using SafeERC20 for IERC20;
    
    // ============ State Variables ============
    
    /// @notice Settlement vault where funds are deposited
    SettlementVault public immutable vault;
    
    /// @notice MockEURC token
    IERC20Permit public immutable mockEURC;
    
    // ============ Events ============
    
    event PermitConsumed(
        address indexed token,
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
    
    event FundsTransferred(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount
    );
    
    // ============ Errors ============
    
    error ZeroAddress();
    error ZeroAmount();
    error TransferFailed();
    error PermitFailed();
    
    // ============ Constructor ============
    
    constructor(
        address _vault,
        address _mockEURC,
        address initialOwner
    ) Ownable(initialOwner) {
        if (_vault == address(0) || _mockEURC == address(0)) revert ZeroAddress();
        
        vault = SettlementVault(_vault);
        mockEURC = IERC20Permit(_mockEURC);
    }
    
    // ============ Public Functions ============
    
    /**
     * @notice Pull funds from both client and seller using EIP-2612 permits
     * @param settlementId Settlement identifier
     * @param client Client (buyer) address
     * @param seller Seller address
     * @param assetToken Asset token address
     * @param assetAmount Amount of asset to pull from seller
     * @param eurcAmount Amount of MockEURC to pull from client
     * @param clientPermit Client's permit signature for MockEURC
     * @param sellerPermit Seller's permit signature for asset token
     */
    function pullFundsWithPermits(
        bytes32 settlementId,
        address client,
        address seller,
        address assetToken,
        uint256 assetAmount,
        uint256 eurcAmount,
        PermitSignature calldata clientPermit,
        PermitSignature calldata sellerPermit
    ) external {
        if (client == address(0) || seller == address(0) || assetToken == address(0)) revert ZeroAddress();
        if (assetAmount == 0 || eurcAmount == 0) revert ZeroAmount();
        
        // 1. Consume client's permit for MockEURC
        _consumePermit(
            address(mockEURC),
            client,
            address(this),
            eurcAmount,
            clientPermit
        );
        
        // 2. Pull MockEURC from client to vault
        IERC20(address(mockEURC)).safeTransferFrom(client, address(vault), eurcAmount);
        emit FundsTransferred(address(mockEURC), client, address(vault), eurcAmount);
        
        // 3. Consume seller's permit for asset token
        _consumePermit(
            assetToken,
            seller,
            address(this),
            assetAmount,
            sellerPermit
        );
        
        // 4. Pull asset from seller to vault
        IERC20(assetToken).safeTransferFrom(seller, address(vault), assetAmount);
        emit FundsTransferred(assetToken, seller, address(vault), assetAmount);
        
        // 5. Notify vault that funds have been pulled
        vault.recordFundsPulled(settlementId, eurcAmount, assetAmount);
    }
    
    /**
     * @notice Pull funds from client only (when seller has pre-deposited assets)
     * @param client Client address
     * @param eurcAmount Amount of MockEURC to pull
     * @param clientPermit Client's permit signature
     */
    function pullClientFunds(
        bytes32 /* settlementId */,
        address client,
        uint256 eurcAmount,
        PermitSignature calldata clientPermit
    ) external {
        if (client == address(0)) revert ZeroAddress();
        if (eurcAmount == 0) revert ZeroAmount();
        
        // Consume client's permit for MockEURC
        _consumePermit(
            address(mockEURC),
            client,
            address(this),
            eurcAmount,
            clientPermit
        );
        
        // Pull MockEURC from client to vault
        IERC20(address(mockEURC)).safeTransferFrom(client, address(vault), eurcAmount);
        emit FundsTransferred(address(mockEURC), client, address(vault), eurcAmount);
    }
    
    // ============ Internal Functions ============
    
    /**
     * @notice Consume an EIP-2612 permit
     * @param token Token address
     * @param owner Token owner
     * @param spender Approved spender
     * @param amount Amount to approve
     * @param permitSig Permit signature
     */
    function _consumePermit(
        address token,
        address owner,
        address spender,
        uint256 amount,
        PermitSignature calldata permitSig
    ) internal {
        try IERC20Permit(token).permit(
            owner,
            spender,
            amount,
            permitSig.deadline,
            permitSig.v,
            permitSig.r,
            permitSig.s
        ) {
            emit PermitConsumed(token, owner, spender, amount);
        } catch {
            // Permit might have already been used, check allowance
            uint256 currentAllowance = IERC20(token).allowance(owner, spender);
            if (currentAllowance < amount) revert PermitFailed();
        }
    }
    
    // ============ Structs ============
    
    struct PermitSignature {
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
}

