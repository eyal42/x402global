"""
x402 OTC API Server
Implements HTTP 402 payment flow with EIP-2612 gasless approvals
"""
import os
import sys
import json
import uuid
import time
from flask import Flask, request, jsonify, Response
from web3 import Web3
from eth_account import Account
from eth_account.messages import encode_typed_data

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from common.config import Config
from common.contracts import (
    get_contract,
    ERC20_PERMIT_ABI,
    SETTLEMENT_VAULT_ABI,
    SWAP_SIMULATOR_ABI
)

# Initialize Flask app
app = Flask(__name__)

# Initialize Web3
w3 = Web3(Web3.HTTPProvider(Config.RPC_URL))

# Facilitator account (runs the server)
facilitator_account = Account.from_key(Config.FACILITATOR_PRIVATE_KEY)

print(f"=== x402 OTC API Server - Role Configuration ===")
print(f"Facilitator (Server): {Config.FACILITATOR_ADDRESS}")
print(f"Seller (Asset Provider): {Config.SELLER_ADDRESS}")
print(f"Chain ID: {Config.CHAIN_ID}")
print(f"RPC URL: {Config.RPC_URL}")
print()

# Load contracts
vault_contract = get_contract(w3, Config.SETTLEMENT_VAULT_ADDRESS, SETTLEMENT_VAULT_ABI)
simulator_contract = get_contract(w3, Config.SWAP_SIMULATOR_ADDRESS, SWAP_SIMULATOR_ABI)
mock_eurc = get_contract(w3, Config.MOCK_EURC_ADDRESS, ERC20_PERMIT_ABI)
mock_usdc = get_contract(w3, Config.MOCK_USDC_ADDRESS, ERC20_PERMIT_ABI)
yps_token = get_contract(w3, Config.YPS_ADDRESS, ERC20_PERMIT_ABI)

# In-memory order tracking
orders = {}


def generate_order_id() -> str:
    """Generate unique order ID"""
    return str(uuid.uuid4())


def create_x402_response(order_id: str, client_address: str, asset_amount: int) -> Response:
    """Create HTTP 402 Payment Required response"""
    
    # Calculate required MockUSDC amount
    required_usdc = asset_amount * Config.ASSET_PRICE_USDC // (10**18)  # YPS is 18 decimals
    
    # Calculate deadline
    deadline = int(time.time()) + Config.PAYMENT_DEADLINE_SECONDS
    
    # Create order in contract
    order_id_bytes = Web3.keccak(text=order_id)
    
    try:
        # Build transaction to create payment request
        tx = vault_contract.functions.createPaymentRequest(
            order_id_bytes,
            Web3.to_checksum_address(client_address),
            Web3.to_checksum_address(Config.SELLER_ADDRESS),  # seller
            Config.YPS_ADDRESS,  # asset token
            asset_amount,
            Config.MOCK_USDC_ADDRESS,  # settlement token
            required_usdc,
            deadline
        ).build_transaction({
            'from': facilitator_account.address,
            'nonce': w3.eth.get_transaction_count(facilitator_account.address),
            'gas': 500000,
            'gasPrice': w3.eth.gas_price
        })
        
        # Sign and send transaction (facilitator pays gas)
        signed_tx = facilitator_account.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        
        print(f"Payment request created by facilitator: {tx_hash.hex()}")
        print(f"  Client: {client_address}")
        print(f"  Seller: {Config.SELLER_ADDRESS}")
        
    except Exception as e:
        print(f"Error creating payment request: {e}")
        return jsonify({"error": "Failed to create payment request"}), 500
    
    # Store order locally
    orders[order_id] = {
        "order_id": order_id,
        "order_id_bytes": order_id_bytes.hex(),
        "client": client_address,
        "asset_amount": asset_amount,
        "required_usdc": required_usdc,
        "deadline": deadline,
        "status": "requested",
        "tx_hash": tx_hash.hex()
    }
    
    # Create x402 Payment Requirements object
    payment_requirements = {
        "order_id": order_id,
        "token": Config.MOCK_USDC_ADDRESS,
        "amount": str(required_usdc),
        "decimals": 6,
        "chain_id": Config.CHAIN_ID,
        "deadline": deadline,
        "vault": Config.SETTLEMENT_VAULT_ADDRESS,
        "asset": {
            "token": Config.YPS_ADDRESS,
            "amount": str(asset_amount),
            "decimals": 18
        },
        "payment_method": "eip2612_permit",
        "instructions": "Sign EIP-2612 permit for MockEURC and include in X-PAYMENT header"
    }
    
    response = jsonify(payment_requirements)
    response.status_code = 402
    response.headers['X-Payment-Required'] = 'true'
    
    return response


