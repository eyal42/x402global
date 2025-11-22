"""Configuration management for x402 OTC API"""
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class Config:
    """Configuration class for the x402 OTC API system"""
    
    # Network
    RPC_URL = os.getenv("RPC_URL", "https://rpc-amoy.polygon.technology")
    CHAIN_ID = int(os.getenv("CHAIN_ID", "80002"))  # Polygon Amoy
    
    # Contract Addresses
    MOCK_EURC_ADDRESS = os.getenv("MOCK_EURC_ADDRESS_POLYGON")
    MOCK_USDC_ADDRESS = os.getenv("MOCK_USDC_ADDRESS_POLYGON")
    YPS_ADDRESS = os.getenv("YPS_ADDRESS")
    SWAP_SIMULATOR_ADDRESS = os.getenv("SWAP_SIMULATOR_ADDRESS")
    SETTLEMENT_VAULT_ADDRESS = os.getenv("SETTLEMENT_VAULT_ADDRESS")
    
    # ============ Role-Based Configuration ============
    
    # FACILITATOR (Server/Orchestrator)
    # - Runs the HTTP server
    # - Owns SettlementVault contract
    # - Orchestrates transactions
    FACILITATOR_PRIVATE_KEY = os.getenv("FACILITATOR_PRIVATE_KEY")
    FACILITATOR_ADDRESS = os.getenv("FACILITATOR_ADDRESS")
    
    # SELLER (Asset Provider)
    # - Provides YPS tokens
    # - Receives MockUSDC settlement
    SELLER_PRIVATE_KEY = os.getenv("SELLER_PRIVATE_KEY")
    SELLER_ADDRESS = os.getenv("SELLER_ADDRESS")
    
    # CLIENT (Buyer)
    # - Buys assets
    # - Pays with MockEURC
    # - Receives YPS tokens
    CLIENT_PRIVATE_KEY = os.getenv("CLIENT_PRIVATE_KEY")
    CLIENT_ADDRESS = os.getenv("CLIENT_ADDRESS")
    
    # Server Settings
    SERVER_HOST = os.getenv("SERVER_HOST", "127.0.0.1")
    SERVER_PORT = int(os.getenv("SERVER_PORT", "5000"))
    
    # Asset Pricing (in MockUSDC, 6 decimals)
    ASSET_PRICE_USDC = int(os.getenv("ASSET_PRICE_USDC", str(100 * 10**6)))  # 100 USDC per YPS token
    
    # EUR/USD Exchange Rate API (optional, for client)
    EUR_USD_RATE_API = os.getenv("EUR_USD_RATE_API", "")
    DEFAULT_EUR_USD_RATE = float(os.getenv("DEFAULT_EUR_USD_RATE", "1.05"))  # 1 EUR = 1.05 USD
    
    # Payment deadline (in seconds)
    PAYMENT_DEADLINE_SECONDS = int(os.getenv("PAYMENT_DEADLINE_SECONDS", "3600"))  # 1 hour
    
    @classmethod
    def validate(cls, role: str = "all"):
        """
        Validate that all required configuration is present
        
        Args:
            role: Which role to validate for ("facilitator", "client", "seller", or "all")
        """
        # Common required fields
        required = [
            "MOCK_EURC_ADDRESS",
            "MOCK_USDC_ADDRESS",
            "YPS_ADDRESS",
            "SWAP_SIMULATOR_ADDRESS",
            "SETTLEMENT_VAULT_ADDRESS"
        ]
        
        # Role-specific requirements
        if role in ["facilitator", "all"]:
            required.extend(["FACILITATOR_PRIVATE_KEY", "FACILITATOR_ADDRESS"])
        
        if role in ["seller", "all"]:
            required.extend(["SELLER_ADDRESS"])
        
        if role in ["client", "all"]:
            required.extend(["CLIENT_PRIVATE_KEY", "CLIENT_ADDRESS"])
        
        missing = []
        for field in required:
            if not getattr(cls, field):
                missing.append(field)
        
        if missing:
            raise ValueError(f"Missing required configuration: {', '.join(missing)}")
        
        return True

