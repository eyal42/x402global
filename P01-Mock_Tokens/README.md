# Mock Tokens (MockUSDC & MockEURC)

Production-grade ERC-20 tokens with advanced features for testing and development. Includes compliance controls, gasless approvals (EIP-2612), role-based minting, and bridge integration hooks.

## Features

- **ERC-20 Core**: Standard ERC-20 with 6 decimals (matching real USDC/EURC)
- **EIP-2612 Permit**: Gasless approvals via off-chain signatures
- **Access Control**: OpenZeppelin role-based permissions
  - `DEFAULT_ADMIN_ROLE` - Full administrative control
  - `MASTER_MINTER_ROLE` - Can configure minters and allowances
  - `MINTER_ROLE` - Can mint tokens (with allowance limits)
  - `BRIDGE_ROLE` - Can execute bridge operations
- **Compliance Controls**: Blacklist functionality with balance wiping
- **Role-Based Minting**: Fixed cap allowances per minter
- **Bridge Hooks**: Cross-chain burn/mint with event indexing
- **Comprehensive Testing**: 80+ unit tests plus invariant tests

## Project Structure

```
.
├── src/                      # Solidity contracts
│   ├── MockTokenBase.sol     # Base abstract contract
│   ├── MockUSDC.sol          # MockUSDC implementation
│   └── MockEURC.sol          # MockEURC implementation
├── test/                     # Foundry tests
│   ├── MockTokenBaseTest.sol      # ERC-20 core tests
│   ├── MockTokenPermitTest.sol    # EIP-2612 permit tests
│   ├── MockTokenBlacklistTest.sol # Blacklist tests
│   ├── MockTokenMintingTest.sol   # Minting tests
│   ├── MockTokenBridgeTest.sol    # Bridge hooks tests
│   └── invariant/                 # Invariant tests
│       ├── MockTokenInvariant.t.sol
│       └── handlers/
│           └── TokenHandler.sol
├── script/                   # Deployment scripts
│   ├── Deploy.s.sol          # Main deployment
│   ├── Setup.s.sol           # Post-deployment setup
│   ├── Mint.s.sol            # Mint tokens
│   └── SmokeTest.s.sol       # On-chain verification
├── python/                   # Python utilities
│   ├── config.py             # Shared configuration
│   ├── balance.py            # Balance checker
│   ├── mint_burn.py          # Mint/burn operations
│   ├── blacklist.py          # Blacklist management
│   └── README.md             # Python utilities docs
├── deploy/                   # Deployment artifacts
│   └── addresses.example.json
├── foundry.toml              # Foundry configuration
├── requirements.txt          # Python dependencies
└── README.md                 # This file
```

