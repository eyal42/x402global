"""
x402 OTC API Client
Makes requests to buy assets using EIP-2612 gasless approvals
"""
import os
import sys
import json
import time
import requests
from web3 import Web3
from eth_account import Account
from eth_account.messages import encode_typed_data

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from common.config import Config
from common.contracts import get_contract, ERC20_PERMIT_ABI


class X402Client:
    """Client for making x402 payment requests"""
    
    def __init__(self, server_url: str, private_key: str = None, client_address: str = None):
        self.server_url = server_url
        self.w3 = Web3(Web3.HTTPProvider(Config.RPC_URL))
        
        # Use provided key or get from config
        if private_key:
            self.account = Account.from_key(private_key)
        else:
            self.account = Account.from_key(Config.CLIENT_PRIVATE_KEY)
        
        # Verify address matches config if provided
        if client_address and client_address.lower() != self.account.address.lower():
            print(f"Warning: Provided address {client_address} doesn't match private key address {self.account.address}")
        
        print(f"=== x402 Client (Buyer) ===")
        print(f"Client Address: {self.account.address}")
        print(f"Server: {server_url}")
        print(f"Role: Buyer (pays EURC, receives YPS)\n")
        
        # Load MockEURC contract
        self.mock_eurc = get_contract(self.w3, Config.MOCK_EURC_ADDRESS, ERC20_PERMIT_ABI)
        
    def get_eur_usd_rate(self) -> float:
        """Get EUR/USD exchange rate (simulated or from API)"""
        # In production, this would call a real API
        # For demo, use configured rate
        return Config.DEFAULT_EUR_USD_RATE
    
    def sign_eip2612_permit(
        self,
        token_address: str,
        spender: str,
        amount: int,
        deadline: int
    ) -> dict:
        """Sign EIP-2612 permit for gasless approval"""
        
        # Get nonce
        nonce = self.mock_eurc.functions.nonces(self.account.address).call()
        
        # Get token name for EIP-712 domain
        token_name = self.mock_eurc.functions.name().call()
        
        # Create EIP-712 typed data for permit
        permit_data = {
            "types": {
                "EIP712Domain": [
                    {"name": "name", "type": "string"},
                    {"name": "version", "type": "string"},
                    {"name": "chainId", "type": "uint256"},
                    {"name": "verifyingContract", "type": "address"}
                ],
                "Permit": [
                    {"name": "owner", "type": "address"},
                    {"name": "spender", "type": "address"},
                    {"name": "value", "type": "uint256"},
                    {"name": "nonce", "type": "uint256"},
                    {"name": "deadline", "type": "uint256"}
                ]
            },
            "domain": {
                "name": token_name,
                "version": "1",
                "chainId": Config.CHAIN_ID,
                "verifyingContract": token_address
            },
            "primaryType": "Permit",
            "message": {
                "owner": self.account.address,
                "spender": spender,
                "value": amount,
                "nonce": nonce,
                "deadline": deadline
            }
        }
        
        # Sign typed data
        encoded_data = encode_typed_data(full_message=permit_data)
        signed_message = self.account.sign_message(encoded_data)
        
        # Return signature components
        # Handle both int and bytes types for r and s (eth-account version compatibility)
        r_value = signed_message.r if isinstance(signed_message.r, int) else int.from_bytes(signed_message.r, 'big')
        s_value = signed_message.s if isinstance(signed_message.s, int) else int.from_bytes(signed_message.s, 'big')
        
        # Convert to hex and pad to 64 characters (32 bytes), remove '0x' prefix
        r_hex = format(r_value, '064x')  # Pad to 64 hex chars
        s_hex = format(s_value, '064x')  # Pad to 64 hex chars
        
        return {
            "v": signed_message.v,
            "r": r_hex,
            "s": s_hex,
            "amount": str(amount),
            "deadline": deadline,
            "nonce": nonce
        }
    
    def buy_asset(self, amount: float) -> dict:
        """
        Buy asset using x402 flow
        
        Args:
            amount: Amount of asset to buy (in tokens, not wei)
        
        Returns:
            Response from server
        """
        print(f"\n=== Starting x402 Purchase ===")
        print(f"Requesting {amount} YPS tokens")
        
        # Step 1: Make initial request (expect 402)
        print("\nStep 1: Making initial request...")
        url = f"{self.server_url}/buy-asset"
        params = {
            "client": self.account.address,
            "amount": str(amount)
        }
        
        response = requests.get(url, params=params)
        
        if response.status_code != 402:
            print(f"Unexpected response: {response.status_code}")
            return response.json()
        
        print("Received HTTP 402 Payment Required")
        
        # Step 2: Parse payment requirements
        payment_req = response.json()
        print("\nStep 2: Payment Requirements:")
        print(json.dumps(payment_req, indent=2))
        
        required_usdc = int(payment_req['amount'])
        deadline = payment_req['deadline']
        vault_address = payment_req['vault']
        order_id = payment_req['order_id']
        
        # Step 3: Get EUR/USD rate and calculate max EURC payment
        print("\nStep 3: Calculating payment amount...")
        eur_usd_rate = self.get_eur_usd_rate()
        print(f"EUR/USD rate: {eur_usd_rate}")
        
        # Required USDC (6 decimals) / EUR_USD_rate = Required EURC (6 decimals)
        # Add 5% buffer for price movement
        required_eurc = int(required_usdc / eur_usd_rate * 1.05)
        print(f"Required USDC: {required_usdc / 10**6}")
        print(f"Max EURC payment (with buffer): {required_eurc / 10**6}")
        
        # Check balance
        balance = self.mock_eurc.functions.balanceOf(self.account.address).call()
        print(f"Current EURC balance: {balance / 10**6}")
        
        if balance < required_eurc:
            print("Insufficient EURC balance!")
            return {"error": "Insufficient balance"}
        
        # Step 4: Sign EIP-2612 permit
        print("\nStep 4: Signing EIP-2612 permit...")
        permit_signature = self.sign_eip2612_permit(
            Config.MOCK_EURC_ADDRESS,
            vault_address,
            required_eurc,
            deadline
        )
        print("Permit signed (gasless approval)")
        
        # Step 5: Retry request with payment
        print("\nStep 5: Submitting payment...")
        payment_payload = {
            "order_id": order_id,
            "permit_signature": permit_signature
        }
        
        headers = {
            "X-PAYMENT": json.dumps(payment_payload)
        }
        
        response = requests.get(url, params=params, headers=headers)
        
        if response.status_code == 200:
            print("\n✅ Purchase successful!")
            result = response.json()
            print("\nTransaction Details:")
            print(f"Order ID: {result['order_id']}")
            print(f"Asset received: {int(result['asset_amount']) / 10**18} YPS")
            print(f"Payment: {int(result['payment_amount']) / 10**6} EURC")
            print(f"Settlement: {int(result['settlement_amount']) / 10**6} USDC")
            print("\nTransaction Hashes:")
            for key, tx_hash in result['transactions'].items():
                print(f"  {key}: {tx_hash}")
            
            return result
        else:
            print(f"\n❌ Purchase failed: {response.status_code}")
            print(response.text)
            return response.json()


def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='x402 OTC API Client (Buyer)')
    parser.add_argument('--server', default='http://127.0.0.1:5000',
                       help='Server URL (default: http://127.0.0.1:5000)')
    parser.add_argument('--amount', type=float, default=1.0,
                       help='Amount of YPS tokens to buy (default: 1.0)')
    parser.add_argument('--private-key', default=None,
                       help='Client private key (default: from CLIENT_PRIVATE_KEY env)')
    
    args = parser.parse_args()
    
    # Validate client configuration
    try:
        Config.validate(role="client")
    except ValueError as e:
        print(f"Configuration error: {e}")
        print("\nMake sure CLIENT_PRIVATE_KEY and CLIENT_ADDRESS are set in .env")
        sys.exit(1)
    
    # Create client
    client = X402Client(
        args.server, 
        args.private_key if args.private_key else Config.CLIENT_PRIVATE_KEY,
        Config.CLIENT_ADDRESS
    )
    
    # Make purchase
    result = client.buy_asset(args.amount)
    
    # Print final result
    print("\n" + "="*50)
    print("FINAL RESULT:")
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()

