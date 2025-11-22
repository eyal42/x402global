# Role Separation Guide - x402 OTC API

This document explains the three distinct roles in the x402 OTC API system and how to configure them.

---

## 🎭 Three Distinct Roles

The system separates concerns into three independent roles, each with their own address and private key:

### 1. 👨‍💼 FACILITATOR (Server/Orchestrator)

**Purpose:** Runs the HTTP server and orchestrates all on-chain transactions

**Responsibilities:**
- Runs the Flask HTTP server
- Owns the `SettlementVault` contract
- Creates payment requests on-chain
- Consumes EIP-2612 permits
- Pulls funds from clients
- Orchestrates swap simulations
- Completes settlements
- Releases assets to clients
- **Pays gas for all operations**

**Environment Variables:**
```bash
FACILITATOR_PRIVATE_KEY=0x...
FACILITATOR_ADDRESS=0x...
```

**Used By:**
- `python/server/server.py` - HTTP server
- **All deployment scripts** - `script/DeployAll.s.sol`, `script/Deploy*.s.sol`
- Contract ownership and configuration

**Account Requirements:**
- Must have MATIC for gas fees
- Should be the owner of SettlementVault contract
- Does NOT need MockEURC or MockUSDC tokens

---

### 2. 🏪 SELLER (Asset Provider)

**Purpose:** Provides the on-chain assets and receives payment

**Responsibilities:**
- Provides YPS tokens (stored in vault)
- Receives MockUSDC settlement tokens
- Can withdraw settled funds from vault
- **Does NOT sign transactions** (passive role)

**Environment Variables:**
```bash
SELLER_PRIVATE_KEY=0x...  # Optional, only if seller wants to withdraw
SELLER_ADDRESS=0x...      # Required
```

**Used By:**
- `python/server/server.py` - Specified in createPaymentRequest
- Seller can use scripts to withdraw settled funds

**Account Requirements:**
- Address must be specified for settlement
- Private key only needed for withdrawals
- Receives MockUSDC from completed sales

---

### 3. 🛒 CLIENT (Buyer)

**Purpose:** Buys on-chain assets

**Responsibilities:**
- Requests asset purchases via HTTP
- Signs EIP-2612 permits (off-chain, gasless)
- Provides MockEURC for payment
- Receives YPS tokens
- **Does NOT pay gas** (uses permits)

**Environment Variables:**
```bash
CLIENT_PRIVATE_KEY=0x...
CLIENT_ADDRESS=0x...
```

**Used By:**
- `python/client/client.py` - HTTP client

**Account Requirements:**
- Must have MockEURC tokens for payment
- Does NOT need MATIC (gasless permits)
- Will receive YPS tokens after purchase

---

## 🔧 Configuration Example

### Scenario 1: Three Separate Accounts (Recommended for Production)

```bash
# .env file

# Facilitator (Server operator)
FACILITATOR_PRIVATE_KEY=0xabc123...
FACILITATOR_ADDRESS=0x1111111111111111111111111111111111111111

# Seller (Asset provider)
SELLER_PRIVATE_KEY=0xdef456...  # Optional
SELLER_ADDRESS=0x2222222222222222222222222222222222222222

# Client (Buyer)
CLIENT_PRIVATE_KEY=0xghi789...
CLIENT_ADDRESS=0x3333333333333333333333333333333333333333
```

### Scenario 2: Development/Demo (One Account)

For testing, you can use the same account for all roles:

```bash
# .env file

# Single account for all roles (demo only)
FACILITATOR_PRIVATE_KEY=0xabc123...
FACILITATOR_ADDRESS=0x1111111111111111111111111111111111111111

SELLER_PRIVATE_KEY=0xabc123...
SELLER_ADDRESS=0x1111111111111111111111111111111111111111

CLIENT_PRIVATE_KEY=0xabc123...
CLIENT_ADDRESS=0x1111111111111111111111111111111111111111
```

