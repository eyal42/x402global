# P02 — x402 + EIP-2612 OTC API for On-Chain Assets

A complete implementation of an **HTTP 402-based OTC API** that uses **x402 protocol** and **EIP-2612 gasless approvals** to sell on-chain assets (yield-bearing pool tokens) via HTTP requests, settling payments in **MockEURC** and **MockUSDC** on **Polygon Amoy**.

---

## 🎯 Overview

This project demonstrates:
- **HTTP 402 (Payment Required)** responses with structured payment requirements
- **EIP-2612 gasless approvals** (permit) for token transfers without spending gas
- **On-chain asset trading** via HTTP API
- **Simulated DEX swaps** (EURC → USDC conversion)
- **Real-time event tracking** for observability
- **Complete settlement flow** with escrow and asset release

---

## 🏗️ Architecture

### Smart Contracts

1. **YieldPoolShare** (`src/YieldPoolShare.sol`)
   - ERC-20 token representing yield-bearing pool shares
   - The on-chain asset being sold via the OTC API
   - 18 decimals

2. **SettlementVault** (`src/SettlementVault.sol`)
   - Core contract coordinating the x402 payment flow
   - Handles EIP-2612 permit consumption and fund pulling
   - Manages order lifecycle and asset settlement
   - Escrows assets and releases them upon payment completion

3. **SwapSimulator** (`src/SwapSimulator.sol`)
   - Simulates EURC → USDC conversion without a real liquidity pool
   - Uses configurable exchange rates
   - Emits events for swap initiation and fulfillment

### Python Components

1. **Server** (`python/server/server.py`)
   - Flask HTTP server exposing `/buy-asset` endpoint
   - Returns HTTP 402 with payment requirements on first request
   - Processes EIP-2612 permit signatures from X-PAYMENT header
   - Orchestrates on-chain settlement flow

2. **Client** (`python/client/client.py`)
   - Makes x402 payment requests
   - Signs EIP-2612 permits (gasless approvals)
   - Queries EUR/USD exchange rates
   - Retries request with payment proof

3. **Event Tracker** (`python/tracker/tracker.py`)
   - Real-time monitoring of on-chain events
   - Beautiful CLI progress display
   - Historical event queries
   - Order status tracking

---

## 📋 Prerequisites

### Foundry (Solidity)
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Python 3.8+
```bash
python3 --version
```

### Environment Setup
1. Copy `env.example` to `.env`
2. Fill in all required values:
   - Private keys
   - RPC URL for Polygon Amoy
   - Mock token addresses from P01 deployment
   - Contract addresses (after deployment)

---

## 🚀 Quick Start

### 1. Deploy Contracts

First, ensure MockEURC and MockUSDC are deployed (from P01 project) and add their addresses to `.env`.

```bash
# Compile contracts
forge build

# Deploy all contracts
forge script script/DeployAll.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast

# Save the deployed addresses to .env:
# YPS_ADDRESS=<YieldPoolShare address>
# SWAP_SIMULATOR_ADDRESS=<SwapSimulator address>
# SETTLEMENT_VAULT_ADDRESS=<SettlementVault address>
```

### 2. Setup Python Environment

```bash
cd python
bash setup.sh
source venv/bin/activate
```

### 3. Mint Test Tokens

Mint MockEURC tokens to your client address using P01 scripts:

