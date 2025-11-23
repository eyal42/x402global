# P03 - Uniswap v4 Hook-Enabled Liquidity Pool

A comprehensive implementation of a Uniswap v4 hook-enabled liquidity pool for **MockEURC ⇄ MockUSDC** on **Polygon Amoy**. This system supports an OTC-style payment flow driven by a facilitator smart contract with vault integration.

## 🎯 Overview

This project implements a complete end-to-end solution for facilitator-controlled swaps with:

- **FacilitatorHook**: Custom Uniswap v4 hook that validates facilitator authorization and charges fees
- **PoolSettlementVault**: Vault contract managing asset settlement flow
- **Facilitator**: Orchestrator contract for executing swaps against the Uniswap v4 pool
- **Python Tools**: Client scripts for executing swaps and tracking events in real-time

### Architecture

```
┌─────────────┐      ┌──────────────┐      ┌─────────────────┐
│   Client    │─────▶│ Facilitator  │─────▶│  PoolManager    │
│             │      │   Contract   │      │   (Uniswap v4)  │
└─────────────┘      └──────────────┘      └─────────────────┘
                            │                        │
                            │                        │
                            ▼                        ▼
                     ┌──────────────┐      ┌─────────────────┐
                     │    Vault     │      │ FacilitatorHook │
                     │   Contract   │      │                 │
                     └──────────────┘      └─────────────────┘
```

## 📋 Features

### Core Contracts

1. **FacilitatorHook.sol**
   - Validates swap callers (only authorized facilitators)
   - Implements beforeSwap and afterSwap hooks
   - Charges configurable facilitator fees (default 0.3%)
   - Emits detailed events for tracking

2. **PoolSettlementVault.sol**
   - Manages asset escrow and settlement
   - Enforces deposit ordering (asset first, then EURC)
   - Supports vault timeout and reversal
   - Integrates with pool for USDC receipt

3. **Facilitator.sol**
   - Orchestrates swaps through Uniswap v4 PoolManager
   - Supports both vault-integrated and simple swaps
   - Configurable pool key management
   - Slippage protection

### Deployment & Scripts

- **Deploy.s.sol**: Deploy all contracts and configure relationships
- **InitializePool.s.sol**: Initialize Uniswap v4 pool with hook
- **AddLiquidity.s.sol**: Add liquidity to the pool
- **ExecuteSwap.s.sol**: Execute test swaps through the facilitator

### Python Tools

- **facilitator_client.py**: Execute swaps from Python
- **tracker.py**: Real-time event monitoring with human-readable progress

### Tests

Comprehensive Foundry tests covering:
- Hook authorization and permissions
- Vault state transitions and settlement
- Fee calculations
- Error cases and edge conditions

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Python 3.8+ (for Python tools)
- RPC access to Polygon Amoy
- Test tokens (MockEURC, MockUSDC)

### Installation

1. **Clone and install dependencies:**

```bash
cd P03-Pool
forge install
```

2. **Set up environment variables:**

Create a `.env` file in the project root:

```bash
# Network Configuration
POLYGON_AMOY_RPC_URL=https://rpc-amoy.polygon.technology/
POLYGONSCAN_API_KEY=your_api_key

# Deployer Configuration
PRIVATE_KEY=your_private_key
DEPLOYER_ADDRESS=your_address

# Uniswap v4 Addresses (Polygon Amoy)
POOL_MANAGER_ADDRESS=0x... # Uniswap v4 PoolManager
SWAP_ROUTER_ADDRESS=0x...  # PoolSwapTest router
LIQUIDITY_ROUTER_ADDRESS=0x... # PoolModifyLiquidityTest router

# Token Addresses
MOCK_EURC_ADDRESS_POLYGON=0x...
MOCK_USDC_ADDRESS_POLYGON=0x...

# Deployed Contract Addresses (filled after deployment)
HOOK_ADDRESS=
VAULT_ADDRESS=
FACILITATOR_ADDRESS=
```

3. **Build contracts:**

```bash
forge build
```

## 📦 Deployment

### Step 1: Deploy Contracts

```bash
forge script script/Deploy.s.sol \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast \
  --verify
```

This deploys:
- FacilitatorHook
- PoolSettlementVault
- Facilitator

And configures their relationships automatically.

**Output**: Contract addresses are saved to `deployed_addresses.env`

### Step 2: Initialize Pool

