# Troubleshooting Guide

## Issue: Empty Revert Error When Minting Tokens

When you see `Error: script failed: <empty revert data>`, it usually means one of these:

### 1. Contracts Not Actually Deployed

The deployment might have simulated successfully but didn't broadcast to the network.

**Check if contracts exist:**

```bash
forge script script/Verify.s.sol:Verify --rpc-url $POLYGON_AMOY_RPC_URL
```

If code size is 0, contracts aren't deployed. Redeploy with:

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast \
  --legacy \
  -vvvv
```

### 2. EIP-3855 (PUSH0) Not Supported

The warning says:
```
Warning: EIP-3855 is not supported in one or more of the RPCs used.
```

**Solution:** Use `--legacy` flag or downgrade Solidity to 0.8.19:

```bash
# Option A: Use legacy transactions
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast \
  --legacy \
  -vvvv

# Option B: Downgrade Solidity (edit foundry.toml)
solc_version = "0.8.19"
```

### 3. Not Enough Gas or MATIC

Check your deployer balance:

```bash
cast balance $YOUR_ADDRESS --rpc-url $POLYGON_AMOY_RPC_URL
```

Get testnet MATIC from: https://faucet.polygon.technology/

### 4. Wrong Network Configuration

Verify your RPC URL:

```bash
echo $POLYGON_AMOY_RPC_URL
```

Should be: `https://rpc-amoy.polygon.technology/`

## Step-by-Step Fix

### Step 1: Check Current State

```bash
# Load environment
source .env

# Verify contracts exist
forge script script/Verify.s.sol:Verify --rpc-url $POLYGON_AMOY_RPC_URL
```

### Step 2: Redeploy if Needed (Use Legacy)

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast \
  --legacy \
  -vvvv
```

**Note:** Remove `--verify` initially. Verify contracts separately after deployment succeeds.

### Step 3: Update Addresses

```bash
# Addresses will be in the output, update your .env
cat deployed_addresses.txt >> .env
source .env
```

### Step 4: Mint Test Tokens

```bash
forge script script/Interact.s.sol:Interact \
  --sig "mintTestTokens()" \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast \
  --legacy \
  -vvvv
```

## Common Fixes

### Fix 1: Use Legacy Transactions

Always add `--legacy` flag for Polygon Amoy:

```bash
# In your commands
--broadcast --legacy
```

### Fix 2: Downgrade Solidity

Edit `foundry.toml`:

```toml
[profile.default]
solc_version = "0.8.19"  # Instead of 0.8.28
```

Then rebuild:

```bash
forge clean
forge build
```

### Fix 3: Manual Contract Verification

After successful deployment:

```bash
forge verify-contract \
  --chain-id 80002 \
  --compiler-version 0.8.28 \
  --constructor-args $(cast abi-encode "constructor(address)" "$YOUR_ADDRESS") \
  $YIELD_POOL_SHARE_ADDRESS \
  src/YieldPoolShare.sol:YieldPoolShare \
  --etherscan-api-key $POLYGONSCAN_API_KEY
```

## Quick Command Reference

```bash
# 1. Source environment
source .env

# 2. Check balance
cast balance $(cast wallet address --private-key $PRIVATE_KEY) --rpc-url $POLYGON_AMOY_RPC_URL

# 3. Verify contracts exist
forge script script/Verify.s.sol:Verify --rpc-url $POLYGON_AMOY_RPC_URL

# 4. Deploy (use --legacy!)
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast \
  --legacy \
  -vvvv

# 5. Mint tokens (use --legacy!)
forge script script/Interact.s.sol:Interact \
  --sig "mintTestTokens()" \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast \
  --legacy \
  -vvvv
```

## Still Having Issues?

### Check Transaction on Explorer

1. Go to: https://amoy.polygonscan.com/
2. Search for your deployer address
3. Check if transactions were actually sent
4. Look for failed transactions and error messages

### Enable More Verbose Output

```bash
forge script ... -vvvvv  # 5 v's for maximum verbosity
```

### Check Contract at Address

```bash
cast code $YIELD_POOL_SHARE_ADDRESS --rpc-url $POLYGON_AMOY_RPC_URL
```

If it returns `0x`, the contract isn't deployed.

## Success Checklist

- [ ] RPC URL is correct
- [ ] Have enough MATIC for gas
- [ ] Environment variables loaded (`source .env`)
- [ ] Used `--legacy` flag for deployment
- [ ] Contracts have code at addresses (verified with `Verify.s.sol`)
- [ ] Updated `.env` with deployed addresses
- [ ] Minting works without errors

## Need Help?

Check the logs carefully. The most common issue is **forgetting --legacy flag** on Polygon Amoy!

