"""
OTC API HTTP Server implementing x402 protocol
Seller-side server that exposes assets for sale via HTTP
"""
import json
import time
from typing import Dict, Optional
from flask import Flask, request, jsonify
from eth_account import Account
import config
import web3_utils
from x402_types import (
    create_x402_payment_requirement,
    create_x402_response,
    parse_x402_payment_header,
    SettlementRequest,
    SettlementResponse,
)

app = Flask(__name__)

# Global state
active_settlements: Dict[str, Dict] = {}
seller_account = None

def init_server():
    """Initialize server with seller account"""
    global seller_account
    
    if not config.SELLER_PRIVATE_KEY:
        raise ValueError("SELLER_PRIVATE_KEY not configured")
    
    seller_account = Account.from_key(config.SELLER_PRIVATE_KEY)
    print(f"Server initialized as seller: {seller_account.address}")
    print(f"Server listening on {config.HTTP_SERVER_HOST}:{config.HTTP_SERVER_PORT}")

@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "seller": seller_account.address if seller_account else None,
        "timestamp": int(time.time()),
    })

@app.route("/buy-asset", methods=["GET", "POST"])
def buy_asset():
    """
    Main OTC endpoint to purchase assets
    
    GET: Request payment requirements (returns 402)
    POST: Submit payment proof and execute settlement
    """
    
    # Parse request
    if request.method == "GET":
        # Extract amount from query params
        asset_amount_str = request.args.get("amount")
        if not asset_amount_str:
            return jsonify({"error": "Missing 'amount' parameter"}), 400
        
        try:
            asset_amount = int(asset_amount_str)
        except ValueError:
            return jsonify({"error": "Invalid 'amount' parameter"}), 400
        
        # Check for X-PAYMENT header
        payment_header = request.headers.get("X-PAYMENT")
        
        if not payment_header:
            # No payment provided, return 402 with requirements
            return handle_payment_required(asset_amount)
        else:
            # Payment header provided, validate and process
            return handle_payment_submitted(asset_amount, payment_header)
    
    elif request.method == "POST":
        # POST request with JSON body
        try:
            data = request.get_json()
            settlement_request = SettlementRequest(**data)
        except Exception as e:
            return jsonify({"error": f"Invalid request: {str(e)}"}), 400
        
        # Check for X-PAYMENT header
        payment_header = request.headers.get("X-PAYMENT")
        
        if not payment_header:
            return handle_payment_required(settlement_request.asset_amount)
        else:
            return handle_payment_submitted(settlement_request.asset_amount, payment_header)

def handle_payment_required(asset_amount: int) -> tuple:
    """
    Handle initial request without payment - return 402
    
    Returns: (response, status_code, headers)
    """
    # Calculate price (example: 1.10 USDC per YPS token)
    price_per_unit_usdc = 1.10
    
    # Create payment requirement
    payment_req = create_x402_payment_requirement(
        asset_amount=asset_amount,
        price_per_unit_usdc=price_per_unit_usdc,
        seller_address=seller_account.address,
        asset_token_address=config.YIELD_POOL_SHARE_ADDRESS,
        settlement_vault_address=config.SETTLEMENT_VAULT_ADDRESS,
        mock_usdc_address=config.MOCK_USDC_ADDRESS,
        deadline_seconds=3600,
    )
    
    response_body, status_code, headers = create_x402_response(payment_req)
    
    print(f"\n[402] Payment required for {asset_amount} YPS")
    print(f"Required USDC: {payment_req.required_amount / 10**6}")
    
    return jsonify(response_body), status_code, headers