```bash
forge script script/InitializePool.s.sol \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast
```

This creates and initializes the Uniswap v4 pool with:
- MockEURC/MockUSDC pair
- 0.3% fee tier
- 60 tick spacing
- FacilitatorHook attached
- Initial 1:1 price ratio

### Step 3: Add Liquidity

First, ensure you have sufficient token balances. Then:

```bash
forge script script/AddLiquidity.s.sol \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast
```

This adds initial liquidity (default: 10,000 of each token) across a full range position.

### Step 4: Test Swaps

```bash
forge script script/ExecuteSwap.s.sol \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast
```

This executes:
1. EURC → USDC swap (100 tokens)
2. USDC → EURC reverse swap (50 tokens)

And displays the results.

## 🐍 Python Tools

### Setup

```bash
cd python
pip install -r requirements.txt
```

### Execute Swaps

```bash
python facilitator_client.py \
  --amount-in 100 \
  --token-in EURC \
  --token-out USDC \
  --slippage 5
```

**Example Output:**
```
✅ Connected to Polygon Amoy
📍 Account: 0x742d35Cc6634C0532925a3b844Bc454e4438f44e
🔗 Facilitator: 0x...

📊 Initial Balances:
   EURC: 10000.0
   USDC: 10000.0

💱 Executing Swap
   From: 100 EURC
   To: USDC (min: 95.0)
   Direction: 0→1
   Slippage: 5%

✅ Swap Successful!
   Transaction: 0x...
   Gas Used: 234567

📊 Final Balances:
   EURC: 9900.0
   USDC: 10099.7
```

### Track Events

Monitor all contract events in real-time:

```bash
python tracker.py --output status.json --poll-interval 5
```

**Example Output:**
```
🔍 Event Tracker Started
🔗 Network: Polygon Amoy
📍 Contracts:
   Facilitator: 0x...
   Hook: 0x...
   Vault: 0x...

👀 Watching for events... (Press Ctrl+C to stop)

📦 New events in blocks 12345 to 12347:
────────────────────────────────────────────────────────────────────────────────
2025-11-22T... | Block 12345 | Facilitator  | FacilitatedSwapRequested      | TX: 0xabcd...
   🔄 Swap requested
2025-11-22T... | Block 12346 | Hook         | BeforeSwapExecuted            | TX: 0xabcd...
   ⚙️  Pre-swap hook executed
2025-11-22T... | Block 12346 | Hook         | AfterSwapExecuted             | TX: 0xabcd...
   ✅ Post-swap hook executed
2025-11-22T... | Block 12346 | Hook         | FacilitatorFeeCharged         | TX: 0xabcd...
   💰 Facilitator fee charged
2025-11-22T... | Block 12347 | Facilitator  | FacilitatedSwapCompleted      | TX: 0xabcd...
   ✨ Swap completed
────────────────────────────────────────────────────────────────────────────────
```

## 🧪 Testing

### Run All Tests

```bash
forge test -vv
```

### Run Specific Tests

```bash
# Hook tests
forge test --match-path "test/FacilitatorHook.t.sol" -vv

# Vault tests
forge test --match-path "test/PoolSettlementVault.t.sol" -vv
```

### Test Coverage

```bash
forge coverage
```

## 📊 Contract Details

### FacilitatorHook

**Key Features:**
- Authorization: Only whitelisted facilitators can trigger swaps
- Fee Management: Configurable fee rate (0-10%)
- Event Tracking: Comprehensive events for all hook actions

**Main Functions:**
- `setFacilitator(address, bool)`: Authorize/deauthorize facilitators
- `setFeeRate(uint24)`: Set fee rate in basis points
- `beforeSwap(...)`: Pre-swap validation and event emission
- `afterSwap(...)`: Post-swap fee calculation and event emission

### PoolSettlementVault

**Key Features:**
- Ordered deposits: Asset must be deposited before EURC
- Settlement automation: Opens when USDC requirement met
- Timeout protection: Automatic reversal after deadline

**Main Functions:**
- `createVault(...)`: Create new vault instance
- `depositAsset(bytes32)`: Seller deposits asset
- `depositEURC(bytes32, uint256)`: Client deposits EURC
- `recordUSDCReceived(bytes32, uint256)`: Record swap output
- `openVault(bytes32)`: Settle and distribute assets
- `timeoutVault(bytes32)`: Reverse expired vault

