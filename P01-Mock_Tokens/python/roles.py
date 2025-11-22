#!/usr/bin/env python3
"""
Check role status for an address across all tokens and blockchains
"""

import argparse
import os
from web3 import Web3
from config import (
    get_web3, get_contract, format_amount,
    DEFAULT_ADMIN_ROLE, MASTER_MINTER_ROLE, MINTER_ROLE, BRIDGE_ROLE
)


# Blockchain configurations
BLOCKCHAINS = {
    'arbitrum': {
        'name': 'Arbitrum Sepolia',
        'short_name': 'Arbitrum',
        'rpc_env': 'ARBITRUM_SEPOLIA_RPC_URL',
        'usdc_env': 'MOCK_USDC_ADDRESS_ARBITRUM',
        'eurc_env': 'MOCK_EURC_ADDRESS_ARBITRUM',
    },
    'polygon': {
        'name': 'Polygon Amoy',
        'short_name': 'Polygon',
        'rpc_env': 'POLYGON_AMOY_RPC_URL',
        'usdc_env': 'MOCK_USDC_ADDRESS_POLYGON',
        'eurc_env': 'MOCK_EURC_ADDRESS_POLYGON',
    }
}


def check_roles_for_token(w3, token_address, contract_name, address, blockchain_name):
    """Check all roles for an address on a specific token"""
    
    if not token_address:
        return None
    
    try:
        token = get_contract(w3, contract_name, token_address)
        
        # Get token info
        symbol = token.functions.symbol().call()
        name = token.functions.name().call()
        
        # Check roles
        has_admin = token.functions.hasRole(DEFAULT_ADMIN_ROLE, address).call()
        has_master_minter = token.functions.hasRole(MASTER_MINTER_ROLE, address).call()
        has_minter = token.functions.hasRole(MINTER_ROLE, address).call()
        has_bridge = token.functions.hasRole(BRIDGE_ROLE, address).call()
        
        # Get minter allowance if applicable
        minter_allowance = 0
        if has_minter:
            minter_allowance = token.functions.minterAllowance(address).call()
        
        return {
            'name': name,
            'symbol': symbol,
            'address': token_address,
            'has_admin': has_admin,
            'has_master_minter': has_master_minter,
            'has_minter': has_minter,
            'has_bridge': has_bridge,
            'minter_allowance': minter_allowance,
        }
    except Exception as e:
        print(f"  ⚠️  Error checking {contract_name} on {blockchain_name}: {e}")
        return None


