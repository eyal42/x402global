# OTC API for On-Chain Assets (Polygon Amoy)

A complete implementation of an Over-The-Counter (OTC) API system using **x402** payment negotiation and **EIP-2612 gasless approvals** to sell on-chain assets (yield-bearing tokens) via HTTP, settling payments in **MockEURC** and **MockUSDC** on **Polygon Amoy**.

## 🎯 Overview

This project demonstrates:
- **HTTP 402 (x402)** - Payment Required protocol for web-based asset trading
- **EIP-2612** - Gasless permit signatures for token approvals
- **Uniswap V4 Integration** - Automated MockEURC → MockUSDC conversion
- **Finality Monitoring** - Wait for block finality before settlement
- **Real-time Tracking** - Web UI for monitoring settlement progress

## 🏗️ Architecture

### Smart Contracts

1. **YieldPoolShare** (`src/YieldPoolShare.sol`)
   - ERC-20 token with EIP-2612 permit support
   - Represents yield-bearing assets being sold
   - 18 decimals

2. **SettlementVault** (`src/SettlementVault.sol`)
   - Escrows MockEURC, MockUSDC, and asset tokens
   - Manages settlement lifecycle and state
   - Enforces finality checks before distribution

3. **PermitPuller** (`src/PermitPuller.sol`)
   - Consumes EIP-2612 permits from buyer and seller
   - Pulls funds atomically in one transaction
   - Transfers to SettlementVault

4. **FacilitatorHook** (`src/FacilitatorHook.sol`)
   - Integrates with Uniswap V4 for token swaps
   - Validates swap output meets minimum requirements
   - Handles residual token refunds

### Off-Chain Components

1. **HTTP Server** (`python/server.py`)
   - Seller-side API exposing `/buy-asset` endpoint
   - Returns HTTP 402 with payment requirements
   - Creates settlements on-chain

2. **HTTP Client** (`python/client.py`)
   - Buyer-side client for purchasing assets
   - Queries EUR/USD rates
   - Creates EIP-2612 permit signatures
   - Submits payment proofs

3. **Facilitator** (`python/facilitator.py`)
   - Monitors on-chain events
   - Executes swaps via Uniswap V4
   - Waits for block finality
   - Executes final settlement

4. **Event Tracker** (`python/tracker.py`)
   - Real-time web UI dashboard
   - Visualizes settlement progress
   - Displays events and status

## 🔄 Protocol Flow

```
┌─────────┐                 ┌─────────┐                 ┌─────────────┐                 ┌──────────┐
│  Client │                 │  Server │                 │ Facilitator │                 │  Vault   │
│ (Buyer) │                 │(Seller) │                 │ (Off-chain) │                 │(On-chain)│
└────┬────┘                 └────┬────┘                 └──────┬──────┘                 └────┬─────┘
     │                           │                              │                             │
     │ 1. GET /buy-asset         │                              │                             │
     │──────────────────────────>│                              │                             │
     │                           │                              │                             │
     │ 2. HTTP 402 (Payment Req) │                              │                             │
     │<──────────────────────────│                              │                             │
     │                           │                              │                             │
     │ 3. Query EUR/USD rate     │                              │                             │
     │────────────────────>      │                              │                             │
     │                           │                              │                             │
     │ 4. Create EIP-2612 permit │                              │                             │
     │                           │                              │                             │
     │ 5. GET /buy-asset + permit│                              │                             │
     │──────────────────────────>│                              │                             │
     │                           │ 6. Create settlement          │                             │
     │                           │─────────────────────────────────────────────────────────>│
     │                           │                              │                             │
     │                           │                              │ 7. Detect SettlementCreated │
     │                           │                              │<────────────────────────────│
     │                           │                              │                             │
     │                           │                              │ 8. Pull funds (PermitPuller)│
     │                           │                              │─────────────────────────────>│
     │                           │                              │                             │
     │                           │                              │ 9. Execute swap (Uniswap V4)│
     │                           │                              │─────────────────────────────>│
     │                           │                              │                             │
     │                           │                              │ 10. Wait for finality       │
     │                           │                              │                             │
     │                           │                              │ 11. Execute settlement       │
     │                           │                              │─────────────────────────────>│
     │                           │                              │                             │
     │ 12. Receive assets        │                              │                             │
     │<──────────────────────────────────────────────────────────────────────────────────────│
```

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Python 3.8+
- Node.js (optional, for frontend enhancements)
- MATIC tokens on Polygon Amoy (for gas)