## Installation

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Python 3.8+](https://www.python.org/downloads/)
- Node.js (optional, for additional tooling)

### Setup

1. **Clone the repository:**
```bash
git clone <repository-url>
cd P01-Mock_Tokens
```

2. **Install Foundry dependencies:**
```bash
forge install
```

3. **Install Python dependencies:**
```bash
pip install -r requirements.txt
```

4. **Create `.env` file:**
```bash
cp .env.example .env
# Edit .env with your configuration
```

5. **Build contracts:**
```bash
forge build
```

## Testing

### Run All Tests

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vv

# Run with gas report
forge test --gas-report

# Run specific test file
forge test --match-path test/MockTokenBaseTest.sol

# Run specific test
forge test --match-test test_Transfer
```

### Test Coverage

The project includes 80+ comprehensive tests:

- **Core ERC-20** (14 tests): Decimals, transfers, approvals, balance tracking
- **EIP-2612 Permit** (9 tests): Valid permits, nonce management, deadline enforcement
- **Blacklist** (15 tests): Set/unset, transfer blocking, wipe functionality
- **Role Minting** (20 tests): Role grants, allowance configuration, minting limits
- **Bridge Hooks** (16 tests): Role permissions, burn/mint operations, events
- **Invariant Tests** (6 tests): Supply invariants, balance constraints

### Run Tests Offline

```bash
forge test --offline
```

### Invariant Tests

```bash
forge test --match-path "test/invariant/*.sol" -vv
```

## Deployment

### Local Deployment (Anvil)

1. **Start Anvil:**
```bash
anvil
```

2. **Deploy contracts:**
```bash
forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --broadcast
```

### Testnet Deployment

1. **Set environment variables in `.env`:**
```bash
DEPLOYER_PRIVATE_KEY=0x...
DEPLOYER_WALLET=0x...
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
```

2. **Deploy to Arbitrum Sepolia:**
```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \ 
  --private-key $DEPLOYER_PRIVATE_KEY
```

3. **Setup roles and minter:**
```bash
forge script script/Setup.s.sol:Setup \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --sig "run(address,address)" <token-address> <minter-address>
```

4. **Mint initial tokens:**
```bash
forge script script/Mint.s.sol:Mint \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --sig "run(address,address,uint256)" <token-address> <user-address> 1000000000
```

### Verify Deployment

```bash
forge script script/SmokeTest.s.sol:SmokeTest \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --sig "run(address)" <token-address>
```

## Python Utilities

The `python/` directory contains utilities for interacting with deployed contracts.

### Setup

```bash
cd python
pip install -r ../requirements.txt
```

### Check Balances

```bash
python balance.py 0xYourAddress --rpc $RPC_URL
```

### Mint Tokens

```bash
python mint_burn.py --token $USDC_ADDRESS mint 0xRecipient 1000.0
```

### Manage Blacklist

```bash
# Check blacklist status
python blacklist.py --token $USDC_ADDRESS check 0xAddress

# Add to blacklist
python blacklist.py --token $USDC_ADDRESS add 0xBadActor

# Wipe blacklisted balance
python blacklist.py --token $USDC_ADDRESS wipe 0xBadActor
```

See [python/README.md](python/README.md) for complete documentation.

## Contract Architecture

### MockTokenBase (Abstract)

Base contract implementing all features:

- ERC-20 standard with 6 decimals
- EIP-2612 permit functionality
- Role-based access control
- Blacklist compliance
- Minter allowance system
- Bridge burn/mint hooks

### MockUSDC & MockEURC

Concrete implementations inheriting from `MockTokenBase`:

- **MockUSDC**: "Mock USD Coin" with symbol "MockUSDC"
- **MockEURC**: "Mock Euro Coin" with symbol "MockEURC"

## Key Functions

### Minting

```solidity
// Configure minter (requires MASTER_MINTER_ROLE)
function configureMinter(address minter, uint256 allowance) external;

// Mint tokens (requires MINTER_ROLE and sufficient allowance)
function mint(address to, uint256 amount) external;

// Burn tokens (anyone can burn their own tokens)
function burn(uint256 amount) external;
```

### Blacklist

```solidity
// Set blacklist status (requires DEFAULT_ADMIN_ROLE)
function setBlacklisted(address account, bool blacklisted) external;

// Wipe blacklisted balance (requires DEFAULT_ADMIN_ROLE)
function wipeBlacklisted(address account) external;

// Check blacklist status
function isBlacklisted(address account) external view returns (bool);
```

### Bridge Hooks

```solidity
// Burn for cross-chain transfer (requires BRIDGE_ROLE)
function bridgeBurn(
    bytes32 dstChain,
    bytes dstRecipient,
    uint256 amount,
    bytes data
) external;

// Mint from cross-chain transfer (requires BRIDGE_ROLE)
function bridgeMint(
    bytes32 srcChain,
    bytes srcSender,
    address to,
    uint256 amount,
    bytes data
) external;
```

### Permit (EIP-2612)

```solidity
// Gasless approval via signature
function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
) external;
```

## Security Considerations

### ⚠️ WARNING: TEST TOKENS ONLY

These tokens are designed for **testing and development only**. They include features that would be inappropriate for production use:

- Unrestricted minting (with configurable allowances)
- Administrative blacklist controls
- Balance wiping functionality

### Access Control

The contracts use OpenZeppelin's AccessControl for role management:

1. **DEFAULT_ADMIN_ROLE**: Can grant/revoke all roles and manage blacklist
2. **MASTER_MINTER_ROLE**: Can configure minter allowances
3. **MINTER_ROLE**: Can mint tokens up to their allowance
4. **BRIDGE_ROLE**: Can execute bridge operations

### Best Practices

- Keep admin private keys secure
- Use hardware wallets for admin roles in production-like environments
- Regularly audit role assignments
- Monitor blacklist events
- Set appropriate minter allowances

## Development Workflow

### Format Code

```bash
forge fmt
```

### Run Linter

```bash
forge build --force
```

### Gas Optimization

```bash
forge test --gas-report
forge snapshot
```

### Clean Build

```bash
forge clean
forge build
```

## Expected Test Output

```
Ran 5 test suites: 74 tests passed, 0 failed, 0 skipped (74 total tests)

Test Breakdown:
- MockTokenBaseTest: 14 tests ✓
- MockTokenPermitTest: 9 tests ✓
- MockTokenBlacklistTest: 15 tests ✓
- MockTokenMintingTest: 20 tests ✓
- MockTokenBridgeTest: 16 tests ✓

Ran 1 invariant test suite: 6 tests passed
- MockTokenInvariantTest: 6 tests ✓
```

## Troubleshooting

### Common Issues

**Issue**: `Error: Could not find artifacts`
```bash
# Solution: Build contracts first
forge build
```

**Issue**: `Connection refused` when running Python scripts
```bash
# Solution: Check RPC URL in .env
RPC_URL=http://127.0.0.1:8545
```

**Issue**: `Insufficient allowance` when minting
```bash
# Solution: Configure minter allowance first
forge script script/Setup.s.sol...
```

**Issue**: Tests fail with network errors
```bash
# Solution: Run tests in offline mode
forge test --offline
```

## Contributing

This is a demonstration project. For production use, consider:

1. Professional security audit
2. Formal verification
3. Gradual rollout
4. Emergency pause mechanisms
5. Upgrade mechanisms (if needed)

## License

MIT License - See LICENSE file for details

## Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [EIP-2612: Permit Extension](https://eips.ethereum.org/EIPS/eip-2612)
- [Web3.py Documentation](https://web3py.readthedocs.io/)
