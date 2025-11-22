#!/usr/bin/env python3
"""
Mint and burn token operations
"""

import argparse
from web3 import Web3
from config import (
    get_web3, get_account, get_contract, send_transaction,
    format_amount, parse_amount, print_receipt_info, MINTER_ROLE
)


def check_minter_status(token_address: str, minter_address: str, rpc_url: str = None):
    """Check if address has minter role and allowance"""
    w3 = get_web3(rpc_url)
    token = get_contract(w3, "MockUSDC", token_address)
    
    is_minter = token.functions.hasRole(MINTER_ROLE, minter_address).call()
    allowance = token.functions.minterAllowance(minter_address).call()
    
    print(f"\nMinter Status for {minter_address}:")
    print(f"  Has MINTER_ROLE: {is_minter}")
    print(f"  Minter Allowance: {format_amount(allowance)}")
    print()


def mint_tokens(
    token_address: str,
    to_address: str,
    amount: str,
    private_key: str = None,
    rpc_url: str = None
):
    """Mint tokens to an address"""
    w3 = get_web3(rpc_url)
    account = get_account(private_key)
    token = get_contract(w3, "MockUSDC", token_address)
    
    amount_wei = parse_amount(amount)
    
    print(f"\nMinting {format_amount(amount_wei)} tokens to {to_address}")
    print(f"From: {account.address}")
    
    # Build transaction
    tx = token.functions.mint(
        Web3.to_checksum_address(to_address),
        amount_wei
    ).build_transaction({
        "from": account.address,
        "nonce": w3.eth.get_transaction_count(account.address),
    })
    
    # Send transaction
    receipt = send_transaction(w3, account, tx)
    print_receipt_info(receipt)
    
    # Check new balance
    new_balance = token.functions.balanceOf(to_address).call()
    print(f"\nNew balance: {format_amount(new_balance)}")


def burn_tokens(
    token_address: str,
    amount: str,
    private_key: str = None,
    rpc_url: str = None
):
    """Burn tokens from caller's balance"""
    w3 = get_web3(rpc_url)
    account = get_account(private_key)
    token = get_contract(w3, "MockUSDC", token_address)
    
    amount_wei = parse_amount(amount)
    
    print(f"\nBurning {format_amount(amount_wei)} tokens")
    print(f"From: {account.address}")
    
    # Build transaction
    tx = token.functions.burn(amount_wei).build_transaction({
        "from": account.address,
        "nonce": w3.eth.get_transaction_count(account.address),
    })
    
    # Send transaction
    receipt = send_transaction(w3, account, tx)
    print_receipt_info(receipt)
    
    # Check new balance
    new_balance = token.functions.balanceOf(account.address).call()
    print(f"\nNew balance: {format_amount(new_balance)}")


def check_balance(token_address: str, address: str, rpc_url: str = None):
    """Check token balance"""
    w3 = get_web3(rpc_url)
    token = get_contract(w3, "MockUSDC", token_address)
    
    balance = token.functions.balanceOf(Web3.to_checksum_address(address)).call()
    print(f"\nBalance of {address}: {format_amount(balance)}")


def main():
    parser = argparse.ArgumentParser(description="Mint and burn tokens")
    parser.add_argument("--token", required=True, help="Token contract address")
    parser.add_argument("--rpc", help="RPC URL (default: from .env)")
    parser.add_argument("--private-key", help="Private key (default: from .env)")
    
    subparsers = parser.add_subparsers(dest="command", help="Command to execute")
    
    # Mint command
    mint_parser = subparsers.add_parser("mint", help="Mint tokens")
    mint_parser.add_argument("to", help="Recipient address")
    mint_parser.add_argument("amount", help="Amount to mint")
    
    # Burn command
    burn_parser = subparsers.add_parser("burn", help="Burn tokens")
    burn_parser.add_argument("amount", help="Amount to burn")
    
    # Balance command
    balance_parser = subparsers.add_parser("balance", help="Check balance")
    balance_parser.add_argument("address", help="Address to check")
    
    # Minter status command
    status_parser = subparsers.add_parser("status", help="Check minter status")
    status_parser.add_argument("address", help="Address to check")
    
    args = parser.parse_args()
    
    if args.command == "mint":
        mint_tokens(args.token, args.to, args.amount, args.private_key, args.rpc)
    elif args.command == "burn":
        burn_tokens(args.token, args.amount, args.private_key, args.rpc)
    elif args.command == "balance":
        check_balance(args.token, args.address, args.rpc)
    elif args.command == "status":
        check_minter_status(args.token, args.address, args.rpc)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()

