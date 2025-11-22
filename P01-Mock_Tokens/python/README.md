# Python Utilities for Mock Tokens

This directory contains Python utilities for interacting with the MockUSDC and MockEURC token contracts.

## Setup

1. Install Python dependencies:
```bash
pip install -r ../requirements.txt
```

2. Create a `.env` file in the project root with your configuration:
```bash
# RPC endpoint
RPC_URL=http://127.0.0.1:8545

# Private key (without 0x prefix or with it)
PRIVATE_KEY=your_private_key_here

# Contract addresses (set after deployment)
USDC_ADDRESS=0x...
EURC_ADDRESS=0x...
```

## Available Scripts

### balance.py
Check native and token balances for an address.

```bash
# Check balances for an address
python balance.py 0x1234...

# With custom RPC
python balance.py 0x1234... --rpc http://localhost:8545
```

### mint_burn.py
Mint and burn token operations.

```bash
# Mint tokens
python mint_burn.py --token 0xToken... mint 0xRecipient... 1000.0

# Burn tokens
python mint_burn.py --token 0xToken... burn 100.0

# Check balance
python mint_burn.py --token 0xToken... balance 0xAddress...

# Check minter status
python mint_burn.py --token 0xToken... status 0xMinter...
```

### blacklist.py
Blacklist management operations.

```bash
# Check blacklist status
python blacklist.py --token 0xToken... check 0xAddress...

# Add to blacklist
python blacklist.py --token 0xToken... add 0xAddress...

# Remove from blacklist
python blacklist.py --token 0xToken... remove 0xAddress...

# Wipe blacklisted balance
python blacklist.py --token 0xToken... wipe 0xAddress...
```

## Configuration Module

The `config.py` module provides shared utilities:

- `get_web3(rpc_url)` - Get Web3 instance
- `get_account(private_key)` - Get account from private key
- `load_abi(contract_name)` - Load contract ABI from Foundry output
- `get_contract(w3, contract_name, address)` - Get contract instance
- `send_transaction(w3, account, tx)` - Send transaction and wait for receipt
- `format_amount(amount)` - Format token amount for display (with 6 decimals)
- `parse_amount(amount_str)` - Parse token amount from string
- `print_receipt_info(receipt)` - Print transaction receipt information

### Role Constants

```python
from config import DEFAULT_ADMIN_ROLE, MASTER_MINTER_ROLE, MINTER_ROLE, BRIDGE_ROLE
```

## Examples

### Complete Workflow

```bash
# 1. Check balances
python balance.py 0xYourAddress

# 2. Check minter status
python mint_burn.py --token $USDC_ADDRESS status 0xYourAddress

# 3. Mint tokens
python mint_burn.py --token $USDC_ADDRESS mint 0xRecipient 1000.0

# 4. Check new balance
python mint_burn.py --token $USDC_ADDRESS balance 0xRecipient

# 5. Check blacklist
python blacklist.py --token $USDC_ADDRESS check 0xSomeAddress

# 6. Add to blacklist
python blacklist.py --token $USDC_ADDRESS add 0xBadActor
```

## Notes

- All token amounts use 6 decimals (e.g., 1000.0 = 1000000000 in contract units)
- Private keys can be provided via `--private-key` flag or `PRIVATE_KEY` environment variable
- RPC URLs can be provided via `--rpc` flag or `RPC_URL` environment variable
- Transaction receipts are automatically printed with gas used and block number
- Scripts will automatically estimate gas if not provided

