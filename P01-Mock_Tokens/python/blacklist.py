#!/usr/bin/env python3
"""
Blacklist management operations
"""

import argparse
from web3 import Web3
from config import (
    get_web3, get_account, get_contract, send_transaction,
    format_amount, print_receipt_info
)


def check_blacklist(token_address: str, address: str, rpc_url: str = None):
    """Check if address is blacklisted"""
    w3 = get_web3(rpc_url)
    token = get_contract(w3, "MockUSDC", token_address)
    
    is_blacklisted = token.functions.isBlacklisted(Web3.to_checksum_address(address)).call()
    balance = token.functions.balanceOf(Web3.to_checksum_address(address)).call()
    
    print(f"\nAddress: {address}")
    print(f"  Blacklisted: {is_blacklisted}")
    print(f"  Balance: {format_amount(balance)}")
    print()


def set_blacklist(
    token_address: str,
    address: str,
    blacklisted: bool,
    private_key: str = None,
    rpc_url: str = None
):
    """Set blacklist status for an address"""
    w3 = get_web3(rpc_url)
    account = get_account(private_key)
    token = get_contract(w3, "MockUSDC", token_address)
    
    action = "Blacklisting" if blacklisted else "Unblacklisting"
    print(f"\n{action} address {address}")
    print(f"From: {account.address}")
    
    # Build transaction
    tx = token.functions.setBlacklisted(
        Web3.to_checksum_address(address),
        blacklisted
    ).build_transaction({
        "from": account.address,
        "nonce": w3.eth.get_transaction_count(account.address),
    })
    
    # Send transaction
    receipt = send_transaction(w3, account, tx)
    print_receipt_info(receipt)


def wipe_blacklisted(
    token_address: str,
    address: str,
    private_key: str = None,
    rpc_url: str = None
):
    """Wipe balance of a blacklisted address"""
    w3 = get_web3(rpc_url)
    account = get_account(private_key)
    token = get_contract(w3, "MockUSDC", token_address)
    
    # Check balance before
    balance_before = token.functions.balanceOf(Web3.to_checksum_address(address)).call()
    
    print(f"\nWiping balance of blacklisted address {address}")
    print(f"Balance to wipe: {format_amount(balance_before)}")
    print(f"From: {account.address}")
    
    # Build transaction
    tx = token.functions.wipeBlacklisted(
        Web3.to_checksum_address(address)
    ).build_transaction({
        "from": account.address,
        "nonce": w3.eth.get_transaction_count(account.address),
    })
    
    # Send transaction
    receipt = send_transaction(w3, account, tx)
    print_receipt_info(receipt)
    
    # Check balance after
    balance_after = token.functions.balanceOf(address).call()
    print(f"\nBalance after wipe: {format_amount(balance_after)}")


def main():
    parser = argparse.ArgumentParser(description="Blacklist management")
    parser.add_argument("--token", required=True, help="Token contract address")
    parser.add_argument("--rpc", help="RPC URL (default: from .env)")
    parser.add_argument("--private-key", help="Private key (default: from .env)")
    
    subparsers = parser.add_subparsers(dest="command", help="Command to execute")
    
    # Check command
    check_parser = subparsers.add_parser("check", help="Check blacklist status")
    check_parser.add_argument("address", help="Address to check")
    
    # Add command
    add_parser = subparsers.add_parser("add", help="Add to blacklist")
    add_parser.add_argument("address", help="Address to blacklist")
    
    # Remove command
    remove_parser = subparsers.add_parser("remove", help="Remove from blacklist")
    remove_parser.add_argument("address", help="Address to unblacklist")
    
    # Wipe command
    wipe_parser = subparsers.add_parser("wipe", help="Wipe blacklisted balance")
    wipe_parser.add_argument("address", help="Blacklisted address to wipe")
    
    args = parser.parse_args()
    
    if args.command == "check":
        check_blacklist(args.token, args.address, args.rpc)
    elif args.command == "add":
        set_blacklist(args.token, args.address, True, args.private_key, args.rpc)
    elif args.command == "remove":
        set_blacklist(args.token, args.address, False, args.private_key, args.rpc)
    elif args.command == "wipe":
        wipe_blacklisted(args.token, args.address, args.private_key, args.rpc)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()

