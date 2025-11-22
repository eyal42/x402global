# mockUSDC and mockEURC, ERC-20 tokens with Advanced Features

## Project Overview
Create a Foundry-based Solidity project implementing production-grade ERC-20 tokens with compliance controls, including blacklists and whitelists, gasless approvals, role-based minting, and bridge integration hooks. Include comprehensive testing, deployment scripts, and Python utilities for interaction.

## Project Structure Requirements

### Core Directories
- `src/` - Solidity source contracts
  - Base abstract contract with all shared functionality
  - Two concrete token implementations MockUSDC, MockEURC)
- `test/` - Foundry test suite
  - Unit tests for each feature module
  - Invariant tests in `test/invariant/` subdirectory
  - Handler contracts for fuzzing in `test/invariant/handlers/`
- `script/` - Foundry deployment and setup scripts
  - `Deploy.s.sol` - Main deployment script
  - `Setup.s.sol` - Post-deployment role configuration, reads MINTER address and CCY from cl and setsup Minter to Mint CCY
  - `Mint.s.sol` - Reads from cl MINTER, USER and CCY addresses, and has MINTER mint CCY to USER. 
  - `SmokeTest.s.sol` - On-chain verification tests
- `python/` - Web3.py utilities for contract interaction
  - `config.py` - Shared configuration and Web3 setup
  - Feature-specific scripts (mint_burn.py, permit.py, blacklist.py, events.py, bridge_hooks.py)
  - Write balance.py, a python script reading and printing balance of address in MockUSDC,MockEURC and native asset. 
  - `README.md` - Python utilities documentation
- `deploy/` - Deployment artifacts
  - `addresses.<network>.json` - Contract addresses per network
  - `addresses.example.json` - Template file
- `lib/` - Foundry dependencies (OpenZeppelin, forge-std)
- `out/` - Compiled artifacts (generated)
- `cache/` - Foundry cache (generated)
- `broadcast/` - Broadcast transaction logs (generated)

### Configuration Files
- `foundry.toml` - Foundry configuration with:
  - Solidity version (0.8.28)
  - Optimizer settings (enabled, 200 runs)
  - RPC endpoint mappings for multiple networks
  - Etherscan verification configs
  - Fuzz and invariant test settings
- `requirements.txt` - Python dependencies (web3.py, python-dotenv, eth-account)
- `.env.example` - Environment variable template
- `.gitignore` - Standard Foundry + Python ignores

### Documentation Files
- `README.md` - Main project documentation with:
  - Feature overview
  - Installation and setup instructions
  - Testing guide with examples
  - Deployment instructions for multiple networks
  - Python utilities usage
  - Expected test output
- `DESIGN_GUIDE.md` - Architecture and design decisions
- `USAGE_EXAMPLES.md` - Common workflows and examples
- `PROJECT_TEMPLATE_PROMPT.md` - This file (meta-documentation)

## Contract Requirements

### Base Contract Features
1. **ERC-20 Core**: Standard ERC-20 with 6 decimals (not 18)
2. **EIP-2612 Permit**: Gasless approvals via `permit()` function
3. **Access Control**: OpenZeppelin AccessControl with custom roles:
   - `DEFAULT_ADMIN_ROLE` - Full administrative control
   - `MASTER_MINTER_ROLE` - Can configure minters
   - `MINTER_ROLE` - Can mint tokens (with allowance limits)
   - `BRIDGE_ROLE` - Can execute bridge operations
4. **Compliance Controls**:
   - Blacklist mapping with `setBlacklisted(address, bool)`
   - Transfer restrictions (block to/from blacklisted addresses)
   - `wipeBlacklisted(address)` to burn blacklisted balances
   - Events: `BlacklistedSet`, `BlacklistedWiped`
5. **Role-Based Minting**:
   - Fixed cap allowances per minter (configured by master minter)
   - `configureMinter(address, uint256)` to set allowances
   - `mint(address, uint256)` requires MINTER_ROLE and sufficient allowance
   - Public `burn(uint256)` function
   - Event: `MinterConfigured`
6. **Bridge Hooks**:
   - `bridgeBurn(bytes32 dstChain, bytes dstRecipient, uint256 amount, bytes data)`
   - `bridgeMint(bytes32 srcChain, bytes srcSender, address to, uint256 amount, bytes data)`
   - Events: `BridgeBurn`, `BridgeMint` with indexed parameters for chain/sender/recipient

### Token Implementations
- Two concrete contracts inheriting from base (e.g., TestUSDCToken, TestEURCToken)
- Each with unique name and symbol
- Same functionality, different deployment instances

## Testing Requirements

### Unit Tests (Foundry)
- **Core ERC-20**: Decimals, transfers, approvals, balance tracking (12+ tests)
- **EIP-2612 Permit**: Valid permits, nonce management, deadline enforcement, replay protection (9+ tests)
- **Blacklist**: Set/unset, transfer blocking, wipe functionality, events (18+ tests)
- **Role Minting**: Role grants, allowance configuration, minting within/beyond limits, burn (19+ tests)
- **Bridge Hooks**: Role permissions, burn/mint operations, event emissions, balance updates (20+ tests)

### Invariant Tests
- Supply invariants: sum of balances = total supply
- Supply never negative
- Individual balances never exceed supply
- Blacklist enforcement
- Handler-based fuzzing with call summaries