def check_all_roles(address: str):
    """Check roles for an address on all tokens and blockchains"""
    
    address = Web3.to_checksum_address(address)
    
    print(f"\n{'='*80}")
    print(f"Role Status for Address: {address}")
    print(f"{'='*80}\n")
    
    results = {}
    
    # Check each blockchain
    for blockchain_key, blockchain_config in BLOCKCHAINS.items():
        print(f"📍 {blockchain_config['name']}")
        print(f"{'-'*80}")
        
        # Get RPC URL
        rpc_url = os.getenv(blockchain_config['rpc_env'])
        if not rpc_url:
            print(f"  ⚠️  RPC URL not set ({blockchain_config['rpc_env']})\n")
            continue
        
        try:
            w3 = get_web3(rpc_url)
            chain_id = w3.eth.chain_id
            print(f"  Chain ID: {chain_id}\n")
        except Exception as e:
            print(f"  ⚠️  Cannot connect to {blockchain_config['name']}: {e}\n")
            continue
        
        results[blockchain_key] = {}
        
        # Check MockUSDC
        usdc_address = os.getenv(blockchain_config['usdc_env'])
        if usdc_address:
            print(f"  🪙  MockUSDC ({usdc_address})")
            usdc_result = check_roles_for_token(
                w3, usdc_address, 'MockUSDC', address, blockchain_config['name']
            )
            if usdc_result:
                results[blockchain_key]['usdc'] = usdc_result
                print(f"      Admin Role:         {'✅ YES' if usdc_result['has_admin'] else '❌ NO'}")
                print(f"      Master Minter Role: {'✅ YES' if usdc_result['has_master_minter'] else '❌ NO'}")
                print(f"      Minter Role:        {'✅ YES' if usdc_result['has_minter'] else '❌ NO'}")
                if usdc_result['has_minter']:
                    print(f"      Minter Allowance:   {format_amount(usdc_result['minter_allowance'])}")
                print(f"      Bridge Role:        {'✅ YES' if usdc_result['has_bridge'] else '❌ NO'}")
        else:
            print(f"  ⚠️  MockUSDC address not set ({blockchain_config['usdc_env']})")
        
        print()
        
        # Check MockEURC
        eurc_address = os.getenv(blockchain_config['eurc_env'])
        if eurc_address:
            print(f"  🪙  MockEURC ({eurc_address})")
            eurc_result = check_roles_for_token(
                w3, eurc_address, 'MockEURC', address, blockchain_config['name']
            )
            if eurc_result:
                results[blockchain_key]['eurc'] = eurc_result
                print(f"      Admin Role:         {'✅ YES' if eurc_result['has_admin'] else '❌ NO'}")
                print(f"      Master Minter Role: {'✅ YES' if eurc_result['has_master_minter'] else '❌ NO'}")
                print(f"      Minter Role:        {'✅ YES' if eurc_result['has_minter'] else '❌ NO'}")
                if eurc_result['has_minter']:
                    print(f"      Minter Allowance:   {format_amount(eurc_result['minter_allowance'])}")
                print(f"      Bridge Role:        {'✅ YES' if eurc_result['has_bridge'] else '❌ NO'}")
        else:
            print(f"  ⚠️  MockEURC address not set ({blockchain_config['eurc_env']})")
        
        print()
    
    # Summary
    print(f"{'='*80}")
    print("SUMMARY")
    print(f"{'='*80}\n")
    
    # Count roles
    total_admin = 0
    total_master_minter = 0
    total_minter = 0
    total_bridge = 0
    
    for blockchain_key, tokens in results.items():
        for token_key, token_info in tokens.items():
            if token_info['has_admin']:
                total_admin += 1
            if token_info['has_master_minter']:
                total_master_minter += 1
            if token_info['has_minter']:
                total_minter += 1
            if token_info['has_bridge']:
                total_bridge += 1
    
    print(f"Address {address} has:")
    print(f"  • Admin Role:         {total_admin} token(s)")
    print(f"  • Master Minter Role: {total_master_minter} token(s)")
    print(f"  • Minter Role:        {total_minter} token(s)")
    print(f"  • Bridge Role:        {total_bridge} token(s)")
    
    if total_admin + total_master_minter + total_minter + total_bridge == 0:
        print(f"\n⚠️  Address has NO roles on any token")
    
    print(f"\n{'='*80}\n")


def main():
    parser = argparse.ArgumentParser(
        description="Check role status for an address across all tokens and blockchains",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Check roles for an address
  python roles.py 0x132d8294de62dE637973166C99c0FAC9C39b37Be
  
  # Check roles for deployer wallet
  python roles.py $DEPLOYER_WALLET

Roles Checked:
  - Admin Role (DEFAULT_ADMIN_ROLE): Can manage all roles and blacklist
  - Master Minter Role: Can configure minter allowances
  - Minter Role: Can mint tokens up to allowance
  - Bridge Role: Can execute bridge operations

Environment Variables Required:
  ARBITRUM_SEPOLIA_RPC_URL       - RPC endpoint for Arbitrum Sepolia
  POLYGON_AMOY_RPC_URL           - RPC endpoint for Polygon Amoy
  MOCK_USDC_ADDRESS_ARBITRUM     - MockUSDC address on Arbitrum
  MOCK_EURC_ADDRESS_ARBITRUM     - MockEURC address on Arbitrum
  MOCK_USDC_ADDRESS_POLYGON      - MockUSDC address on Polygon
  MOCK_EURC_ADDRESS_POLYGON      - MockEURC address on Polygon
        """
    )
    
    parser.add_argument("address", help="Address to check roles for")
    
    args = parser.parse_args()
    
    try:
        check_all_roles(args.address)
    except Exception as e:
        print(f"\n❌ Error: {e}\n")
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())

