# Quick Start Guide - x402 OTC API

This guide will get you up and running with the x402 OTC API in under 10 minutes.

---

## Prerequisites Checklist

- [ ] Foundry installed (`foundryup`)
- [ ] Python 3.8+ installed
- [ ] Access to Polygon Amoy testnet
- [ ] Private key with some MATIC for gas
- [ ] MockEURC and MockUSDC deployed (from P01 project)

---

## 5-Minute Setup

### Step 1: Clone and Configure (2 minutes)

```bash
# Navigate to project
cd P02-x402

# Copy environment template
cp env.example .env

# Edit .env with your values
nano .env
```

Required `.env` values:
```bash
PRIVATE_KEY=your_private_key_here
RPC_URL=https://rpc-amoy.polygon.technology
MOCK_EURC_ADDRESS_POLYGON=0x...  # From P01
MOCK_USDC_ADDRESS_POLYGON=0x...  # From P01
```

### Step 2: Deploy Contracts (2 minutes)

```bash
# Install dependencies
forge install

# Deploy all contracts
forge script script/DeployAll.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

**Important:** Save the deployed addresses and add them to `.env`:
```bash
YPS_ADDRESS=0x...
SWAP_SIMULATOR_ADDRESS=0x...
SETTLEMENT_VAULT_ADDRESS=0x...
```

### Step 3: Setup Python (1 minute)

```bash
cd python
bash setup.sh
source venv/bin/activate
```

---

## Run the Demo (3 terminals)

### Terminal 1: Event Tracker
```bash
cd python
source venv/bin/activate
python tracker/tracker.py --mode watch
```

### Terminal 2: Server
```bash
cd python
source venv/bin/activate
python server/server.py
```

### Terminal 3: Client
```bash
cd python
source venv/bin/activate

# First, mint some MockEURC tokens to your address
# (Use P01 project scripts)

# Then make a purchase
python client/client.py --amount 1.0
```

---

## What You'll See

1. **Terminal 1 (Tracker)** shows real-time events:
   ```
   💳 Payment Requested - Order: abc123...
   ✍️  Permit Signed & Consumed - Order: abc123...
   💰 Funds Pulled - Order: abc123...
   🔄 Swap Completed - Order: abc123...
   🏦 Vault Funded - Order: abc123...
   ✅ Asset Released - Order: abc123...
   ```

2. **Terminal 2 (Server)** logs HTTP requests and transaction hashes

3. **Terminal 3 (Client)** shows the purchase flow step-by-step

---

## Troubleshooting

### "Insufficient balance"
Mint MockEURC tokens to your client address:
```bash
cd ../P01-Mock_Tokens
forge script script/MintTokens.s.sol --rpc-url $RPC_URL --broadcast
```

### "Configuration error"
Make sure all addresses in `.env` are filled in correctly.

### "Connection refused"
Check that the server is running on the correct port (default: 5000).

### "Transaction reverted"
Check that:
- You have enough MATIC for gas
- Contract addresses in `.env` are correct
- Vault has YPS tokens to sell

---

## Next Steps

- Read the [full README](README.md) for detailed documentation
- Check out the [prompt specification](prompt/p02.md)
- Explore the smart contracts in `src/`
- Customize the pricing in `.env`
- Try buying different amounts
- Modify the exchange rate in SwapSimulator

---

## Key Endpoints

### Server API

- `GET /buy-asset?client=0x...&amount=1.0` - Buy assets (x402 flow)
- `GET /status/<order_id>` - Check order status
- `GET /health` - Health check

### Example Request

```bash
# First request (returns 402)
curl "http://localhost:5000/buy-asset?client=0xYourAddress&amount=1.0"

# Returns payment requirements
# Client signs permit off-chain
# Retry with X-PAYMENT header (handled by client.py)
```

---

## Architecture at a Glance

```
Client                    Server                    Blockchain
  |                         |                           |
  |--GET /buy-asset-------->|                           |
  |<------402 Payment-------|                           |
  |     Requirements        |                           |
  |                         |                           |
  | Sign EIP-2612 Permit    |                           |
  | (off-chain, gasless)    |                           |
  |                         |                           |
  |--GET with X-PAYMENT---->|                           |
  |                         |--createPaymentRequest---->|
  |                         |--pullPaymentWithPermit--->|
  |                         |--instantSwap------------->|
  |                         |--completeSwapAndSettle--->|
  |                         |--releaseAsset------------>|
  |<------200 OK + Asset----|                           |
  |                         |                           |
```

---

## Support

If you get stuck:
1. Check `.env` configuration
2. Verify contract deployments
3. Check you have test tokens
4. Review server logs for errors
5. Check event tracker for on-chain activity

---

**Ready to build?** Start with Step 1! 🚀