### On-Chain Smoke Tests
- Script that verifies all major functions work on deployed contracts
- Tests: basic info, roles, minting, transfers, permit, blacklist, bridge hooks
- Outputs pass/fail status for each test

## Deployment Scripts

### Deploy.s.sol
- Deploys both token contracts
- Reads addresses from environment variables
- Supports multiple networks (Arbitrum Sepolia, Polygon Amoy)
- Saves deployment addresses to JSON files

### Setup.s.sol
- Grants MASTER_MINTER_ROLE to deployer wallet
- Grants MINTER_ROLE to deployer wallet
- Configures minter allowance (1 billion tokens)
- Idempotent (checks before granting)

### SetupAndMint.s.sol
- Combines Setup.s.sol functionality
- Additionally mints initial tokens to a user wallet
- Useful for quick initialization

## Python Utilities

### Common Infrastructure (`config.py`)
- Web3 connection management
- Account handling from private keys
- Contract ABI loading from Foundry output
- Transaction sending with receipt waiting
- Amount formatting/parsing (6 decimals)
- Role hash constants

### Feature Scripts
1. **mint_burn.py**: Mint tokens, burn tokens, check balances, check minter status
2. **permit.py**: Sign permits, execute permits, full gasless approval demo
3. **blacklist.py**: Check/set blacklist status, test transfers, wipe balances, full demo
4. **events.py**: Query historical events, watch for new events in real-time
5. **bridge_hooks.py**: Bridge burn, bridge mint, round-trip demos, event testing
6. **balance.py**: Check balances for native token and all deployed tokens on a network

All scripts should:
- Support `--token` flag for contract address
- Support `--rpc` and `--private-key` flags (with env fallback)
- Have clear help text and examples
- Use subcommands for different actions
- Provide informative console output

## Documentation Standards

### README.md Should Include
- Project overview and features
- Directory structure diagram
- Installation prerequisites and setup steps
- Testing instructions with verbosity levels
- Test coverage summary (test counts per suite)
- Contract architecture explanation
- Role descriptions
- Key function documentation
- Python utilities quick reference
- Deployment instructions for local and testnets
- Smoke test instructions
- Expected test output
- Security considerations
- Development workflow (formatting, static analysis, gas optimization)
- GitHub workflow (clone, commit, push, pull)

### DESIGN_GUIDE.md Should Include
- Architecture decisions and rationale
- Role hierarchy and permissions
- Blacklist semantics and edge cases
- EIP-2612 implementation details
- Bridge event schema and indexing strategy
- Library choices (OpenZeppelin)
- Testing strategy
- Gas optimization considerations

### USAGE_EXAMPLES.md Should Include
- Complete setup workflow
- Common operations (mint, transfer, permit, blacklist)
- Multi-user scenarios
- Compliance testing flows
- Troubleshooting common issues
- Quick reference table

## Environment Configuration

### .env.example Template
```bash
# RPC URLs
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
POLYGON_AMOY_RPC_URL=https://rpc-amoy.polygon.technology

# Private Keys
DEPLOYER_PRIVATE_KEY=0x...
PRIVATE_KEY=0x...

# Contract Addresses (after deployment)
USDC_ADDRESS=0x...
EURC_ADDRESS=0x...
DEPLOYER_WALLET=0x...
USER_1_WALLET=0x...

# Etherscan
ETHERSCAN_API_KEY=...
```

## Quality Standards

### Code Quality
- Solidity 0.8.28 with strict compiler settings
- OpenZeppelin contracts for security
- Comprehensive NatSpec documentation
- Custom errors instead of require strings
- Events for all state changes

### Testing Quality
- 80+ comprehensive tests covering all features
- Edge cases and error conditions
- Event emission verification
- Gas optimization considerations
- Invariant testing for critical properties

### Documentation Quality
- Clear, step-by-step instructions
- Code examples for all common operations
- Expected outputs for verification
- Troubleshooting sections
- Security warnings where appropriate

## Deliverables Checklist

- [ ] Foundry project initialized with dependencies
- [ ] Base contract with all features implemented
- [ ] Two token implementations
- [ ] Complete test suite (80+ tests)
- [ ] Invariant tests with handlers
- [ ] Deployment scripts for multiple networks
- [ ] Setup and minting scripts
- [ ] On-chain smoke test script
- [ ] Python utilities (6+ scripts)
- [ ] Configuration files (foundry.toml, requirements.txt, .env.example)
- [ ] Comprehensive README.md
- [ ] DESIGN_GUIDE.md
- [ ] USAGE_EXAMPLES.md
- [ ] Deployment address JSON files
- [ ] All tests passing locally
- [ ] Smoke tests passing on testnets
- [ ] Clean git history with conventional commits

## Success Criteria

1. **Functionality**: All features work as specified (ERC-20, permit, blacklist, minting, bridge hooks)
2. **Testing**: 80+ tests, all passing, with good coverage
3. **Deployment**: Successfully deployable to multiple testnets
4. **Usability**: Clear documentation and working Python utilities
5. **Code Quality**: Clean, well-documented, secure code following best practices
6. **Completeness**: All deliverables present and functional

## Notes

- Use OpenZeppelin contracts for security and standardization
- Follow Foundry best practices for testing and deployment
- Ensure Python scripts are user-friendly with clear error messages
- Document all environment variables and their purposes
- Include security warnings for test tokens
- Make scripts idempotent where possible
- Support multiple networks from the start
- Use conventional commit messages for git history

