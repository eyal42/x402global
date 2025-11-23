# Demo Instructions for OTC API System

This guide walks you through a complete demo of the OTC API system for ETH Global Buenos Aires 2025.

## 🎬 Pre-Demo Setup (Do this before presenting)

### 1. Environment Setup

```bash
# Copy and configure environment
cp env.example .env

# Edit .env with your values:
# - POLYGON_AMOY_RPC_URL
# - Private keys (seller, buyer, facilitator)
# - Mock token addresses
```

### 2. Deploy Contracts

```bash
# Deploy all contracts
make deploy

# Or manually:
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast \
  --verify \
  -vvvv

# Copy deployed addresses to .env
cat deployed_addresses.txt >> .env
```

### 3. Fund Accounts

```bash
# Ensure seller has YieldPoolShares
make mint

# Ensure buyer has MockEURC tokens
# (Use the P01-Mock_Tokens minter)
```

## 🚀 Live Demo Flow

### Setup: Open 4 Terminals

```
┌─────────────────────┬─────────────────────┐
│   Terminal 1        │   Terminal 2        │
│   Event Tracker     │   OTC Server        │
│   (localhost:5000)  │   (port 8402)       │
├─────────────────────┼─────────────────────┤
│   Terminal 3        │   Terminal 4        │
│   Facilitator       │   Client (Buyer)    │
│   (monitors chain)  │   (initiates tx)    │
└─────────────────────┴─────────────────────┘
```

### Step 1: Start Event Tracker (Terminal 1)

```bash
cd P06-Full
make tracker

# Or:
cd python
python tracker.py
```

**Show audience:**
- Open browser to http://localhost:5000
- Display the dashboard on screen
- Explain the UI components:
  - Statistics panel (settlements, events, block number)
  - Active Settlements panel
  - Recent Events panel

### Step 2: Start OTC Server (Terminal 2)

```bash
cd P06-Full
make server

# Or:
cd python
python server.py
```

**Explain to audience:**
- This is the seller's HTTP server
- Exposes `/buy-asset` endpoint
- Implements HTTP 402 (x402) protocol
- Prices assets in MockUSDC

### Step 3: Start Facilitator (Terminal 3)

```bash
cd P06-Full
make facilitator

# Or:
cd python
python facilitator.py
```

**Explain to audience:**
- Off-chain orchestrator
- Monitors blockchain events
- Executes swaps via Uniswap V4
- Waits for finality before settlement
- Distributes assets and payments

### Step 4: Run Client Purchase (Terminal 4)

```bash
cd P06-Full

# Purchase 100 YPS tokens (100 * 10^18)
make client AMOUNT=100000000000000000000

# Or:
cd python
python client.py 100000000000000000000
```

**Walk through the flow:**

1. **Initial Request (402)**
   - Show terminal output: client requests payment requirements
   - Server responds with HTTP 402
   - Explain payment requirement object

2. **EUR/USD Rate Query**
   - Client queries external API for exchange rate
   - Calculates max EURC budget
   - Show the calculation logic

3. **EIP-2612 Permit**
   - Client creates gasless approval signature
   - No separate approval transaction needed
   - Explain EIP-712 typed signatures

4. **Payment Submission**
   - Client sends request with X-PAYMENT header
   - Server creates settlement on-chain
   - Show settlement ID

5. **Watch Event Tracker UI**
   - Point to the dashboard
   - Show "SettlementCreated" event appearing
   - Watch settlement card appear in "Active Settlements"

6. **Facilitator Actions**
   - Terminal 3 shows "FundsPulled" event
   - Facilitator executes swap
   - Show "SwapCompleted" event
   - Show "VaultFunded" event

7. **Finality Wait**
   - Explain block finality on Polygon
   - Show countdown in terminal
   - Highlight security importance

8. **Final Settlement**
   - Show "FinalityConfirmed" event
   - Facilitator executes settlement
   - Show "SettlementExecuted" event
   - Settlement status changes to "settled" in UI

## 🎯 Key Demo Points to Emphasize

### 1. HTTP 402 Protocol (x402)
- Standard HTTP status code
- Machine-readable payment requirements
- Web-native payment negotiation

### 2. EIP-2612 Gasless Approvals
- No separate approval transaction
- Better UX (one transaction instead of two)
- EIP-712 signatures

### 3. Automatic Conversion
- Client pays in EUR (MockEURC)
- Seller receives USD (MockUSDC)
- Uniswap V4 handles conversion transparently

### 4. Finality Guarantees
- Settlement waits for block finality
- Protects against reorgs
- Production-ready safety

### 5. Real-Time Observability
- Beautiful web dashboard
- Live event streaming
- Clear progress indicators

## 🎨 Demo Tips

### Visual Flow
1. **Start with architecture diagram** on slides
2. **Show code** for key components (server, client)
3. **Run live demo** with all 4 terminals visible
4. **Highlight web UI** for visual impact

### Talking Points
- "This solves the UX problem of crypto payments on the web"
- "Users don't need to approve first, then pay - just sign once"
- "Currency conversion happens automatically in the background"
- "We wait for finality, so there's no risk of reorgs"

### Common Questions

**Q: Why HTTP 402 instead of wallet connect?**
A: HTTP 402 is a web standard, works with any HTTP client, enables programmatic access, better for APIs and integrations.

**Q: What about MEV/frontrunning?**
A: Permits have deadlines, amounts are maximum limits, settlement is atomic.

**Q: Why wait for finality?**
A: Polygon can have reorgs, we wait for checkpoint finality to ensure settlement is irreversible.

**Q: How does this compare to regular DEX?**
A: This is OTC (over-the-counter), meant for larger trades, negotiated prices, HTTP-accessible, server-mediated.

## 🐛 Troubleshooting

### Terminal 1 (Tracker) Issues
- Port 5000 busy: Change in config.py or use different port
- No events showing: Check RPC connection

### Terminal 2 (Server) Issues
- Port 8402 busy: Change HTTP_SERVER_PORT in .env
- Settlement creation fails: Check contract addresses in .env

### Terminal 3 (Facilitator) Issues
- Not detecting events: Check FACILITATOR_PRIVATE_KEY
- Swap fails: Check MockEURC/MockUSDC liquidity

### Terminal 4 (Client) Issues
- Insufficient MockEURC: Mint more from P01-Mock_Tokens
- Permit signature fails: Check BUYER_PRIVATE_KEY

## 📊 Success Metrics to Show

After successful demo:
1. Settlement completed (check UI)
2. Assets transferred to buyer (check balance on Polygonscan)
3. USDC transferred to seller (check balance)
4. Residual EURC refunded (if any)
5. All events logged in tracker

## 🎓 Learning Outcomes

Audience should understand:
- HTTP 402 as a payment protocol standard
- EIP-2612 gasless approvals
- On-chain settlement with finality
- Real-world blockchain integration
- Production-grade event monitoring

## 🏆 Hackathon Judging Points

Highlight:
- ✅ Novel use of HTTP 402 for blockchain payments
- ✅ Excellent UX (no prior approvals needed)
- ✅ Production-ready (finality checks, error handling)
- ✅ Beautiful UI for observability
- ✅ Complete end-to-end implementation
- ✅ Well-documented and tested

---

**Good luck with your demo! 🚀**

