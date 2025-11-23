"""
Web3 utilities for interacting with Polygon Amoy
"""
import json
from typing import Optional, Dict, Any, Tuple
from web3 import Web3
from web3.contract import Contract
from eth_account import Account
from eth_account.messages import encode_typed_data
from eth_abi import encode
import config

# Initialize Web3
w3 = Web3(Web3.HTTPProvider(config.POLYGON_AMOY_RPC_URL))

def get_contract(address: str, abi: list) -> Contract:
    """Get a contract instance"""
    return w3.eth.contract(address=Web3.to_checksum_address(address), abi=abi)

def load_abi(contract_name: str) -> list:
    """Load ABI from compiled contract artifacts"""
    # For MockUSDC and MockEURC, use minimal ERC20 + Permit ABI
    if contract_name in ["MockUSDC", "MockEURC"]:
        return get_erc20_permit_abi()
    
    try:
        # Try to load from Foundry out directory
        with open(f"../out/{contract_name}.sol/{contract_name}.json", "r") as f:
            artifact = json.load(f)
            return artifact["abi"]
    except FileNotFoundError:
        # Try interface directory
        try:
            with open(f"../out/I{contract_name}.sol/I{contract_name}.json", "r") as f:
                artifact = json.load(f)
                return artifact["abi"]
        except FileNotFoundError:
            print(f"Warning: Could not find ABI for {contract_name}")
            return []

def get_erc20_permit_abi() -> list:
    """Return minimal ERC20 + EIP-2612 Permit ABI"""
    return [
        {
            "inputs": [{"name": "account", "type": "address"}],
            "name": "balanceOf",
            "outputs": [{"name": "", "type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [],
            "name": "decimals",
            "outputs": [{"name": "", "type": "uint8"}],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [],
            "name": "name",
            "outputs": [{"name": "", "type": "string"}],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [{"name": "owner", "type": "address"}],
            "name": "nonces",
            "outputs": [{"name": "", "type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [
                {"name": "owner", "type": "address"},
                {"name": "spender", "type": "address"}
            ],
            "name": "allowance",
            "outputs": [{"name": "", "type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [
                {"name": "owner", "type": "address"},
                {"name": "spender", "type": "address"},
                {"name": "value", "type": "uint256"},
                {"name": "deadline", "type": "uint256"},
                {"name": "v", "type": "uint8"},
                {"name": "r", "type": "bytes32"},
                {"name": "s", "type": "bytes32"}
            ],
            "name": "permit",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [
                {"name": "to", "type": "address"},
                {"name": "amount", "type": "uint256"}
            ],
            "name": "transfer",
            "outputs": [{"name": "", "type": "bool"}],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [
                {"name": "from", "type": "address"},
                {"name": "to", "type": "address"},
                {"name": "amount", "type": "uint256"}
            ],
            "name": "transferFrom",
            "outputs": [{"name": "", "type": "bool"}],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [
                {"name": "spender", "type": "address"},
                {"name": "amount", "type": "uint256"}
            ],
            "name": "approve",
            "outputs": [{"name": "", "type": "bool"}],
            "stateMutability": "nonpayable",
            "type": "function"
        }
    ]

def get_nonce(address: str) -> int:
    """Get the current nonce for an address"""
    return w3.eth.get_transaction_count(Web3.to_checksum_address(address))

def get_balance(address: str, token_address: Optional[str] = None) -> int:
    """Get balance (native or ERC20)"""
    address = Web3.to_checksum_address(address)
    
    if token_address is None:
        # Get native MATIC balance
        return w3.eth.get_balance(address)
    else:
        # Get ERC20 balance
        token_abi = load_abi("MockUSDC")  # All tokens have same ABI
        token = get_contract(token_address, token_abi)
        return token.functions.balanceOf(address).call()

def create_permit_signature(
    token_address: str,
    owner_address: str,
    spender_address: str,
    value: int,
    deadline: int,
    private_key: str
) -> Tuple[int, bytes, bytes]:
    """
    Create an EIP-2612 permit signature
    
    Returns: (v, r, s) signature components
    """
    token_address = Web3.to_checksum_address(token_address)
    owner_address = Web3.to_checksum_address(owner_address)
    spender_address = Web3.to_checksum_address(spender_address)
    
    # Get token contract
    token_abi = load_abi("MockUSDC")
    token = get_contract(token_address, token_abi)
    
    # Get nonce for permit
    try:
        nonce = token.functions.nonces(owner_address).call()
    except Exception as e:
        print(f"Error getting nonce: {e}")
        nonce = 0
    
    # Get token name and version for EIP-712
    try:
        name = token.functions.name().call()
    except:
        name = "Unknown Token"
    
    # EIP-712 domain
    domain = {
        "name": name,
        "version": "1",
        "chainId": config.CHAIN_ID,
        "verifyingContract": token_address,
    }
    
    # Permit message
    message = {
        "owner": owner_address,
        "spender": spender_address,
        "value": value,
        "nonce": nonce,
        "deadline": deadline,
    }
    
    # Types for EIP-712
    types = {
        "EIP712Domain": [
            {"name": "name", "type": "string"},
            {"name": "version", "type": "string"},
            {"name": "chainId", "type": "uint256"},
            {"name": "verifyingContract", "type": "address"},
        ],
        "Permit": [
            {"name": "owner", "type": "address"},
            {"name": "spender", "type": "address"},
            {"name": "value", "type": "uint256"},
            {"name": "nonce", "type": "uint256"},
            {"name": "deadline", "type": "uint256"},
        ],
    }
    
    # Create typed data structure
    typed_data = {
        "types": types,
        "primaryType": "Permit",
        "domain": domain,
        "message": message,
    }
    
    # Sign the message
    encoded_data = encode_typed_data(full_message=typed_data)
    signed_message = Account.from_key(private_key).sign_message(encoded_data)
    
    # Extract v, r, s
    v = signed_message.v
    r = signed_message.r.to_bytes(32, byteorder='big')
    s = signed_message.s.to_bytes(32, byteorder='big')
    
    return (v, r, s)

def send_transaction(
    contract: Contract,
    function_name: str,
    args: list,
    private_key: str,
    value: int = 0
) -> str:
    """
    Send a transaction to a contract
    
    Returns: transaction hash
    """
    account = Account.from_key(private_key)
    
    # Build transaction
    function = getattr(contract.functions, function_name)(*args)
    
    tx = function.build_transaction({
        'from': account.address,
        'nonce': get_nonce(account.address),
        'gas': 500000,  # Estimate or set manually
        'gasPrice': w3.eth.gas_price,
        'value': value,
        'chainId': config.CHAIN_ID,
    })
    
    # Sign and send
    signed_tx = account.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
    
    return tx_hash.hex()

def wait_for_transaction(tx_hash: str, timeout: int = 120) -> Dict[str, Any]:
    """
    Wait for a transaction to be mined
    
    Returns: transaction receipt
    """
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=timeout)
    return dict(receipt)

def get_block_number() -> int:
    """Get current block number"""
    return w3.eth.block_number

def is_block_finalized(block_number: int, confirmations: int = None) -> bool:
    """Check if a block is finalized based on confirmation count"""
    if confirmations is None:
        confirmations = config.FINALITY_CONFIRMATIONS
    
    current_block = get_block_number()
    return (current_block - block_number) >= confirmations

def format_token_amount(amount: int, decimals: int) -> str:
    """Format token amount for display"""
    return f"{amount / (10 ** decimals):.{decimals}f}"

def parse_token_amount(amount: str, decimals: int) -> int:
    """Parse token amount from string"""
    return int(float(amount) * (10 ** decimals))