def handle_payment_submitted(asset_amount: int, payment_header: str) -> tuple:
    """
    Handle request with payment proof - execute settlement
    
    Returns: (response, status_code)
    """
    # Parse payment proof
    payment_proof = parse_x402_payment_header(payment_header)
    
    if not payment_proof:
        return jsonify({"error": "Invalid X-PAYMENT header"}), 400
    
    print(f"\n[PAYMENT] Received payment proof from {payment_proof.client_address}")
    print(f"Max EURC payment: {payment_proof.max_payment_amount / 10**6}")
    
    # Calculate required USDC
    price_per_unit_usdc = 1.10
    asset_human = asset_amount / (10 ** 18)
    required_usdc_human = asset_human * price_per_unit_usdc
    required_usdc = int(required_usdc_human * (10 ** 6))
    
    # Calculate max EURC (add 10% buffer for exchange rate)
    max_eurc = int(required_usdc * 1.10 * 1.1)
    
    # Validate payment proof
    if payment_proof.max_payment_amount < max_eurc:
        return jsonify({
            "error": "Insufficient payment",
            "required_usdc": required_usdc,
            "max_eurc": max_eurc,
            "provided_eurc": payment_proof.max_payment_amount,
        }), 400
    
    # Create settlement on-chain
    try:
        settlement_id = create_settlement(
            client_address=payment_proof.client_address,
            asset_amount=asset_amount,
            required_usdc=required_usdc,
            max_eurc=max_eurc,
        )
        
        # Store settlement info
        active_settlements[settlement_id] = {
            "client": payment_proof.client_address,
            "asset_amount": asset_amount,
            "required_usdc": required_usdc,
            "max_eurc": max_eurc,
            "status": "pending",
            "created_at": int(time.time()),
        }
        
        response = SettlementResponse(
            settlement_id=settlement_id,
            status="created",
            message="Settlement created successfully",
            required_usdc=required_usdc,
            max_eurc=max_eurc,
            asset_amount=asset_amount,
        )
        
        print(f"[SUCCESS] Settlement created: {settlement_id}")
        
        return jsonify(response.model_dump()), 200
        
    except Exception as e:
        print(f"[ERROR] Failed to create settlement: {e}")
        return jsonify({"error": f"Settlement failed: {str(e)}"}), 500

def create_settlement(
    client_address: str,
    asset_amount: int,
    required_usdc: int,
    max_eurc: int,
) -> str:
    """
    Create a settlement on-chain via SettlementVault
    
    Returns: settlement_id (bytes32 as hex string)
    """
    # Load vault contract
    vault_abi = web3_utils.load_abi("SettlementVault")
    vault = web3_utils.get_contract(config.SETTLEMENT_VAULT_ADDRESS, vault_abi)
    
    # Create settlement transaction
    # Note: This assumes the seller/facilitator has permission to create settlements
    tx_hash = web3_utils.send_transaction(
        contract=vault,
        function_name="createSettlement",
        args=[
            client_address,
            seller_account.address,
            config.YIELD_POOL_SHARE_ADDRESS,
            asset_amount,
            required_usdc,
            max_eurc,
        ],
        private_key=config.FACILITATOR_PRIVATE_KEY,
    )
    
    print(f"[TX] Settlement creation tx: {tx_hash}")
    
    # Wait for transaction
    receipt = web3_utils.wait_for_transaction(tx_hash)
    
    # Extract settlement ID from logs
    # Parse SettlementCreated event
    settlement_created_event = vault.events.SettlementCreated()
    logs = settlement_created_event.process_receipt(receipt)
    
    if logs:
        settlement_id = logs[0]['args']['settlementId'].hex()
        return settlement_id
    else:
        raise Exception("Failed to get settlement ID from transaction")

@app.route("/settlement/<settlement_id>", methods=["GET"])
def get_settlement(settlement_id: str):
    """Get settlement status"""
    
    if settlement_id not in active_settlements:
        # Try to fetch from contract
        try:
            vault_abi = web3_utils.load_abi("SettlementVault")
            vault = web3_utils.get_contract(config.SETTLEMENT_VAULT_ADDRESS, vault_abi)
            
            settlement_data = vault.functions.getSettlement(bytes.fromhex(settlement_id[2:])).call()
            
            return jsonify({
                "settlement_id": settlement_id,
                "status": "on-chain",
                "data": settlement_data,
            })
        except Exception as e:
            return jsonify({"error": "Settlement not found"}), 404
    
    return jsonify(active_settlements[settlement_id])

def run_server():
    """Run the Flask server"""
    init_server()
    app.run(
        host=config.HTTP_SERVER_HOST,
        port=config.HTTP_SERVER_PORT,
        debug=True,
    )

if __name__ == "__main__":
    run_server()

