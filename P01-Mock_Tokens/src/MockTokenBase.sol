// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title MockTokenBase
 * @notice Base contract for mock ERC-20 tokens with advanced features including:
 *         - EIP-2612 permit (gasless approvals)
 *         - Role-based access control
 *         - Blacklist compliance controls
 *         - Role-based minting with allowances
 *         - Bridge integration hooks
 * @dev This contract uses 6 decimals instead of the standard 18 decimals
 */
abstract contract MockTokenBase is ERC20, ERC20Permit, AccessControl {
    // ============ Custom Errors ============
    
    error AccountBlacklisted(address account);
    error InsufficientMinterAllowance(address minter, uint256 requested, uint256 available);
    error NotMinter(address account);
    error NotMasterMinter(address account);
    error NotBridge(address account);
    error ZeroAddress();
    error ZeroAmount();
    
    // ============ Roles ============
    
    /// @notice Role that can configure minters and their allowances
    bytes32 public constant MASTER_MINTER_ROLE = keccak256("MASTER_MINTER_ROLE");
    
    /// @notice Role that can mint tokens (subject to allowances)
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    /// @notice Role that can execute bridge operations
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    
    // ============ State Variables ============
    
    /// @notice Mapping of blacklisted addresses
    mapping(address => bool) public isBlacklisted;
    
    /// @notice Mapping of minter addresses to their remaining mint allowances
    mapping(address => uint256) public minterAllowance;
    
    // ============ Events ============
    
    /// @notice Emitted when an address is blacklisted or unblacklisted
    event BlacklistedSet(address indexed account, bool isBlacklisted);
    
    /// @notice Emitted when a blacklisted address's balance is wiped
    event BlacklistedWiped(address indexed account, uint256 amount);
    
    /// @notice Emitted when a minter's allowance is configured
    event MinterConfigured(address indexed minter, uint256 allowance);
    
    /// @notice Emitted when tokens are burned for bridging
    event BridgeBurn(
        address indexed from,
        bytes32 indexed dstChain,
        bytes indexed dstRecipient,
        uint256 amount,
        bytes data
    );
    
    /// @notice Emitted when tokens are minted from bridging
    event BridgeMint(
        bytes32 indexed srcChain,
        bytes indexed srcSender,
        address indexed to,
        uint256 amount,
        bytes data
    );
    
    // ============ Constructor ============
    
    /**
     * @notice Initialize the token contract
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param admin Initial admin address (receives DEFAULT_ADMIN_ROLE)
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address admin
    ) ERC20(name_, symbol_) ERC20Permit(name_) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }
    
    // ============ ERC-20 Overrides ============
    
    /**
     * @notice Returns 6 decimals instead of the standard 18
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    
    /**
     * @notice Transfer tokens with blacklist checks
     * @param to Recipient address
     * @param value Amount to transfer
     */
    function transfer(address to, uint256 value) public override returns (bool) {
        if (isBlacklisted[msg.sender]) revert AccountBlacklisted(msg.sender);
        if (isBlacklisted[to]) revert AccountBlacklisted(to);
        return super.transfer(to, value);
    }
    
    /**
     * @notice Transfer tokens from address with blacklist checks
     * @param from Sender address
     * @param to Recipient address
     * @param value Amount to transfer
     */
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (isBlacklisted[from]) revert AccountBlacklisted(from);
        if (isBlacklisted[to]) revert AccountBlacklisted(to);
        return super.transferFrom(from, to, value);
    }
    
    // ============ Blacklist Functions ============
    
    /**
     * @notice Set or unset an address as blacklisted
     * @param account Address to modify
     * @param blacklisted True to blacklist, false to unblacklist
     */
    function setBlacklisted(address account, bool blacklisted) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (account == address(0)) revert ZeroAddress();
        isBlacklisted[account] = blacklisted;
        emit BlacklistedSet(account, blacklisted);
    }
    
    /**
     * @notice Wipe the balance of a blacklisted address
     * @param account Blacklisted address to wipe
     */
    function wipeBlacklisted(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!isBlacklisted[account]) revert AccountBlacklisted(account);
        uint256 balance = balanceOf(account);
        if (balance > 0) {
            _burn(account, balance);
            emit BlacklistedWiped(account, balance);
        }
    }
    
    // ============ Minting Functions ============
    
    /**
     * @notice Configure a minter's allowance
     * @param minter Address to configure
     * @param allowance Maximum amount the minter can mint
     */
    function configureMinter(address minter, uint256 allowance) 
        external 
        onlyRole(MASTER_MINTER_ROLE) 
    {
        if (minter == address(0)) revert ZeroAddress();
        minterAllowance[minter] = allowance;
        emit MinterConfigured(minter, allowance);
    }
    
    /**
     * @notice Mint tokens to an address
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (isBlacklisted[to]) revert AccountBlacklisted(to);
        
        uint256 allowance = minterAllowance[msg.sender];
        if (amount > allowance) {
            revert InsufficientMinterAllowance(msg.sender, amount, allowance);
        }
        
        minterAllowance[msg.sender] = allowance - amount;
        _mint(to, amount);
    }
    
    /**
     * @notice Burn tokens from caller's balance
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        _burn(msg.sender, amount);
    }
    
    // ============ Bridge Functions ============
    
    /**
     * @notice Burn tokens for cross-chain bridge transfer
     * @param dstChain Destination chain identifier
     * @param dstRecipient Recipient address on destination chain
     * @param amount Amount to burn
     * @param data Additional bridge data
     */
    function bridgeBurn(
        bytes32 dstChain,
        bytes memory dstRecipient,
        uint256 amount,
        bytes memory data
    ) external onlyRole(BRIDGE_ROLE) {
        if (amount == 0) revert ZeroAmount();
        if (dstRecipient.length == 0) revert ZeroAddress();
        
        _burn(msg.sender, amount);
        emit BridgeBurn(msg.sender, dstChain, dstRecipient, amount, data);
    }
    
    /**
     * @notice Mint tokens from cross-chain bridge transfer
     * @param srcChain Source chain identifier
     * @param srcSender Sender address on source chain
     * @param to Recipient address on this chain
     * @param amount Amount to mint
     * @param data Additional bridge data
     */
    function bridgeMint(
        bytes32 srcChain,
        bytes memory srcSender,
        address to,
        uint256 amount,
        bytes memory data
    ) external onlyRole(BRIDGE_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (isBlacklisted[to]) revert AccountBlacklisted(to);
        
        _mint(to, amount);
        emit BridgeMint(srcChain, srcSender, to, amount, data);
    }
}
