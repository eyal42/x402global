# Setup Guide

This guide will walk you through setting up and deploying the Uniswap v4 hook-enabled liquidity pool system.

## Prerequisites

Before you begin, ensure you have:

1. **Foundry Installed**
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Python 3.8+** (for Python tools)
   ```bash
   python3 --version
   ```

3. **Polygon Amoy Testnet**
   - RPC URL: `https://rpc-amoy.polygon.technology/`
   - Faucet: https://faucet.polygon.technology/
   - Block Explorer: https://amoy.polygonscan.com/

4. **Test Tokens**
   - Deployed MockEURC and MockUSDC (from P01-Mock_Tokens)
   - Or deploy your own ERC20 tokens

## Step-by-Step Setup

### 1. Environment Configuration

Create a `.env` file in the project root with the following variables:

```bash
# Copy from the README and fill in your values
POLYGON_AMOY_RPC_URL=https://rpc-amoy.polygon.technology/
PRIVATE_KEY=your_private_key_without_0x
DEPLOYER_ADDRESS=0xYourAddress

# Uniswap v4 addresses (these must be deployed on Amoy first)
POOL_MANAGER_ADDRESS=0x...
SWAP_ROUTER_ADDRESS=0x...
LIQUIDITY_ROUTER_ADDRESS=0x...

# Token addresses
MOCK_EURC_ADDRESS_POLYGON=0x...
MOCK_USDC_ADDRESS_POLYGON=0x...
```

**Important Security Notes:**
- Never commit your `.env` file
- Use a test wallet with test funds only
- Keep your private key secure

### 2. Install Dependencies

```bash
# Install Foundry dependencies
forge install

# Build contracts to verify everything works
forge build
```

Expected output:
```
Compiling 39 files with Solc 0.8.28
Solc 0.8.28 finished in X.XXs
Compiler run successful
```

### 3. Get Test Funds

You'll need MATIC on Polygon Amoy for gas fees:

1. Visit https://faucet.polygon.technology/
2. Select "Polygon Amoy" network
3. Enter your address
4. Claim test MATIC

### 4. Get Test Tokens

If you don't have MockEURC and MockUSDC yet:

**Option A: Use Existing Deployment**
- Get the addresses from the P01-Mock_Tokens deployment
- Have the admin grant you minting privileges
- Mint tokens to your address

**Option B: Deploy Your Own**
```bash
cd ../P01-Mock_Tokens
forge script script/Deploy.s.sol --rpc-url $POLYGON_AMOY_RPC_URL --broadcast
```

### 5. Mint Test Tokens

You'll need tokens for:
- Adding liquidity (e.g., 10,000 of each)
- Testing swaps (e.g., 1,000 of each)

Example with admin access:
```solidity
// Mint 20,000 MockEURC
mockEURC.mint(yourAddress, 20000 * 10**6);

// Mint 20,000 MockUSDC
mockUSDC.mint(yourAddress, 20000 * 10**6);
```

### 6. Deploy Uniswap v4 (If Not Already Deployed)

**Important**: Uniswap v4 must be deployed on Polygon Amoy first.

Check if it's already deployed:
- Search for "Uniswap v4" on https://amoy.polygonscan.com/
- Check Uniswap's official documentation

If not deployed, you'll need to:
1. Clone the v4-core repository
2. Deploy PoolManager
3. Deploy test routers (PoolSwapTest, PoolModifyLiquidityTest)
4. Update your `.env` with the addresses

### 7. Deploy Pool System

```bash
# Deploy hook, vault, and facilitator
forge script script/Deploy.s.sol \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast \
  --verify

# Check deployed_addresses.env for the addresses
cat deployed_addresses.env
```

**Important**: Copy the deployed addresses to your `.env` file:
```bash
HOOK_ADDRESS=0x...
VAULT_ADDRESS=0x...
FACILITATOR_ADDRESS=0x...
```

### 8. Initialize Pool

```bash
forge script script/InitializePool.s.sol \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast
```

This creates the EURC/USDC pool with:
- 0.3% fee tier
- Hook attached
- Initial 1:1 price

### 9. Add Liquidity

```bash
# Make sure you have approved the tokens first
forge script script/AddLiquidity.s.sol \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast
```

This adds:
- 10,000 MockEURC
- 10,000 MockUSDC
- Full range position

### 10. Test the System

```bash
# Execute a test swap
forge script script/ExecuteSwap.s.sol \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast
```

## Python Tools Setup

### 1. Install Python Dependencies

```bash
cd python
pip install -r requirements.txt
```

### 2. Test Python Client

```bash
# Execute a swap
python facilitator_client.py \
  --amount-in 10 \
  --token-in EURC \
  --token-out USDC \
  --slippage 5
```

### 3. Run Event Tracker

```bash
# Monitor events in real-time
python tracker.py --output status.json
```

Open a new terminal and execute swaps to see events appear!

## Troubleshooting

### Common Issues

**Issue: "Failed to connect to RPC"**
- Check your RPC URL is correct
- Try a different RPC endpoint
- Ensure you have internet connectivity

**Issue: "Insufficient balance"**
- Ensure you have enough MATIC for gas
- Mint more test tokens
- Check token balances with a block explorer

**Issue: "Pool not initialized"**
- Run the InitializePool script first
- Verify the pool was created successfully
- Check the pool exists in PoolManager

**Issue: "Unauthorized caller"**
- Ensure the facilitator is authorized in the hook
- Check the deployment script completed successfully
- Verify addresses in your `.env` match deployed contracts

**Issue: "Slippage too high"**
- Increase slippage tolerance
- Check pool has sufficient liquidity
- Try smaller swap amounts

### Getting Help

1. **Check Logs**: Use `-vvvv` flag for detailed Foundry output
   ```bash
   forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast -vvvv
   ```

2. **Verify Contracts**: Check contracts on Polygonscan
   ```bash
   # Verification is automatic with --verify flag
   # Or manually verify at: https://amoy.polygonscan.com/verifyContract
   ```

3. **Test Locally**: Use Foundry's local testing
   ```bash
   forge test -vv
   ```

4. **Check Balances**: Use cast commands
   ```bash
   cast balance $YOUR_ADDRESS --rpc-url $RPC_URL
   cast call $TOKEN_ADDRESS "balanceOf(address)(uint256)" $YOUR_ADDRESS --rpc-url $RPC_URL
   ```

## Next Steps

After successful deployment:

1. **Test Different Scenarios**
   - Small swaps
   - Large swaps
   - Both directions (EURC→USDC and USDC→EURC)

2. **Monitor Events**
   - Use the Python tracker
   - Watch transactions on Polygonscan

3. **Integrate with Frontend**
   - Use the Python client as reference
   - Build a web interface using web3.js or ethers.js

4. **Add More Liquidity**
   - Run AddLiquidity script with different amounts
   - Try concentrated liquidity positions

## Production Checklist

Before using in production:

- [ ] Full security audit
- [ ] Comprehensive test coverage
- [ ] Mainnet deployment plan
- [ ] Emergency pause mechanism
- [ ] Monitoring and alerting
- [ ] Documentation for users
- [ ] Legal review
- [ ] Insurance consideration

## Resources

- [Uniswap v4 Docs](https://docs.uniswap.org/contracts/v4/overview)
- [Foundry Book](https://book.getfoundry.sh/)
- [Polygon Docs](https://docs.polygon.technology/)
- [Web3.py Docs](https://web3py.readthedocs.io/)

---

**Need Help?** Create an issue on GitHub or check the README.md for more details.

