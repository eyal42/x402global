#!/usr/bin/env python3
"""
Setup a minter for a token on a specific blockchain
"""

import argparse
import os
from web3 import Web3
from config import (
    get_web3, get_account, get_contract, send_transaction,
    format_amount, MASTER_MINTER_ROLE, MINTER_ROLE
)


# Blockchain configurations
BLOCKCHAINS = {
    'arbitrum': {
        'name': 'Arbitrum Sepolia',
        'rpc_env': 'ARBITRUM_SEPOLIA_RPC_URL',
        'usdc_env': 'MOCK_USDC_ADDRESS_ARBITRUM',
        'eurc_env': 'MOCK_EURC_ADDRESS_ARBITRUM',
    },
    'polygon': {
        'name': 'Polygon Amoy',
        'rpc_env': 'POLYGON_AMOY_RPC_URL',
        'usdc_env': 'MOCK_USDC_ADDRESS_POLYGON',
        'eurc_env': 'MOCK_EURC_ADDRESS_POLYGON',
    }
}

# Asset configurations
ASSETS = {
    'usdc': {
        'name': 'MockUSDC',
        'contract_name': 'MockUSDC',
    },
    'eurc': {
        'name': 'MockEURC',
        'contract_name': 'MockEURC',
    }
}


def setup_minter(
    minter_address: str,
    asset: str,
    blockchain: str,
    allowance: int = 1_000_000_000_000_000  # 1 billion tokens default
):
    """
    Setup an address as a minter for a token
    
    Steps:
    1. Grant MASTER_MINTER_ROLE to deployer (if not already granted)
    2. Grant MINTER_ROLE to minter address
    3. Configure minter allowance
    """
    
    # Validate inputs
    if blockchain not in BLOCKCHAINS:
        raise ValueError(f"Unknown blockchain: {blockchain}. Use 'arbitrum' or 'polygon'")
    
    if asset not in ASSETS:
        raise ValueError(f"Unknown asset: {asset}. Use 'usdc' or 'eurc'")
    
    blockchain_config = BLOCKCHAINS[blockchain]
    asset_config = ASSETS[asset]
    
    # Get configuration from environment
    rpc_url = os.getenv(blockchain_config['rpc_env'])
    if not rpc_url:
        raise ValueError(f"RPC URL not set. Please set {blockchain_config['rpc_env']} in .env")
    
    deployer_private_key = os.getenv('DEPLOYER_PRIVATE_KEY')
    if not deployer_private_key:
        raise ValueError("DEPLOYER_PRIVATE_KEY not set in .env")
    
    # Get token address
    token_env = blockchain_config['usdc_env'] if asset == 'usdc' else blockchain_config['eurc_env']
    token_address = os.getenv(token_env)
    if not token_address:
        raise ValueError(f"Token address not set. Please set {token_env} in .env")
    
    # Connect to blockchain
    w3 = get_web3(rpc_url)
    deployer_account = get_account(deployer_private_key)
    token = get_contract(w3, asset_config['contract_name'], token_address)
    minter_address = Web3.to_checksum_address(minter_address)
    
    # Get token info
    token_name = token.functions.name().call()
    token_symbol = token.functions.symbol().call()
    chain_id = w3.eth.chain_id
    
    print(f"\n{'='*70}")
    print(f"Setting up Minter for {token_symbol}")
    print(f"{'='*70}")
    print(f"Blockchain: {blockchain_config['name']} (Chain ID: {chain_id})")
    print(f"Token: {token_name} ({token_symbol})")
    print(f"Token Address: {token_address}")
    print(f"Minter Address: {minter_address}")
    print(f"Deployer: {deployer_account.address}")
    print(f"{'='*70}\n")
    
    # Check current roles
    print("Checking current roles...")
    has_master_minter = token.functions.hasRole(MASTER_MINTER_ROLE, deployer_account.address).call()
    has_minter_role = token.functions.hasRole(MINTER_ROLE, minter_address).call()
    current_allowance = token.functions.minterAllowance(minter_address).call()
    
    print(f"Deployer has MASTER_MINTER_ROLE: {has_master_minter}")
    print(f"Minter has MINTER_ROLE: {has_minter_role}")
    print(f"Current minter allowance: {format_amount(current_allowance)}\n")
    
    # Step 1: Grant MASTER_MINTER_ROLE to deployer if needed
    if not has_master_minter:
        print("[1/3] Granting MASTER_MINTER_ROLE to deployer...")
        tx = token.functions.grantRole(
            MASTER_MINTER_ROLE,
            deployer_account.address
        ).build_transaction({
            'from': deployer_account.address,
            'nonce': w3.eth.get_transaction_count(deployer_account.address),
        })
        receipt = send_transaction(w3, deployer_account, tx)
        print(f"✓ Transaction mined in block {receipt['blockNumber']}")
    else:
        print("[1/3] ✓ Deployer already has MASTER_MINTER_ROLE")
    
    # Step 2: Grant MINTER_ROLE to minter address if needed
    if not has_minter_role:
        print("\n[2/3] Granting MINTER_ROLE to minter address...")
        tx = token.functions.grantRole(
            MINTER_ROLE,
            minter_address
        ).build_transaction({
            'from': deployer_account.address,
            'nonce': w3.eth.get_transaction_count(deployer_account.address),
        })
        receipt = send_transaction(w3, deployer_account, tx)
        print(f"✓ Transaction mined in block {receipt['blockNumber']}")
    else:
        print("\n[2/3] ✓ Minter address already has MINTER_ROLE")
    
    # Step 3: Configure minter allowance
    print(f"\n[3/3] Configuring minter allowance to {format_amount(allowance)}...")
    tx = token.functions.configureMinter(
        minter_address,
        allowance
    ).build_transaction({
        'from': deployer_account.address,
        'nonce': w3.eth.get_transaction_count(deployer_account.address),
    })
    receipt = send_transaction(w3, deployer_account, tx)
    print(f"✓ Transaction mined in block {receipt['blockNumber']}")
    
    # Verify final state
    print("\n" + "="*70)
    print("Setup Complete! Final Status:")
    print("="*70)
    final_has_minter = token.functions.hasRole(MINTER_ROLE, minter_address).call()
    final_allowance = token.functions.minterAllowance(minter_address).call()
    
    print(f"✓ Minter has MINTER_ROLE: {final_has_minter}")
    print(f"✓ Minter allowance: {format_amount(final_allowance)}")
    print(f"\nThe address {minter_address}")
    print(f"can now mint up to {format_amount(final_allowance)} {token_symbol} tokens")
    print("="*70 + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="Setup a minter for a token on a specific blockchain",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Setup minter on Polygon Amoy for USDC
  python setup.py 0x1234... usdc polygon
  
  # Setup minter on Arbitrum Sepolia for EURC with custom allowance
  python setup.py 0x1234... eurc arbitrum --allowance 5000000000000
  
  # Setup minter with 10 billion token allowance
  python setup.py 0x1234... usdc polygon --allowance 10000000000000000

Environment Variables Required:
  DEPLOYER_PRIVATE_KEY          - Private key of the contract owner
  DEPLOYER_WALLET               - Address of the contract owner
  ARBITRUM_SEPOLIA_RPC_URL      - RPC endpoint for Arbitrum Sepolia
  POLYGON_AMOY_RPC_URL          - RPC endpoint for Polygon Amoy
  MOCK_USDC_ADDRESS_ARBITRUM    - MockUSDC address on Arbitrum
  MOCK_EURC_ADDRESS_ARBITRUM    - MockEURC address on Arbitrum
  MOCK_USDC_ADDRESS_POLYGON     - MockUSDC address on Polygon
  MOCK_EURC_ADDRESS_POLYGON     - MockEURC address on Polygon
        """
    )
    
    parser.add_argument("address", help="Address to setup as minter")
    parser.add_argument("asset", choices=['usdc', 'eurc'], help="Asset to mint (usdc or eurc)")
    parser.add_argument("blockchain", choices=['arbitrum', 'polygon'], 
                       help="Blockchain (arbitrum or polygon)")
    parser.add_argument("--allowance", type=int, default=1_000_000_000_000_000,
                       help="Minter allowance in raw units (default: 1 billion tokens)")
    
    args = parser.parse_args()
    
    try:
        setup_minter(args.address, args.asset, args.blockchain, args.allowance)
    except Exception as e:
        print(f"\n❌ Error: {e}\n")
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())