```bash
cd ../P01-Mock_Tokens
forge script script/MintTokens.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### 4. Run the Demo

#### Terminal 1: Start Event Tracker
```bash
cd python
source venv/bin/activate
python tracker/tracker.py --mode watch
```

#### Terminal 2: Start Server
```bash
cd python
source venv/bin/activate
python server/server.py
```

#### Terminal 3: Make a Purchase
```bash
cd python
source venv/bin/activate
python client/client.py --amount 1.0
```

---

## 🔄 Protocol Flow

### Step-by-Step Process

1. **Client Request (HTTP 402)**
   ```
   GET /buy-asset?client=0x...&amount=1.0
   → 402 Payment Required
   ```
   
   Response includes:
   - Order ID
   - Required USDC amount
   - Payment deadline
   - Asset details
   - EIP-2612 instructions

2. **Client Signs Permit**
   - Queries EUR/USD exchange rate
   - Calculates max EURC payment
   - Signs EIP-712 permit message (off-chain, gasless)
   - Creates X-PAYMENT header with signature

3. **Client Retries with Payment**
   ```
   GET /buy-asset?client=0x...&amount=1.0
   X-PAYMENT: {"order_id": "...", "permit_signature": {...}}
   → 200 OK (on success)
   ```

4. **Server Processes Payment**
   - Consumes permit signature
   - Pulls EURC from client using `permit()` + `transferFrom()`
   - Initiates swap simulation (EURC → USDC)
   - Completes settlement in vault
   - Releases YPS tokens to client
   - Sends refund if surplus exists

5. **Events Emitted** (visible in tracker)
   - 💳 PaymentRequested
   - ✍️ PermitConsumed
   - 💰 FundsPulled
   - 🔄 SwapCompleted
   - 🏦 VaultFunded
   - ✅ AssetReleased
   - 💸 RefundSent (if applicable)

---

## 📁 Project Structure

```
P02-x402/
├── src/
│   ├── YieldPoolShare.sol          # On-chain asset token
│   ├── SettlementVault.sol         # Core x402 settlement logic
│   └── SwapSimulator.sol           # EURC→USDC conversion simulator
│
├── script/
│   ├── DeployAll.s.sol             # Deploy all contracts
│   ├── DeployYieldPoolShare.s.sol  # Deploy YPS token
│   ├── DeploySwapSimulator.s.sol   # Deploy simulator
│   ├── DeploySettlementVault.s.sol # Deploy vault
│   └── SetupDemo.s.sol             # Setup demo environment
│
├── python/
│   ├── common/
│   │   ├── config.py               # Configuration management
│   │   └── contracts.py            # Contract ABIs and helpers
│   │
│   ├── server/
│   │   └── server.py               # HTTP 402 server
│   │
│   ├── client/
│   │   └── client.py               # x402 client
│   │
│   ├── tracker/
│   │   └── tracker.py              # Real-time event tracker
│   │
│   ├── requirements.txt            # Python dependencies
│   ├── setup.sh                    # Setup script
│   ├── run_demo.sh                 # Demo runner
│   └── utils.py                    # Utility functions
│
├── test/
│   └── (tests go here)
│
├── prompt/
│   └── p02.md                      # Project specification
│
├── env.example                     # Environment template
├── foundry.toml                    # Foundry configuration
└── README.md                       # This file
```

---

## 🔧 Configuration

### Environment Variables

See `env.example` for all configuration options:

| Variable | Description | Example |
|----------|-------------|---------|
| `RPC_URL` | Polygon Amoy RPC | `https://rpc-amoy.polygon.technology` |
| `CHAIN_ID` | Chain ID | `80002` |
| `PRIVATE_KEY` | Server/deployer private key | `0x...` |
| `CLIENT_PRIVATE_KEY` | Client private key | `0x...` |
| `MOCK_EURC_ADDRESS_POLYGON` | MockEURC address | `0x...` |
| `MOCK_USDC_ADDRESS_POLYGON` | MockUSDC address | `0x...` |
| `YPS_ADDRESS` | YieldPoolShare address | `0x...` |
| `SWAP_SIMULATOR_ADDRESS` | SwapSimulator address | `0x...` |
| `SETTLEMENT_VAULT_ADDRESS` | SettlementVault address | `0x...` |
| `ASSET_PRICE_USDC` | Price per YPS in USDC | `100000000` (100 USDC) |
| `DEFAULT_EUR_USD_RATE` | EUR/USD exchange rate | `1.05` |

---

## 🎮 Usage Examples

### Check Balances

```bash
python python/utils.py balances --address 0xYourAddress
```

### Check Vault Balances

```bash
python python/utils.py vault-balances
```

### Buy Custom Amount

```bash
python python/client/client.py --amount 5.0
```

### Track Historical Events

```bash
python python/tracker/tracker.py --mode historical --from-block 12345678
```

### Custom Server URL

```bash
python python/client/client.py --server http://custom-server:5000 --amount 1.0
```

---

## 🧪 Testing

Run Foundry tests:

```bash
forge test
```

Run with verbosity:

```bash
forge test -vvv
```

Test specific contract:

```bash
forge test --match-contract SettlementVaultTest
```

---

## 📊 Contract Interactions

### Deploy Contracts
```bash
forge script script/DeployAll.s.sol --rpc-url $RPC_URL --broadcast
```

### Setup Demo Environment
```bash
forge script script/SetupDemo.s.sol --rpc-url $RPC_URL --broadcast
```

### Query Contract State
```bash
# Get order details
cast call $SETTLEMENT_VAULT_ADDRESS "getOrder(bytes32)" <order_id> --rpc-url $RPC_URL

# Check YPS balance of vault
cast call $YPS_ADDRESS "balanceOf(address)" $SETTLEMENT_VAULT_ADDRESS --rpc-url $RPC_URL
```

---

## 🔍 Event Monitoring

The event tracker monitors these key events:

