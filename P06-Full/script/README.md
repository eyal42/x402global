# Deployment and Interaction Scripts

This directory contains Foundry scripts for deploying and interacting with the OTC API contracts.

## Prerequisites

1. Install Foundry: `curl -L https://foundry.paradigm.xyz | bash && foundryup`
2. Copy `env.example` to `.env` and fill in your values
3. Ensure you have MATIC tokens on Polygon Amoy for gas

## Deployment

Deploy all contracts to Polygon Amoy:

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

This will deploy:
- `YieldPoolShare` - Asset token with EIP-2612
- `SettlementVault` - Escrow and settlement logic
- `PermitPuller` - Permit consumption and fund pulling
- `FacilitatorHook` - Uniswap V4 swap integration

Deployed addresses will be saved to `deployed_addresses.txt`.

## Interaction Scripts

### Mint Test Tokens

Mint YieldPoolShares to seller and prepare for testing:

```bash
forge script script/Interact.s.sol:Interact \
  --sig "mintTestTokens()" \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast \
  -vvvv
```

### Create Test Settlement

Create a test settlement between buyer and seller:

```bash
forge script script/Interact.s.sol:Interact \
  --sig "createTestSettlement()" \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --broadcast \
  -vvvv
```

## Testing Locally

Run tests with:

```bash
forge test -vvv
```

Run specific test:

```bash
forge test --match-test testSettlementFlow -vvvv
```

## Verification

If automatic verification fails, verify manually:

```bash
forge verify-contract \
  --chain-id 80002 \
  --compiler-version 0.8.28 \
  --constructor-args $(cast abi-encode "constructor(address)" "DEPLOYER_ADDRESS") \
  DEPLOYED_ADDRESS \
  src/YieldPoolShare.sol:YieldPoolShare
```