### Facilitator

**Key Features:**
- Pool integration: Direct PoolManager interaction
- Swap types: Vault-integrated and simple swaps
- Slippage protection: Configurable minimum output

**Main Functions:**
- `setPoolKey(...)`: Configure pool parameters
- `facilitatedSwap(...)`: Execute vault-integrated swap
- `simpleSwap(...)`: Execute standalone swap

## 🔧 Configuration

### Hook Permissions

The hook implements these Uniswap v4 hooks:
- ✅ beforeInitialize
- ✅ afterInitialize
- ✅ beforeAddLiquidity
- ✅ beforeRemoveLiquidity
- ✅ beforeSwap
- ✅ afterSwap
- ✅ beforeDonate
- ✅ afterDonate

### Fee Configuration

Default fee: 0.3% (30 basis points)
Max fee: 10% (1000 basis points)

Update via:
```solidity
hook.setFeeRate(30); // 0.3%
```

## 📚 Project Structure

```
P03-Pool/
├── src/
│   ├── FacilitatorHook.sol      # Uniswap v4 hook
│   ├── PoolSettlementVault.sol  # Asset settlement vault
│   └── Facilitator.sol          # Swap orchestrator
├── script/
│   ├── Deploy.s.sol             # Deployment script
│   ├── InitializePool.s.sol     # Pool initialization
│   ├── AddLiquidity.s.sol       # Liquidity provision
│   └── ExecuteSwap.s.sol        # Swap execution
├── test/
│   ├── FacilitatorHook.t.sol    # Hook tests
│   └── PoolSettlementVault.t.sol # Vault tests
├── python/
│   ├── facilitator_client.py    # Python swap client
│   ├── tracker.py               # Event tracker
│   └── requirements.txt         # Python dependencies
├── foundry.toml                 # Foundry configuration
├── .env.example                 # Environment template
└── README.md                    # This file
```

## 🛣️ Happy Path Flow

1. **Vault Creation**
   ```solidity
   vault.createVault(vaultId, client, seller, asset, ...);
   ```

2. **Asset Deposit** (Seller)
   ```solidity
   assetToken.approve(vault, amount);
   vault.depositAsset(vaultId);
   ```

3. **EURC Deposit** (Client)
   ```solidity
   eurcToken.approve(vault, amount);
   vault.depositEURC(vaultId, amount);
   ```

4. **Facilitated Swap** (Owner/Facilitator)
   ```solidity
   facilitator.facilitatedSwap(vaultId, eurc, usdc, amount, minOut, true);
   ```

5. **Record USDC**
   ```solidity
   vault.recordUSDCReceived(vaultId, usdcAmount);
   ```

6. **Open Vault** (Anyone)
   ```solidity
   vault.openVault(vaultId);
   // → Asset to client
   // → USDC to seller
   // → Residual EURC to seller
   ```

## 🚨 Error Handling

### Common Errors

**Hook Errors:**
- `UnauthorizedCaller`: Swap not initiated by authorized facilitator
- `InvalidVault`: Vault address is zero
- `InvalidFeeRate`: Fee exceeds 10%

**Vault Errors:**
- `InvalidStatus`: Operation not allowed in current vault state
- `Unauthorized`: Caller not authorized for operation
- `DeadlinePassed`: Operation attempted after deadline
- `NotTimedOut`: Timeout called before deadline

**Facilitator Errors:**
- `PoolKeyNotSet`: Pool not configured
- `InvalidAmount`: Zero or negative amount
- `SlippageTooHigh`: Output below minimum
- `SwapFailed`: Swap execution failed

## 🔐 Security Considerations

1. **Authorization**: Only whitelisted facilitators can execute swaps
2. **Reentrancy Protection**: All external calls protected
3. **Slippage Protection**: Minimum output validation
4. **Timeout Protection**: Automatic reversal for expired vaults
5. **Deposit Ordering**: Asset must be deposited before EURC

## 🤝 Contributing

This is a project for ETH Global Buenos Aires 2025. For issues or improvements, please create an issue or pull request.

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- Uniswap v4 team for the hooks framework
- Polygon team for Amoy testnet
- Foundry team for development tools

## 📞 Support

For questions or issues:
- GitHub Issues: [Create an issue]
- Documentation: See inline code comments
- Examples: Check `script/` directory

---

**Built for ETH Global Buenos Aires 2025** 🇦🇷
