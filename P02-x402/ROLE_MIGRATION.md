# Role Separation Migration Guide

## ✅ What Changed

The system now clearly separates three distinct roles with dedicated configuration:

### Before (v1.0)
```bash
# Old .env format
PRIVATE_KEY=0xabc...              # Ambiguous: server or client?
CLIENT_PRIVATE_KEY=0xdef...       # Only client was separated
```

### After (v1.1)
```bash
# New .env format - Clear role separation

# FACILITATOR: Runs server, pays gas, orchestrates transactions
FACILITATOR_PRIVATE_KEY=0xabc...
FACILITATOR_ADDRESS=0x111...

# SELLER: Provides assets, receives payments
SELLER_PRIVATE_KEY=0xdef...
SELLER_ADDRESS=0x222...

# CLIENT: Buys assets, signs permits (gasless)
CLIENT_PRIVATE_KEY=0xghi...
CLIENT_ADDRESS=0x333...
```

---

## 🎯 Why This Change?

### Problems with Old Approach
1. **Ambiguous naming** - "PRIVATE_KEY" could mean anything
2. **Mixed roles** - Server = Seller was assumed
3. **Limited flexibility** - Can't separate facilitator from seller
4. **Unclear responsibilities** - Who does what?

### Benefits of New Approach
1. ✅ **Crystal clear** - Each role explicitly defined
2. ✅ **Flexible** - Facilitator ≠ Seller if needed
3. ✅ **Secure** - Role isolation improves security
4. ✅ **Scalable** - Easy to add multiple sellers/clients
5. ✅ **Professional** - Matches real-world patterns

---

## 📝 Migration Steps

### Step 1: Update .env File

**Option A: Keep Same Account for All Roles (Demo)**
```bash
# Use your existing PRIVATE_KEY for all roles
FACILITATOR_PRIVATE_KEY=0xYourExistingKey
FACILITATOR_ADDRESS=0xYourExistingAddress

SELLER_PRIVATE_KEY=0xYourExistingKey
SELLER_ADDRESS=0xYourExistingAddress

CLIENT_PRIVATE_KEY=0xYourExistingClientKey
CLIENT_ADDRESS=0xYourClientAddress
```

**Option B: Separate Accounts (Production)**
```bash
# Three different accounts
FACILITATOR_PRIVATE_KEY=0xServerOperatorKey
FACILITATOR_ADDRESS=0xServerOperatorAddress

SELLER_PRIVATE_KEY=0xAssetProviderKey
SELLER_ADDRESS=0xAssetProviderAddress

CLIENT_PRIVATE_KEY=0xBuyerKey
CLIENT_ADDRESS=0xBuyerAddress
```

### Step 2: Update Contract Deployment

✅ **Updated!** All deployment scripts now use `FACILITATOR_PRIVATE_KEY` instead of `PRIVATE_KEY`.

When deploying:
```bash
forge script script/DeployAll.s.sol \
  --rpc-url $RPC_URL \
  --private-key $FACILITATOR_PRIVATE_KEY \
  --broadcast
```

The facilitator account will own all contracts (SettlementVault, SwapSimulator, YieldPoolShare).

### Step 3: Test the System

```bash
# Test server
python python/server/server.py

# Should show:
# Facilitator (Server): 0x...
# Seller (Asset Provider): 0x...

# Test client
python python/client/client.py --amount 1.0

# Should show:
# Client Address: 0x...
# Role: Buyer (pays EURC, receives YPS)
```

---

## 🔍 What Changed in Each File

### 1. `env.example`
```diff
- # Private Keys
- PRIVATE_KEY=your_private_key_here
- CLIENT_PRIVATE_KEY=your_client_private_key_here

+ # ============ Role Separation ============
+ # 1. FACILITATOR (Server/Orchestrator)
+ FACILITATOR_PRIVATE_KEY=your_facilitator_private_key_here
+ FACILITATOR_ADDRESS=your_facilitator_address_here
+
+ # 2. SELLER (Asset Provider)
+ SELLER_PRIVATE_KEY=your_seller_private_key_here
+ SELLER_ADDRESS=your_seller_address_here
+
+ # 3. CLIENT (Buyer)
+ CLIENT_PRIVATE_KEY=your_client_private_key_here
+ CLIENT_ADDRESS=your_client_address_here
```

### 2. `python/common/config.py`
```diff
- SERVER_PRIVATE_KEY = os.getenv("PRIVATE_KEY")
- CLIENT_PRIVATE_KEY = os.getenv("CLIENT_PRIVATE_KEY", os.getenv("PRIVATE_KEY"))

+ # FACILITATOR (Server/Orchestrator)
+ FACILITATOR_PRIVATE_KEY = os.getenv("FACILITATOR_PRIVATE_KEY")
+ FACILITATOR_ADDRESS = os.getenv("FACILITATOR_ADDRESS")
+
+ # SELLER (Asset Provider)
+ SELLER_PRIVATE_KEY = os.getenv("SELLER_PRIVATE_KEY")
+ SELLER_ADDRESS = os.getenv("SELLER_ADDRESS")
+
+ # CLIENT (Buyer)
+ CLIENT_PRIVATE_KEY = os.getenv("CLIENT_PRIVATE_KEY")
+ CLIENT_ADDRESS = os.getenv("CLIENT_ADDRESS")
```