### Scenario 3: Facilitator = Seller (Common Pattern)

The facilitator also acts as the seller:

```bash
# .env file

# Facilitator is also the seller
FACILITATOR_PRIVATE_KEY=0xabc123...
FACILITATOR_ADDRESS=0x1111111111111111111111111111111111111111

SELLER_PRIVATE_KEY=0xabc123...
SELLER_ADDRESS=0x1111111111111111111111111111111111111111

# Separate client
CLIENT_PRIVATE_KEY=0xdef456...
CLIENT_ADDRESS=0x2222222222222222222222222222222222222222
```

---

## 💰 Token & Gas Requirements

### Facilitator Account Needs:
- ✅ **MATIC** - For gas fees (all transactions)
- ❌ MockEURC - Not needed
- ❌ MockUSDC - Not needed
- ❌ YPS - Not needed (held by vault)

### Seller Account Needs:
- ❌ MATIC - Not needed (doesn't sign transactions)
- ❌ MockEURC - Not needed
- ✅ **MockUSDC** - Will receive from sales
- ✅ **YPS** - Must have tokens in vault to sell

### Client Account Needs:
- ❌ MATIC - Not needed (gasless permits!)
- ✅ **MockEURC** - For payment
- ❌ MockUSDC - Not needed
- ✅ **YPS** - Will receive from purchases

---

## 🔄 Transaction Flow with Roles

```
1. CLIENT sends HTTP request to FACILITATOR's server
   └─> GET /buy-asset?amount=1.0

2. FACILITATOR creates order on-chain (pays gas)
   └─> Specifies CLIENT as buyer, SELLER as recipient
   └─> Returns HTTP 402 to CLIENT

3. CLIENT signs EIP-2612 permit (off-chain, no gas)
   └─> Authorizes vault to pull MockEURC
   └─> Sends X-PAYMENT header to FACILITATOR

4. FACILITATOR pulls payment from CLIENT (pays gas)
   └─> Uses CLIENT's permit signature
   └─> Pulls MockEURC from CLIENT to vault

5. FACILITATOR simulates swap (pays gas)
   └─> EURC → USDC conversion

6. FACILITATOR completes settlement (pays gas)
   └─> Credits MockUSDC to SELLER
   └─> Releases YPS to CLIENT
   └─> Refunds surplus to CLIENT if any

7. SELLER can withdraw MockUSDC from vault (pays own gas)
```

---

## 🛠️ Setup Steps

### Step 1: Generate Addresses

```bash
# Generate three new accounts (or use existing)
# You can use MetaMask, cast, or any wallet tool

# Example using cast:
cast wallet new  # For facilitator
cast wallet new  # For seller
cast wallet new  # For client
```

### Step 2: Configure .env

```bash
cp env.example .env
nano .env

# Fill in all 6 variables:
# FACILITATOR_PRIVATE_KEY
# FACILITATOR_ADDRESS
# SELLER_PRIVATE_KEY (optional)
# SELLER_ADDRESS
# CLIENT_PRIVATE_KEY
# CLIENT_ADDRESS
```

### Step 3: Fund Accounts

```bash
# Facilitator needs MATIC
# Get from: https://faucet.polygon.technology/

# Client needs MockEURC
# Use P01 scripts to mint:
cd ../P01-Mock_Tokens
forge script script/MintTokens.s.sol \
  --rpc-url $RPC_URL \
  --private-key $FACILITATOR_PRIVATE_KEY \
  --broadcast
```

### Step 4: Deploy Contracts

```bash
# Deploy with facilitator account
forge script script/DeployAll.s.sol \
  --rpc-url $RPC_URL \
  --private-key $FACILITATOR_PRIVATE_KEY \
  --broadcast

# This deploys:
# - YieldPoolShare
# - SwapSimulator  
# - SettlementVault (owned by facilitator)
# - Mints YPS to vault (ready to sell)
```

### Step 5: Run the System

```bash
# Terminal 1: Event Tracker
python python/tracker/tracker.py --mode watch

# Terminal 2: Server (Facilitator)
python python/server/server.py

# Terminal 3: Client (Buyer)
python python/client/client.py --amount 1.0
```

---

## 🔍 Verification

### Check Role Configuration

```bash
# Check facilitator
cast balance $FACILITATOR_ADDRESS --rpc-url $RPC_URL

# Check seller's vault balance (settled USDC)
cast call $SETTLEMENT_VAULT_ADDRESS \
  "sellerBalances(address)(uint256)" \
  $SELLER_ADDRESS \
  --rpc-url $RPC_URL

# Check client's MockEURC
cast call $MOCK_EURC_ADDRESS \
  "balanceOf(address)(uint256)" \
  $CLIENT_ADDRESS \
  --rpc-url $RPC_URL

# Check client's YPS
cast call $YPS_ADDRESS \
  "balanceOf(address)(uint256)" \
  $CLIENT_ADDRESS \
  --rpc-url $RPC_URL
```

---

## 🎯 Common Patterns

### Pattern 1: Marketplace (Recommended)
- **Facilitator:** Platform operator
- **Seller:** Asset provider (individual/protocol)
- **Client:** End user buyer

### Pattern 2: DEX-style
- **Facilitator:** Protocol/DAO
- **Seller:** Liquidity provider
- **Client:** Trader

### Pattern 3: Integrated Service
- **Facilitator:** Service provider
- **Seller:** Same as facilitator
- **Client:** End user

---

## ⚠️ Security Notes

### Private Key Security
- **Never commit private keys to git**
- Use `.env` files (gitignored)
- Consider using hardware wallets for mainnet
- Use separate accounts for each role

### Role Isolation Benefits
1. **Separation of Concerns:** Each role has specific responsibilities
2. **Security:** Compromised client key doesn't affect server
3. **Accounting:** Clear separation of funds
4. **Scaling:** Can have multiple sellers/clients
5. **Compliance:** Clear audit trail per role

### Gas Management
- Only facilitator pays gas
- Clients use gasless permits (EIP-2612)
- Sellers don't sign transactions (except withdrawals)

---

## 📚 Code References

### Where Roles Are Used

**Facilitator:**
- `python/server/server.py` - All transaction signing
- `script/DeployAll.s.sol` - Contract deployment

**Seller:**
- `python/server/server.py:createPaymentRequest()` - Specified as recipient
- `src/SettlementVault.sol:sellerWithdraw()` - Withdrawal function

**Client:**
- `python/client/client.py` - All client operations
- `src/SettlementVault.sol` - Specified in orders

---

## 🔧 Troubleshooting

### "Missing required configuration"
Make sure all 6 environment variables are set in `.env`

### "Insufficient funds"
- **Facilitator:** Get MATIC from faucet
- **Client:** Mint MockEURC using P01 scripts
- **Seller:** YPS tokens should be in vault

### "Transaction reverted"
- Check facilitator is vault owner
- Verify client has approved amount
- Check seller address is valid

### Role Verification
```python
# In Python script
from python.common.config import Config

print(f"Facilitator: {Config.FACILITATOR_ADDRESS}")
print(f"Seller: {Config.SELLER_ADDRESS}")
print(f"Client: {Config.CLIENT_ADDRESS}")
```

---

## ✅ Checklist

- [ ] Three addresses generated/identified
- [ ] All 6 env variables set in `.env`
- [ ] Facilitator has MATIC for gas
- [ ] Client has MockEURC tokens
- [ ] Contracts deployed by facilitator
- [ ] YPS tokens minted to vault
- [ ] Server runs without errors
- [ ] Client can make purchases

---

**For more information, see [README.md](README.md) and [ARCHITECTURE.md](ARCHITECTURE.md)**