| Event | Description | Triggered By |
|-------|-------------|--------------|
| `PaymentRequested` | Payment request created | Server (HTTP 402 response) |
| `PermitConsumed` | EIP-2612 permit consumed | Server (permit signature validation) |
| `FundsPulled` | Funds pulled from client | Vault (transferFrom after permit) |
| `SwapCompleted` | Swap simulation finished | SwapSimulator |
| `VaultFunded` | Vault credited with settlement tokens | Vault (after swap) |
| `AssetReleased` | Asset transferred to client | Vault (final step) |
| `RefundSent` | Surplus payment refunded | Vault (if applicable) |

---

## 🛠️ Development

### Add New Features

1. **Custom Asset Tokens**: Replace YieldPoolShare with any ERC-20 token
2. **Real DEX Integration**: Replace SwapSimulator with Uniswap V3/V4
3. **Multi-Asset Support**: Extend vault to handle multiple asset types
4. **Price Oracles**: Integrate Chainlink for real-time pricing

### Extend the API

Add new endpoints to `server/server.py`:

```python
@app.route('/list-assets', methods=['GET'])
def list_assets():
    # Return available assets
    pass

@app.route('/quote', methods=['GET'])
def get_quote():
    # Get price quote without creating order
    pass
```

---

## 🚨 Security Considerations

⚠️ **This is a demo project for Polygon Amoy testnet only!**

For production use, consider:

1. **Slippage Protection**: Add minimum output checks for swaps
2. **Deadline Validation**: Enforce strict deadlines on permits
3. **Reentrancy Guards**: Already implemented, but audit thoroughly
4. **Access Control**: Add role-based permissions for admin functions
5. **Rate Limiting**: Implement rate limits on HTTP endpoints
6. **Signature Verification**: Add additional signature checks
7. **Oracle Validation**: Use decentralized price oracles
8. **Audit**: Get professional smart contract audit

---

## 📚 Resources

### x402 Protocol
- HTTP 402 Status Code: [RFC 7231](https://tools.ietf.org/html/rfc7231#section-6.5.2)
- x402 Specification: Custom implementation for crypto payments

### EIP-2612 (Permit)
- [EIP-2612](https://eips.ethereum.org/EIPS/eip-2612): Permit Extension for ERC-20
- [EIP-712](https://eips.ethereum.org/EIPS/eip-712): Typed Structured Data Hashing

### Tools
- [Foundry Book](https://book.getfoundry.sh/)
- [Web3.py Docs](https://web3py.readthedocs.io/)
- [Flask Docs](https://flask.palletsprojects.com/)

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

---

## 📝 License

MIT License - see LICENSE file for details

---

## 🎯 Deliverables Checklist

- ✅ **Smart Contracts**
  - ✅ YieldPoolShare (on-chain asset)
  - ✅ SettlementVault (x402 + EIP-2612 logic)
  - ✅ SwapSimulator (EURC→USDC conversion)

- ✅ **Deployment Scripts**
  - ✅ Individual contract deployment
  - ✅ Complete system deployment
  - ✅ Demo setup script

- ✅ **Python Components**
  - ✅ HTTP 402 server with `/buy-asset` endpoint
  - ✅ Client with EIP-2612 signing
  - ✅ Real-time event tracker
  - ✅ Utility functions

- ✅ **Documentation**
  - ✅ Comprehensive README
  - ✅ Environment configuration
  - ✅ Usage examples
  - ✅ Architecture overview

- ✅ **Observability**
  - ✅ On-chain events for all steps
  - ✅ Real-time event tracker
  - ✅ Beautiful CLI output

---

## 🎉 Demo Walkthrough

### Full End-to-End Flow

1. **Setup** (one-time)
   ```bash
   # Deploy contracts
   forge script script/DeployAll.s.sol --rpc-url $RPC_URL --broadcast
   
   # Mint client tokens
   cd ../P01-Mock_Tokens
   forge script script/MintTokens.s.sol --rpc-url $RPC_URL --broadcast
   cd ../P02-x402
   
   # Setup Python
   cd python && bash setup.sh && source venv/bin/activate
   ```

2. **Run Demo**
   ```bash
   # Terminal 1: Event tracker
   python tracker/tracker.py --mode watch
   
   # Terminal 2: Server
   python server/server.py
   
   # Terminal 3: Client
   python client/client.py --amount 1.0
   ```

3. **Watch the Magic** ✨
   - Server receives request, creates order on-chain
   - Returns HTTP 402 with payment requirements
   - Client signs EIP-2612 permit (gasless!)
   - Client retries with permit in X-PAYMENT header
   - Server processes permit, pulls EURC
   - Swap simulator converts EURC → USDC
   - Vault settles and releases YPS tokens
   - Event tracker shows real-time progress
   - Client receives asset!

---

## 📞 Support

For issues or questions:
1. Check the [prompt specification](prompt/p02.md)
2. Review this README
3. Check contract comments in `src/`
4. Look at Python docstrings

---

**Built for ETH Global Buenos Aires 2025** 🇦🇷
