"""
x402 Protocol Types and Structures
"""
from typing import Dict, Any, Optional
from pydantic import BaseModel, Field
from datetime import datetime, timedelta

class X402PaymentRequirement(BaseModel):
    """
    x402 Payment Requirement object
    Describes what payment is required to access the resource
    """
    version: str = "1.0"
    chain: str = "polygon-amoy"
    chain_id: int = 80002
    settlement_token: str  # MockUSDC address
    settlement_token_symbol: str = "MockUSDC"
    required_amount: int  # Amount in smallest unit
    settlement_vault: str  # SettlementVault address
    payment_deadline: int  # Unix timestamp
    resource: str  # Resource being purchased
    asset_token: str  # YieldPoolShare address
    asset_amount: int  # Amount of asset
    seller: str  # Seller address
    metadata: Optional[Dict[str, Any]] = None

class X402PaymentProof(BaseModel):
    """
    x402 Payment Proof object
    Provided by client to prove payment intent/capability
    """
    version: str = "1.0"
    client_address: str
    payment_token: str  # MockEURC address
    payment_token_symbol: str = "MockEURC"
    max_payment_amount: int  # Maximum EURC willing to pay
    permit_signature: Dict[str, Any]  # EIP-2612 permit signature
    timestamp: int
    settlement_id: Optional[str] = None

class SettlementRequest(BaseModel):
    """Request to purchase assets via OTC"""
    asset_amount: int  # Amount of asset to purchase (in smallest unit)
    client_address: str
    max_eurc_payment: Optional[int] = None  # Optional max EURC willing to pay

class SettlementResponse(BaseModel):
    """Response after settlement is created"""
    settlement_id: str
    status: str
    message: str
    required_usdc: int
    max_eurc: int
    asset_amount: int
    tx_hash: Optional[str] = None

class PermitSignature(BaseModel):
    """EIP-2612 Permit Signature"""
    deadline: int
    v: int
    r: str  # hex string
    s: str  # hex string

def create_x402_payment_requirement(
    asset_amount: int,
    price_per_unit_usdc: float,
    seller_address: str,
    asset_token_address: str,
    settlement_vault_address: str,
    mock_usdc_address: str,
    deadline_seconds: int = 3600
) -> X402PaymentRequirement:
    """
    Create an x402 Payment Requirement object
    
    Args:
        asset_amount: Amount of asset to sell (in smallest unit, e.g., 18 decimals)
        price_per_unit_usdc: Price per unit in USDC (human-readable, e.g., 1.10)
        seller_address: Seller's address
        asset_token_address: Asset token contract address
        settlement_vault_address: Settlement vault contract address
        mock_usdc_address: MockUSDC token address
        deadline_seconds: Payment deadline from now (seconds)
    
    Returns:
        X402PaymentRequirement object
    """
    # Calculate required USDC (assuming 18 decimals for asset, 6 for USDC)
    # Convert asset amount to human-readable, multiply by price, convert to USDC decimals
    asset_human = asset_amount / (10 ** 18)
    required_usdc_human = asset_human * price_per_unit_usdc
    required_usdc_smallest = int(required_usdc_human * (10 ** 6))
    
    deadline = int((datetime.now() + timedelta(seconds=deadline_seconds)).timestamp())
    
    return X402PaymentRequirement(
        chain="polygon-amoy",
        chain_id=80002,
        settlement_token=mock_usdc_address,
        settlement_token_symbol="MockUSDC",
        required_amount=required_usdc_smallest,
        settlement_vault=settlement_vault_address,
        payment_deadline=deadline,
        resource=f"/buy-asset?amount={asset_amount}",
        asset_token=asset_token_address,
        asset_amount=asset_amount,
        seller=seller_address,
        metadata={
            "price_per_unit_usdc": price_per_unit_usdc,
            "asset_decimals": 18,
            "settlement_decimals": 6,
        }
    )

def create_x402_response(payment_requirement: X402PaymentRequirement) -> tuple[str, int, dict]:
    """
    Create an HTTP 402 response with x402 payment requirements
    
    Returns:
        (response_body, status_code, headers)
    """
    headers = {
        "Content-Type": "application/json",
        "WWW-Authenticate": 'x402 realm="OTC Asset Purchase"',
        "X-Payment-Required": "true",
    }
    
    response_body = {
        "error": "Payment Required",
        "message": "Payment required to access this resource",
        "payment_requirement": payment_requirement.model_dump(),
    }
    
    return (response_body, 402, headers)

def parse_x402_payment_header(payment_header: str) -> Optional[X402PaymentProof]:
    """
    Parse X-PAYMENT header from client request
    
    Expected format: "x402 <base64_encoded_json>"
    """
    import json
    import base64
    
    if not payment_header.startswith("x402 "):
        return None
    
    try:
        encoded_data = payment_header[5:]  # Remove "x402 " prefix
        decoded_data = base64.b64decode(encoded_data)
        payment_data = json.loads(decoded_data)
        return X402PaymentProof(**payment_data)
    except Exception as e:
        print(f"Error parsing X-PAYMENT header: {e}")
        return None

def create_x402_payment_header(payment_proof: X402PaymentProof) -> str:
    """
    Create X-PAYMENT header value from payment proof
    
    Returns: "x402 <base64_encoded_json>"
    """
    import json
    import base64
    
    json_data = payment_proof.model_dump_json()
    encoded_data = base64.b64encode(json_data.encode()).decode()
    
    return f"x402 {encoded_data}"

