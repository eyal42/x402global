#!/usr/bin/env python3
"""
Check balances for native token and all deployed tokens
"""

import argparse
import os
from web3 import Web3
from config import get_web3, get_contract, format_amount


def check_balances(address: str, rpc_url: str = None):
    """Check all balances for an address"""
    w3 = get_web3(rpc_url)
    address = Web3.to_checksum_address(address)
    
    print(f"\n=== Balances for {address} ===\n")
    
    # Native balance
    native_balance = w3.eth.get_balance(address)
    print(f"Native Token: {w3.from_wei(native_balance, 'ether')} ETH")
    
    # MockUSDC balance (if address is set)
    usdc_address = os.getenv("USDC_ADDRESS")
    if usdc_address:
        try:
            usdc = get_contract(w3, "MockUSDC", usdc_address)
            usdc_balance = usdc.functions.balanceOf(address).call()
            print(f"MockUSDC: {format_amount(usdc_balance)}")
        except Exception as e:
            print(f"MockUSDC: Error - {e}")
    else:
        print("MockUSDC: Address not set (set USDC_ADDRESS in .env)")
    
    # MockEURC balance (if address is set)
    eurc_address = os.getenv("EURC_ADDRESS")
    if eurc_address:
        try:
            eurc = get_contract(w3, "MockEURC", eurc_address)
            eurc_balance = eurc.functions.balanceOf(address).call()
            print(f"MockEURC: {format_amount(eurc_balance)}")
        except Exception as e:
            print(f"MockEURC: Error - {e}")
    else:
        print("MockEURC: Address not set (set EURC_ADDRESS in .env)")
    
    print()


def main():
    parser = argparse.ArgumentParser(description="Check token balances")
    parser.add_argument("address", help="Address to check")
    parser.add_argument("--rpc", help="RPC URL (default: from .env)")
    
    args = parser.parse_args()
    
    check_balances(args.address, args.rpc)


if __name__ == "__main__":
    main()

