"""
Configuration and utilities for interacting with Mock Token contracts
"""

import json
import os
from pathlib import Path
from typing import Any, Dict
from web3 import Web3
from web3.contract import Contract
from eth_account import Account
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Project root
PROJECT_ROOT = Path(__file__).parent.parent

# Role constants (keccak256 hashes)
DEFAULT_ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000"
MASTER_MINTER_ROLE = Web3.keccak(text="MASTER_MINTER_ROLE").hex()
MINTER_ROLE = Web3.keccak(text="MINTER_ROLE").hex()
BRIDGE_ROLE = Web3.keccak(text="BRIDGE_ROLE").hex()

# Decimals
DECIMALS = 6


def get_web3(rpc_url: str = None) -> Web3:
    """Get Web3 instance with PoA middleware for compatibility"""
    if rpc_url is None:
        rpc_url = os.getenv("RPC_URL", "http://127.0.0.1:8545")
    
    w3 = Web3(Web3.HTTPProvider(rpc_url))
    
    # Inject PoA middleware for chains like Polygon, BSC, etc.
    # This allows handling of extraData > 32 bytes in block headers
    from web3.middleware import geth_poa_middleware
    w3.middleware_onion.inject(geth_poa_middleware, layer=0)
    
    if not w3.is_connected():
        raise ConnectionError(f"Could not connect to {rpc_url}")
    
    return w3


def get_account(private_key: str = None) -> Account:
    """Get account from private key"""
    if private_key is None:
        private_key = os.getenv("PRIVATE_KEY")
    
    if not private_key:
        raise ValueError("No private key provided")
    
    if not private_key.startswith("0x"):
        private_key = "0x" + private_key
    
    return Account.from_key(private_key)


def load_abi(contract_name: str) -> list:
    """Load contract ABI from Foundry output"""
    abi_path = PROJECT_ROOT / "out" / f"{contract_name}.sol" / f"{contract_name}.json"
    
    if not abi_path.exists():
        raise FileNotFoundError(f"ABI file not found: {abi_path}")
    
    with open(abi_path) as f:
        contract_json = json.load(f)
        return contract_json["abi"]


def get_contract(w3: Web3, contract_name: str, address: str) -> Contract:
    """Get contract instance"""
    abi = load_abi(contract_name)
    return w3.eth.contract(address=Web3.to_checksum_address(address), abi=abi)


def send_transaction(w3: Web3, account: Account, tx: Dict[str, Any]) -> Dict[str, Any]:
    """Send transaction and wait for receipt"""
    # Add gas estimate if not provided
    if "gas" not in tx:
        tx["gas"] = w3.eth.estimate_gas(tx)
    
    # Add nonce if not provided
    if "nonce" not in tx:
        tx["nonce"] = w3.eth.get_transaction_count(account.address)
    
    # Sign transaction
    signed_tx = account.sign_transaction(tx)
    
    # Send transaction
    tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
    print(f"Transaction sent: {tx_hash.hex()}")
    
    # Wait for receipt
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f"Transaction mined in block {receipt['blockNumber']}")
    
    if receipt["status"] == 0:
        raise Exception("Transaction failed")
    
    return receipt


def format_amount(amount: int) -> str:
    """Format token amount for display"""
    return f"{amount / 10**DECIMALS:,.{DECIMALS}f}"


def parse_amount(amount_str: str) -> int:
    """Parse token amount from string"""
    return int(float(amount_str) * 10**DECIMALS)


def print_receipt_info(receipt: Dict[str, Any]):
    """Print transaction receipt information"""
    print(f"\nTransaction Receipt:")
    print(f"  Block: {receipt['blockNumber']}")
    print(f"  Gas Used: {receipt['gasUsed']:,}")
    print(f"  Status: {'Success' if receipt['status'] == 1 else 'Failed'}")
    print(f"  Transaction Hash: {receipt['transactionHash'].hex()}")