@app.route('/buy-asset', methods=['GET', 'POST'])
def buy_asset():
    """
    Main endpoint for buying assets via x402
    GET: Returns 402 with payment requirements
    POST with X-PAYMENT: Processes payment and releases asset
    """
    
    # Get client address and asset amount from query params
    client_address = request.args.get('client')
    asset_amount_str = request.args.get('amount', '1')
    
    if not client_address:
        return jsonify({"error": "Missing 'client' parameter"}), 400
    
    try:
        asset_amount = int(float(asset_amount_str) * 10**18)  # Convert to wei
    except ValueError:
        return jsonify({"error": "Invalid 'amount' parameter"}), 400
    
    # Check if payment header is present
    payment_header = request.headers.get('X-PAYMENT')
    
    if not payment_header:
        # First request: Return 402 with payment requirements
        order_id = generate_order_id()
        return create_x402_response(order_id, client_address, asset_amount)
    
    # Second request: Process payment
    try:
        payment_data = json.loads(payment_header)
    except json.JSONDecodeError:
        return jsonify({"error": "Invalid X-PAYMENT header format"}), 400
    
    # Extract payment data
    order_id = payment_data.get('order_id')
    permit_signature = payment_data.get('permit_signature')
    
    if not order_id or not permit_signature:
        return jsonify({"error": "Missing order_id or permit_signature"}), 400
    
    # Get order
    order = orders.get(order_id)
    if not order:
        return jsonify({"error": "Order not found"}), 404
    
    # Extract signature components
    v = permit_signature['v']
    r = permit_signature['r']
    s = permit_signature['s']
    amount = int(permit_signature['amount'])
    deadline = permit_signature['deadline']
    
    # Strip '0x' prefix if present and ensure proper format
    r_clean = r[2:] if r.startswith('0x') else r
    s_clean = s[2:] if s.startswith('0x') else s
    
    print(f"\nProcessing payment for order {order_id}")
    print(f"Client: {client_address}")
    print(f"Amount: {amount}")
    print(f"Signature r: {r_clean[:16]}... (len: {len(r_clean)})")
    print(f"Signature s: {s_clean[:16]}... (len: {len(s_clean)})")
    
    try:
        # Step 1: Pull payment using permit
        order_id_bytes_hex = order['order_id_bytes']
        # Strip 0x prefix if present
        order_id_bytes_hex_clean = order_id_bytes_hex[2:] if order_id_bytes_hex.startswith('0x') else order_id_bytes_hex
        print(f"Order ID bytes hex: {order_id_bytes_hex_clean[:16]}... (len: {len(order_id_bytes_hex_clean)})")
        order_id_bytes = bytes.fromhex(order_id_bytes_hex_clean)
        
        tx = vault_contract.functions.pullPaymentWithPermit(
            order_id_bytes,
            Config.MOCK_EURC_ADDRESS,
            amount,
            deadline,
            v,
            bytes.fromhex(r_clean),
            bytes.fromhex(s_clean)
        ).build_transaction({
            'from': facilitator_account.address,
            'nonce': w3.eth.get_transaction_count(facilitator_account.address),
            'gas': 500000,
            'gasPrice': w3.eth.gas_price
        })
        
        signed_tx = facilitator_account.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        
        print(f"Funds pulled by facilitator: {tx_hash.hex()}")
        
        # Step 2: Simulate swap
        swap_id = Web3.keccak(text=f"{order_id}-swap")
        
        tx = simulator_contract.functions.instantSwap(
            swap_id,
            Config.MOCK_EURC_ADDRESS,
            Config.MOCK_USDC_ADDRESS,
            amount
        ).build_transaction({
            'from': facilitator_account.address,
            'nonce': w3.eth.get_transaction_count(facilitator_account.address),
            'gas': 300000,
            'gasPrice': w3.eth.gas_price
        })
        
        signed_tx = facilitator_account.sign_transaction(tx)
        tx_hash_swap = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        receipt_swap = w3.eth.wait_for_transaction_receipt(tx_hash_swap)
        
        # Get swap output amount
        swap_result = simulator_contract.functions.getSwap(swap_id).call()
        amount_out = swap_result[4]  # amountOut field
        
        print(f"Swap completed: {tx_hash_swap.hex()}, output: {amount_out}")
        
        # Step 3: Complete swap and settle
        tx = vault_contract.functions.completeSwapAndSettle(
            order_id_bytes,
            amount_out
        ).build_transaction({
            'from': facilitator_account.address,
            'nonce': w3.eth.get_transaction_count(facilitator_account.address),
            'gas': 300000,
            'gasPrice': w3.eth.gas_price
        })
        
        signed_tx = facilitator_account.sign_transaction(tx)
        tx_hash_settle = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        receipt_settle = w3.eth.wait_for_transaction_receipt(tx_hash_settle)
        
        print(f"Settlement completed by facilitator: {tx_hash_settle.hex()}")
        print(f"  MockUSDC credited to seller: {Config.SELLER_ADDRESS}")
        
        # Step 4: Release asset
        tx = vault_contract.functions.releaseAsset(
            order_id_bytes
        ).build_transaction({
            'from': facilitator_account.address,
            'nonce': w3.eth.get_transaction_count(facilitator_account.address),
            'gas': 300000,
            'gasPrice': w3.eth.gas_price
        })
        
        signed_tx = facilitator_account.sign_transaction(tx)
        tx_hash_release = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        receipt_release = w3.eth.wait_for_transaction_receipt(tx_hash_release)
        
        print(f"Asset released by facilitator: {tx_hash_release.hex()}")
        print(f"  YPS tokens sent to client: {client_address}")
        
        # Update order status
        order['status'] = 'completed'
        order['payment_tx'] = tx_hash.hex()
        order['swap_tx'] = tx_hash_swap.hex()
        order['settle_tx'] = tx_hash_settle.hex()
        order['release_tx'] = tx_hash_release.hex()
        
        # Get final vault balances
        yps_balance = yps_token.functions.balanceOf(Config.SETTLEMENT_VAULT_ADDRESS).call()
        
        # Return success response
        return jsonify({
            "status": "success",
            "order_id": order_id,
            "asset_amount": str(asset_amount),
            "asset_token": Config.YPS_ADDRESS,
            "payment_amount": str(amount),
            "settlement_amount": str(amount_out),
            "transactions": {
                "payment": tx_hash.hex(),
                "swap": tx_hash_swap.hex(),
                "settle": tx_hash_settle.hex(),
                "release": tx_hash_release.hex()
            },
            "vault_balances": {
                "yps": str(yps_balance)
            }
        }), 200
        
    except Exception as e:
        print(f"Error processing payment: {e}")
        print(f"Error type: {type(e).__name__}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route('/status/<order_id>', methods=['GET'])
def get_status(order_id):
    """Get order status"""
    order = orders.get(order_id)
    if not order:
        return jsonify({"error": "Order not found"}), 404
    
    return jsonify(order), 200


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "roles": {
            "facilitator": Config.FACILITATOR_ADDRESS,
            "seller": Config.SELLER_ADDRESS
        },
        "chain_id": Config.CHAIN_ID,
        "contracts": {
            "vault": Config.SETTLEMENT_VAULT_ADDRESS,
            "simulator": Config.SWAP_SIMULATOR_ADDRESS,
            "yps": Config.YPS_ADDRESS
        }
    }), 200


if __name__ == '__main__':
    # Validate configuration
    try:
        Config.validate(role="facilitator")
    except ValueError as e:
        print(f"Configuration error: {e}")
        sys.exit(1)
    
    print("\n=== x402 OTC API Server ===")
    print(f"Network: Polygon Amoy (Chain ID: {Config.CHAIN_ID})")
    print(f"\nRole Configuration:")
    print(f"  Facilitator (Server): {Config.FACILITATOR_ADDRESS}")
    print(f"  Seller (Receives USDC): {Config.SELLER_ADDRESS}")
    print(f"\nContracts:")
    print(f"  Vault: {Config.SETTLEMENT_VAULT_ADDRESS}")
    print(f"  YPS Token: {Config.YPS_ADDRESS}")
    print(f"\nPricing:")
    print(f"  Asset price: {Config.ASSET_PRICE_USDC / 10**6} USDC per YPS")
    print(f"\nServer listening on {Config.SERVER_HOST}:{Config.SERVER_PORT}\n")
    
    # Run server
    app.run(host=Config.SERVER_HOST, port=Config.SERVER_PORT, debug=True)

