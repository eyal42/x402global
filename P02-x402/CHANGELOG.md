# Changelog

All notable changes to the x402 OTC API project.

---

## [1.1.0] - Role Separation Update

### 🎯 Major Changes

**Role Separation:** Clear separation of three distinct roles with dedicated configuration

### Added

- **ROLES.md** - Comprehensive guide explaining the three roles
- **Role-based environment variables:**
  - `FACILITATOR_PRIVATE_KEY` / `FACILITATOR_ADDRESS`
  - `SELLER_PRIVATE_KEY` / `SELLER_ADDRESS`
  - `CLIENT_PRIVATE_KEY` / `CLIENT_ADDRESS`
- **Role-based validation** in `Config.validate(role="...")`
- **Enhanced logging** showing which role performs each action

### Changed

- **`env.example`** - Restructured with clear role sections and documentation
- **`python/common/config.py`**
  - Replaced `SERVER_PRIVATE_KEY` with `FACILITATOR_PRIVATE_KEY`
  - Added separate configuration for all three roles
  - Enhanced validation with role-specific checks
- **`python/server/server.py`**
  - Uses `facilitator_account` instead of generic `account`
  - Creates orders with explicit `SELLER_ADDRESS`
  - Enhanced logging showing facilitator and seller roles
  - Updated health endpoint to show both facilitator and seller
- **`python/client/client.py`**
  - Enhanced initialization with role identification
  - Better address verification
  - Improved configuration validation
- **`python/utils.py`**
  - Updated to use `FACILITATOR_PRIVATE_KEY`
- **All deployment scripts** (`script/*.s.sol`)
  - Changed from `PRIVATE_KEY` to `FACILITATOR_PRIVATE_KEY`
  - Contracts owned by facilitator (who runs the server)
  - Enhanced logging showing facilitator ownership

### Deprecated

- `PRIVATE_KEY` (use `FACILITATOR_PRIVATE_KEY` instead)
- `SERVER_PRIVATE_KEY` (use `FACILITATOR_PRIVATE_KEY` instead)

### Migration Guide

**Old `.env` format:**
```bash
PRIVATE_KEY=0xabc...
CLIENT_PRIVATE_KEY=0xdef...
```

**New `.env` format:**
```bash
FACILITATOR_PRIVATE_KEY=0xabc...
FACILITATOR_ADDRESS=0x111...

SELLER_PRIVATE_KEY=0xghi...
SELLER_ADDRESS=0x222...

CLIENT_PRIVATE_KEY=0xdef...
CLIENT_ADDRESS=0x333...
```

To migrate:
1. Copy `env.example` to see new format
2. Replace `PRIVATE_KEY` with `FACILITATOR_PRIVATE_KEY`
3. Add `FACILITATOR_ADDRESS`
4. Add `SELLER_PRIVATE_KEY` and `SELLER_ADDRESS`
5. Add `CLIENT_ADDRESS`
6. Test with `python server/server.py` and `python client/client.py`

---

## [1.0.0] - Initial Release

### Added

- **Smart Contracts**
  - `YieldPoolShare.sol` - ERC-20 asset token
  - `SettlementVault.sol` - Core x402 payment vault
  - `SwapSimulator.sol` - EURC→USDC simulator

- **Deployment Scripts**
  - `DeployAll.s.sol` - Complete system deployment
  - Individual contract deployment scripts
  - `SetupDemo.s.sol` - Demo environment setup

- **Tests**
  - `YieldPoolShare.t.sol`
  - `SwapSimulator.t.sol`
  - `SettlementVault.t.sol`

- **Python Components**
  - `server/server.py` - Flask HTTP server with `/buy-asset` endpoint
  - `client/client.py` - EIP-2612 signing client
  - `tracker/tracker.py` - Real-time event tracker
  - `common/config.py` - Configuration management
  - `common/contracts.py` - Contract ABIs and helpers
  - `utils.py` - Utility functions

- **Documentation**
  - `README.md` - Main project documentation
  - `QUICKSTART.md` - 5-minute setup guide
  - `ARCHITECTURE.md` - Technical deep dive
  - `PROJECT_SUMMARY.md` - Project overview
  - `INDEX.md` - Complete file listing
  - `python/README.md` - Python-specific guide

- **Helper Scripts**
  - `setup.sh` - Python environment setup
  - `run_demo.sh` - Demo runner

- **Features**
  - HTTP 402 (Payment Required) protocol
  - EIP-2612 gasless approvals
  - Complete settlement flow
  - Real-time event tracking
  - Automatic refund mechanism
  - EUR/USD conversion simulation

---

## Version Numbering

- **Major version** (X.0.0): Breaking changes
- **Minor version** (0.X.0): New features, non-breaking changes
- **Patch version** (0.0.X): Bug fixes

---

## Upcoming

### Planned Features
- [ ] Real DEX integration (Uniswap V4)
- [ ] Multi-asset support
- [ ] Web UI frontend
- [ ] Advanced order types
- [ ] Cross-chain support

### Known Issues
- None currently

---

**For detailed information about roles, see [ROLES.md](ROLES.md)**