### 1. Clone and Setup

```bash
# Install Foundry dependencies
forge install

# Install Python dependencies
cd python
pip install -r requirements.txt
cd ..
```

### 2. Configure Environment

```bash
# Copy example environment file
cp env.example .env

# Edit .env with your values
# - Private keys for seller, buyer, facilitator
# - MockUSDC and MockEURC addresses
# - RPC URL for Polygon Amoy
```

### 3. Deploy Contracts

```bash
# Deploy all contracts to Polygon Amoy
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast \
  --verify \
  -vvvv

# Addresses will be saved to deployed_addresses.txt
# Update .env with deployed addresses
```

### 4. Mint Test Tokens

```bash
# Mint YieldPoolShares to seller
forge script script/Interact.s.sol:Interact \
  --sig "mintTestTokens()" \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast

# Ensure buyer has MockEURC tokens (from P01-Mock_Tokens project)
```

### 5. Run the System

Open 4 terminals:

```bash
# Terminal 1: Event Tracker with Web UI
cd python
python tracker.py
# Open http://localhost:5000

# Terminal 2: OTC Server (Seller)
python server.py

# Terminal 3: Facilitator
python facilitator.py

# Terminal 4: Client (Buyer) - Purchase 100 YPS tokens
python client.py 100000000000000000000
```

## 📋 Key Features

### ✅ HTTP 402 (x402) Protocol
- Standard HTTP status code for payment requirements
- JSON-based payment requirement objects
- Base64-encoded payment proofs in headers

### ✅ EIP-2612 Gasless Approvals
- No prior approval transactions needed
- EIP-712 typed signature for permits
- Atomic permit + transferFrom in single transaction

### ✅ Uniswap V4 Integration
- Custom facilitator hook for swap validation
- Automatic MockEURC → MockUSDC conversion
- Slippage protection and output validation

### ✅ Finality Monitoring
- Configurable confirmation requirements
- Block-based finality checks
- Safe settlement only after finality

### ✅ Real-Time Tracking
- Beautiful web dashboard
- Live event streaming
- Settlement progress visualization

## 📁 Project Structure

```
P06-Full/
├── src/                          # Solidity contracts
│   ├── YieldPoolShare.sol        # Asset token (ERC-20 + EIP-2612)
│   ├── SettlementVault.sol       # Escrow and settlement logic
│   ├── PermitPuller.sol          # Permit consumption and fund pulling
│   └── FacilitatorHook.sol       # Uniswap V4 swap integration
├── script/                       # Foundry scripts
│   ├── Deploy.s.sol              # Deployment script
│   ├── Interact.s.sol            # Interaction scripts
│   └── README.md                 # Script documentation
├── python/                       # Python components
│   ├── server.py                 # HTTP server (seller)
│   ├── client.py                 # HTTP client (buyer)
│   ├── facilitator.py            # Off-chain facilitator
│   ├── tracker.py                # Event tracker with web UI
│   ├── web3_utils.py             # Web3 utilities
│   ├── x402_types.py             # x402 protocol types
│   ├── config.py                 # Configuration
│   ├── requirements.txt          # Python dependencies
│   └── README.md                 # Python documentation
├── test/                         # Solidity tests
├── foundry.toml                  # Foundry configuration
├── env.example                   # Example environment variables
└── README.md                     # This file
```

## 🔧 Configuration

