"""
OTC API HTTP Client implementing x402 protocol
Buyer-side client that purchases assets via HTTP
"""
import json
import time
import requests
from typing import Optional, Dict, Any
from eth_account import Account
from datetime import datetime, timedelta
import config
import web3_utils
from x402_types import (
    X402PaymentRequirement,
    X402PaymentProof,
    PermitSignature,
    create_x402_payment_header,
)

class OTCClient:
    """Client for purchasing assets via OTC API"""
    
    def __init__(self, private_key: str, server_url: str):
        """
        Initialize OTC client
        
        Args:
            private_key: Buyer's private key
            server_url: OTC server URL (e.g., http://localhost:8402)
        """
        self.account = Account.from_key(private_key)
        self.server_url = server_url.rstrip("/")
        print(f"Client initialized as buyer: {self.account.address}")
    
    def buy_asset(self, asset_amount: int, max_eurc_budget: Optional[int] = None) -> Dict[str, Any]:
        """
        Purchase asset via OTC API using x402 protocol
        
        Args:
            asset_amount: Amount of asset to purchase (in smallest unit)
            max_eurc_budget: Maximum MockEURC willing to pay (optional)
        
        Returns:
            Settlement information
        """
        print(f"\n{'='*60}")
        print(f"PURCHASING ASSET")
        print(f"{'='*60}")
        print(f"Asset Amount: {asset_amount / 10**18} YPS")
        print(f"Buyer: {self.account.address}")
        
        # Step 1: Initial request to get payment requirements
        print(f"\n[STEP 1] Requesting payment requirements...")
        payment_req = self._request_payment_requirements(asset_amount)
        
        if not payment_req:
            raise Exception("Failed to get payment requirements")
        
        print(f"Required USDC: {payment_req.required_amount / 10**6}")
        print(f"Seller: {payment_req.seller}")
        print(f"Deadline: {datetime.fromtimestamp(payment_req.payment_deadline)}")
        
        # Step 2: Calculate EUR/USD rate and determine max EURC budget
        print(f"\n[STEP 2] Calculating EUR/USD rate...")
        eur_usd_rate = self._get_eur_usd_rate()
        print(f"EUR/USD Rate: {eur_usd_rate}")
        
        # Calculate max EURC willing to pay (add buffer for slippage)
        required_usdc = payment_req.required_amount / 10**6
        required_eurc = required_usdc / eur_usd_rate
        max_eurc_with_buffer = required_eurc * 1.15  # 15% slippage buffer
        
        if max_eurc_budget is None:
            max_eurc_budget = int(max_eurc_with_buffer * 10**6)
        
        print(f"Max EURC Budget: {max_eurc_budget / 10**6}")
        
        # Step 3: Check balance
        print(f"\n[STEP 3] Checking MockEURC balance...")
        eurc_balance = web3_utils.get_balance(self.account.address, config.MOCK_EURC_ADDRESS)
        print(f"MockEURC Balance: {eurc_balance / 10**6}")
        
        if eurc_balance < max_eurc_budget:
            raise Exception(f"Insufficient MockEURC balance. Need {max_eurc_budget / 10**6}, have {eurc_balance / 10**6}")
        
        # Step 4: Create EIP-2612 permit signature
        print(f"\n[STEP 4] Creating EIP-2612 permit signature...")
        deadline = int((datetime.now() + timedelta(hours=1)).timestamp())
        
        v, r, s = web3_utils.create_permit_signature(
            token_address=config.MOCK_EURC_ADDRESS,
            owner_address=self.account.address,
            spender_address=config.PERMIT_PULLER_ADDRESS,
            value=max_eurc_budget,
            deadline=deadline,
            private_key=self.account.key.hex(),
        )
        
        permit_sig = PermitSignature(
            deadline=deadline,
            v=v,
            r=r.hex(),
            s=s.hex(),
        )
        
        print(f"Permit signature created (deadline: {datetime.fromtimestamp(deadline)})")
        
        # Step 5: Create payment proof
        print(f"\n[STEP 5] Creating x402 payment proof...")
        payment_proof = X402PaymentProof(
            client_address=self.account.address,
            payment_token=config.MOCK_EURC_ADDRESS,
            payment_token_symbol="MockEURC",
            max_payment_amount=max_eurc_budget,
            permit_signature=permit_sig.model_dump(),
            timestamp=int(time.time()),
        )
        
        # Step 6: Submit payment and execute settlement
        print(f"\n[STEP 6] Submitting payment to server...")
        settlement_result = self._submit_payment(asset_amount, payment_proof)
        
        print(f"\n{'='*60}")
        print(f"SETTLEMENT CREATED")
        print(f"{'='*60}")
        print(f"Settlement ID: {settlement_result.get('settlement_id')}")
        print(f"Status: {settlement_result.get('status')}")
        print(f"Required USDC: {settlement_result.get('required_usdc', 0) / 10**6}")
        print(f"Max EURC: {settlement_result.get('max_eurc', 0) / 10**6}")
        print(f"{'='*60}\n")
        
        return settlement_result
    
    def _request_payment_requirements(self, asset_amount: int) -> Optional[X402PaymentRequirement]:
        """
        Request payment requirements from server (expect 402 response)
        
        Returns:
            X402PaymentRequirement object
        """
        url = f"{self.server_url}/buy-asset?amount={asset_amount}"
        
        try:
            response = requests.get(url)
            
            if response.status_code == 402:
                # Expected 402 Payment Required
                data = response.json()
                payment_req_data = data.get("payment_requirement")
                
                if payment_req_data:
                    return X402PaymentRequirement(**payment_req_data)
            else:
                print(f"Unexpected status code: {response.status_code}")
                print(f"Response: {response.text}")
        
        except Exception as e:
            print(f"Error requesting payment requirements: {e}")
        
        return None
    
    def _submit_payment(self, asset_amount: int, payment_proof: X402PaymentProof) -> Dict[str, Any]:
        """
        Submit payment proof to server
        
        Returns:
            Settlement result
        """
        url = f"{self.server_url}/buy-asset?amount={asset_amount}"
        
        # Create X-PAYMENT header
        payment_header = create_x402_payment_header(payment_proof)
        
        headers = {
            "X-PAYMENT": payment_header,
            "Content-Type": "application/json",
        }
        
        try:
            response = requests.get(url, headers=headers)
            
            if response.status_code == 200:
                return response.json()
            else:
                print(f"Error: {response.status_code}")
                print(f"Response: {response.text}")
                raise Exception(f"Payment submission failed: {response.text}")
        
        except Exception as e:
            print(f"Error submitting payment: {e}")
            raise
    
    def _get_eur_usd_rate(self) -> float:
        """
        Get EUR/USD exchange rate from API
        
        Returns:
            EUR/USD rate
        """
        try:
            response = requests.get(config.EUR_USD_PRICE_API_URL, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                # The API returns rates with EUR as base
                # We want USD rate (how many USD per EUR)
                usd_rate = data.get("rates", {}).get("USD", 1.10)
                return usd_rate
            else:
                print(f"Warning: Failed to get EUR/USD rate, using default 1.10")
                return 1.10
        
        except Exception as e:
            print(f"Warning: Error fetching EUR/USD rate: {e}, using default 1.10")
            return 1.10
    
    def get_settlement_status(self, settlement_id: str) -> Dict[str, Any]:
        """
        Get settlement status from server
        
        Args:
            settlement_id: Settlement identifier
        
        Returns:
            Settlement status
        """
        url = f"{self.server_url}/settlement/{settlement_id}"
        
        try:
            response = requests.get(url)
            
            if response.status_code == 200:
                return response.json()
            else:
                raise Exception(f"Failed to get settlement status: {response.text}")
        
        except Exception as e:
            print(f"Error getting settlement status: {e}")
            raise

def main():
    """Example usage of OTC client"""
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python client.py <asset_amount>")
        print("Example: python client.py 100000000000000000000  # 100 YPS")
        return
    
    asset_amount = int(sys.argv[1])
    
    # Initialize client
    server_url = f"http://{config.HTTP_SERVER_HOST}:{config.HTTP_SERVER_PORT}"
    client = OTCClient(config.BUYER_PRIVATE_KEY, server_url)
    
    # Purchase asset
    try:
        result = client.buy_asset(asset_amount)
        print(f"\nSuccess! Settlement ID: {result.get('settlement_id')}")
    except Exception as e:
        print(f"\nError: {e}")

if __name__ == "__main__":
    main()