### 3. `python/server/server.py`
```diff
- account = Account.from_key(Config.SERVER_PRIVATE_KEY)
- print(f"Server address: {account.address}")

+ facilitator_account = Account.from_key(Config.FACILITATOR_PRIVATE_KEY)
+ print(f"Facilitator (Server): {Config.FACILITATOR_ADDRESS}")
+ print(f"Seller (Asset Provider): {Config.SELLER_ADDRESS}")
```

```diff
- account.address,  # seller
+ Web3.to_checksum_address(Config.SELLER_ADDRESS),  # seller
```

### 4. `python/client/client.py`
```diff
- def __init__(self, server_url: str, private_key: str):
+ def __init__(self, server_url: str, private_key: str = None, client_address: str = None):
+     if private_key:
+         self.account = Account.from_key(private_key)
+     else:
+         self.account = Account.from_key(Config.CLIENT_PRIVATE_KEY)
```

---

## 🧪 Testing Checklist

- [ ] Copy `env.example` to `.env`
- [ ] Fill in all 6 new variables
- [ ] Server starts without errors
- [ ] Server shows facilitator and seller addresses
- [ ] Client connects successfully
- [ ] Client shows correct address
- [ ] Full purchase flow works end-to-end
- [ ] Events tracked correctly

---

## 🐛 Troubleshooting

### Error: "Missing required configuration: FACILITATOR_PRIVATE_KEY"
**Solution:** Update your `.env` file with the new variable names

### Error: "Configuration error: Missing SELLER_ADDRESS"
**Solution:** Add `SELLER_ADDRESS` to `.env` (can be same as facilitator)

### Error: "Configuration error: Missing CLIENT_ADDRESS"
**Solution:** Add `CLIENT_ADDRESS` to `.env`

### Server works but orders fail
**Problem:** Vault not owned by facilitator address
**Solution:** Redeploy contracts with facilitator account

---

## 💡 Quick Start Example

### Fastest Migration (Same Account)

1. **Find your existing key:**
```bash
# From your old .env
OLD_KEY=0xabc123...
OLD_ADDRESS=0x111...
```

2. **Create new .env:**
```bash
cat > .env << EOF
RPC_URL=https://rpc-amoy.polygon.technology
CHAIN_ID=80002

# Use same account for all roles (quick demo)
FACILITATOR_PRIVATE_KEY=$OLD_KEY
FACILITATOR_ADDRESS=$OLD_ADDRESS
SELLER_PRIVATE_KEY=$OLD_KEY
SELLER_ADDRESS=$OLD_ADDRESS
CLIENT_PRIVATE_KEY=$OLD_KEY
CLIENT_ADDRESS=$OLD_ADDRESS

# Your existing contract addresses
MOCK_EURC_ADDRESS_POLYGON=0x...
MOCK_USDC_ADDRESS_POLYGON=0x...
YPS_ADDRESS=0x...
SWAP_SIMULATOR_ADDRESS=0x...
SETTLEMENT_VAULT_ADDRESS=0x...
EOF
```

3. **Test:**
```bash
python python/server/server.py
# Should start successfully
```

---

## 📚 Related Documentation

- **[ROLES.md](ROLES.md)** - Complete guide to the three roles
- **[CHANGELOG.md](CHANGELOG.md)** - Version history
- **[README.md](README.md)** - Main documentation
- **[QUICKSTART.md](QUICKSTART.md)** - Quick setup guide

---

## ❓ FAQ

### Q: Do I need three different accounts?
**A:** No! For testing/demo, use the same account for all three roles. For production, separate accounts are recommended.

### Q: What if I use the same address for facilitator and seller?
**A:** That's fine! The facilitator can also be the seller (common pattern).

### Q: Does the client need MATIC for gas?
**A:** No! Clients use EIP-2612 gasless permits. Only the facilitator pays gas.

### Q: Can I have multiple clients?
**A:** Yes! Each client has their own private key. The server can handle multiple clients.

### Q: What about my old contracts?
**A:** If they were deployed with your old key, make sure `FACILITATOR_ADDRESS` matches that key's address.

---

## ✅ Verification

After migration, verify everything works:

```bash
# Check server
python python/server/server.py
# Look for:
# ✅ Facilitator (Server): 0x...
# ✅ Seller (Asset Provider): 0x...
# ✅ Server listening on...

# Check client
python python/client/client.py --amount 0.1
# Look for:
# ✅ Client Address: 0x...
# ✅ Requesting 0.1 YPS tokens
# ✅ Purchase successful
```

---

**Migration complete! Your system now has clear role separation.** 🎉

For questions, see [ROLES.md](ROLES.md) or [README.md](README.md).