### Environment Variables

| Variable | Description |
|----------|-------------|
| `POLYGON_AMOY_RPC_URL` | Polygon Amoy RPC endpoint |
| `MOCK_USDC_ADDRESS_POLYGON` | MockUSDC contract address |
| `MOCK_EURC_ADDRESS_POLYGON` | MockEURC contract address |
| `YIELD_POOL_SHARE_ADDRESS` | YieldPoolShare contract address |
| `SETTLEMENT_VAULT_ADDRESS` | SettlementVault contract address |
| `PERMIT_PULLER_ADDRESS` | PermitPuller contract address |
| `FACILITATOR_HOOK_ADDRESS` | FacilitatorHook contract address |
| `SELLER_PRIVATE_KEY` | Seller's private key |
| `BUYER_PRIVATE_KEY` | Buyer's private key |
| `PRIVATE_KEY` | Facilitator's private key |
| `FINALITY_CONFIRMATIONS` | Number of block confirmations (default: 10) |
| `HTTP_SERVER_PORT` | Server port (default: 8402) |

## 🧪 Testing

### Run Solidity Tests

```bash
forge test -vvv
```

### Manual End-to-End Test

1. Deploy contracts
2. Start tracker, server, facilitator
3. Run client to purchase assets
4. Monitor progress in tracker UI
5. Verify settlement completion on-chain

### Test Scenarios

- **Happy Path**: Successful asset purchase with swap and settlement
- **Insufficient Payment**: Client provides too little EURC
- **Swap Failure**: Insufficient liquidity or excessive slippage
- **Finality Wait**: Settlement delayed until block finality

## 🎨 Event Tracker UI

The event tracker provides a real-time dashboard showing:

- **Active Settlements**: Visual cards with progress bars
- **Recent Events**: Live event stream
- **Statistics**: Total settlements, events, current block
- **Status Indicators**: Color-coded settlement states

Access at: http://localhost:5000

## 🤝 Roles

### Client (Buyer)
- Wants to purchase on-chain assets
- Pays in MockEURC
- Creates EIP-2612 permits
- No gas costs for approval

### Server (Seller)
- Owns YieldPoolShare assets
- Prices assets in MockUSDC internally
- Exposes HTTP 402 API
- Creates settlements on-chain

### Facilitator
- Orchestrates settlement process
- Consumes permits and pulls funds
- Executes swaps via Uniswap V4
- Monitors finality
- Distributes assets and payments

## 🔐 Security Considerations

- **Permit Expiry**: All permits have deadlines
- **Finality Checks**: Settlements wait for block finality
- **Slippage Protection**: Maximum EURC budget enforced
- **Output Validation**: Swap output must meet minimum USDC
- **Access Control**: Only facilitator can execute settlements

## 📚 References

- [EIP-2612: Permit Extension for ERC-20](https://eips.ethereum.org/EIPS/eip-2612)
- [HTTP 402 Payment Required](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/402)
- [Uniswap V4 Documentation](https://docs.uniswap.org/contracts/v4/overview)
- [Polygon Amoy Testnet](https://polygon.technology/blog/introducing-the-amoy-testnet-for-polygon-pos)

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

Built for ETH Global Buenos Aires 2025

- Uses OpenZeppelin contracts for secure ERC-20 implementation
- Integrates with Uniswap V4 for decentralized swaps
- Implements x402 protocol for HTTP-based asset trading

## 🐛 Known Issues & Future Work

- [ ] Full Uniswap V4 hook implementation (currently simplified)
- [ ] Enhanced slippage calculation based on pool liquidity
- [ ] Multi-asset support beyond YieldPoolShare
- [ ] WebSocket support for real-time client updates
- [ ] Gas optimization for contract interactions
- [ ] Comprehensive test coverage
- [ ] Production-ready error handling

## 📞 Support

For issues, questions, or contributions, please open an issue on GitHub.

---

**Happy Trading! 🚀**
