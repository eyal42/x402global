#!/usr/bin/env python3
"""
Check balances for an address on a specific blockchain
"""

import argparse
import os
from web3 import Web3
from config import get_web3, get_contract, format_amount


# Blockchain configurations
BLOCKCHAINS = {
    'arb': {
        'name': 'Arbitrum Sepolia',
        'rpc_env': 'ARBITRUM_SEPOLIA_RPC_URL',
        'native_token': 'ETH',
        'usdc_env': 'MOCK_USDC_ADDRESS_ARBITRUM',
        'eurc_env': 'MOCK_EURC_ADDRESS_ARBITRUM',
    },
    'poly': {
        'name': 'Polygon Amoy',
        'rpc_env': 'POLYGON_AMOY_RPC_URL',
        'native_token': 'POL',
        'usdc_env': 'MOCK_USDC_ADDRESS_POLYGON',
        'eurc_env': 'MOCK_EURC_ADDRESS_POLYGON',
    }
}


def check_balances(address: str, blockchain: str):
    """Check all balances for an address on specified blockchain"""
    
    if blockchain not in BLOCKCHAINS:
        raise ValueError(f"Unknown blockchain: {blockchain}. Use 'arb' or 'poly'")
    
    config = BLOCKCHAINS[blockchain]
    
    # Get RPC URL from environment
    rpc_url = os.getenv(config['rpc_env'])
    if not rpc_url:
        raise ValueError(f"RPC URL not set. Please set {config['rpc_env']} in .env")
    
    # Connect to blockchain
    w3 = get_web3(rpc_url)
    address = Web3.to_checksum_address(address)
    
    # Get chain info
    chain_id = w3.eth.chain_id
    block_number = w3.eth.block_number
    
    print(f"\n{'='*60}")
    print(f"Blockchain: {config['name']} (Chain ID: {chain_id})")
    print(f"Block Number: {block_number:,}")
    print(f"Address: {address}")
    print(f"{'='*60}\n")
    
    # Native balance
    native_balance = w3.eth.get_balance(address)
    native_balance_formatted = w3.from_wei(native_balance, 'ether')
    print(f"Native Token ({config['native_token']}): {native_balance_formatted:.6f} {config['native_token']}")
    
    # MockUSDC balance
    usdc_address = os.getenv(config['usdc_env']) or os.getenv('USDC_ADDRESS')
    if usdc_address:
        try:
            usdc = get_contract(w3, "MockUSDC", usdc_address)
            usdc_balance = usdc.functions.balanceOf(address).call()
            usdc_symbol = usdc.functions.symbol().call()
            print(f"{usdc_symbol}: {format_amount(usdc_balance)}")
            print(f"  Contract: {usdc_address}")
        except Exception as e:
            print(f"MockUSDC: Error - {e}")
    else:
        print(f"MockUSDC: Address not set (set {config['usdc_env']} or USDC_ADDRESS in .env)")
    
    # MockEURC balance
    eurc_address = os.getenv(config['eurc_env']) or os.getenv('EURC_ADDRESS')
    if eurc_address:
        try:
            eurc = get_contract(w3, "MockEURC", eurc_address)
            eurc_balance = eurc.functions.balanceOf(address).call()
            eurc_symbol = eurc.functions.symbol().call()
            print(f"{eurc_symbol}: {format_amount(eurc_balance)}")
            print(f"  Contract: {eurc_address}")
        except Exception as e:
            print(f"MockEURC: Error - {e}")
    else:
        print(f"MockEURC: Address not set (set {config['eurc_env']} or EURC_ADDRESS in .env)")
    
    print()


def main():
    parser = argparse.ArgumentParser(
        description="Check token balances on a specific blockchain",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Check balance on Arbitrum Sepolia
  python balance2.py 0x1234... --arb

  # Check balance on Polygon Amoy
  python balance2.py 0x1234... --poly
  
Environment Variables:
  ARBITRUM_SEPOLIA_RPC_URL      - RPC endpoint for Arbitrum Sepolia
  POLYGON_AMOY_RPC_URL          - RPC endpoint for Polygon Amoy
  MOCK_USDC_ADDRESS_ARBITRUM    - MockUSDC address on Arbitrum (or USDC_ADDRESS)
  MOCK_EURC_ADDRESS_ARBITRUM    - MockEURC address on Arbitrum (or EURC_ADDRESS)
  MOCK_USDC_ADDRESS_POLYGON     - MockUSDC address on Polygon (or USDC_ADDRESS)
  MOCK_EURC_ADDRESS_POLYGON     - MockEURC address on Polygon (or EURC_ADDRESS)
        """
    )
    
    parser.add_argument("address", help="Address to check balances for")
    
    # Blockchain selection (mutually exclusive)
    blockchain_group = parser.add_mutually_exclusive_group(required=True)
    blockchain_group.add_argument("--arb", action="store_const", const="arb", dest="blockchain",
                                  help="Check on Arbitrum Sepolia")
    blockchain_group.add_argument("--poly", action="store_const", const="poly", dest="blockchain",
                                  help="Check on Polygon Amoy")
    
    args = parser.parse_args()
    
    try:
        check_balances(args.address, args.blockchain)
    except Exception as e:
        print(f"\n❌ Error: {e}\n")
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())

