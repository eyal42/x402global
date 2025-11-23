"""
Configuration module for OTC API system
"""
import os
from typing import Dict, Any
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Network Configuration
POLYGON_AMOY_RPC_URL = os.getenv("POLYGON_AMOY_RPC_URL", "https://rpc-amoy.polygon.technology/")
CHAIN_ID = 80002  # Polygon Amoy

# Private Keys
SELLER_PRIVATE_KEY = os.getenv("SELLER_PRIVATE_KEY", "")
BUYER_PRIVATE_KEY = os.getenv("BUYER_PRIVATE_KEY", "")
FACILITATOR_PRIVATE_KEY = os.getenv("PRIVATE_KEY", "")

# Contract Addresses
MOCK_USDC_ADDRESS = os.getenv("MOCK_USDC_ADDRESS_POLYGON", "")
MOCK_EURC_ADDRESS = os.getenv("MOCK_EURC_ADDRESS_POLYGON", "")
YIELD_POOL_SHARE_ADDRESS = os.getenv("YIELD_POOL_SHARE_ADDRESS", "")
SETTLEMENT_VAULT_ADDRESS = os.getenv("SETTLEMENT_VAULT_ADDRESS", "")
PERMIT_PULLER_ADDRESS = os.getenv("PERMIT_PULLER_ADDRESS", "")
FACILITATOR_HOOK_ADDRESS = os.getenv("FACILITATOR_HOOK_ADDRESS", "")

# API Configuration
EUR_USD_PRICE_API_URL = os.getenv("EUR_USD_PRICE_API_URL", "https://api.exchangerate-api.com/v4/latest/EUR")
HTTP_SERVER_PORT = int(os.getenv("HTTP_SERVER_PORT", "8402"))
HTTP_SERVER_HOST = os.getenv("HTTP_SERVER_HOST", "0.0.0.0")

# Finality Configuration
FINALITY_CONFIRMATIONS = int(os.getenv("FINALITY_CONFIRMATIONS", "10"))
FINALITY_CHECK_INTERVAL_SECONDS = int(os.getenv("FINALITY_CHECK_INTERVAL_SECONDS", "30"))

# Token Decimals
MOCK_USDC_DECIMALS = 6
MOCK_EURC_DECIMALS = 6
YIELD_POOL_SHARE_DECIMALS = 18

def validate_config() -> bool:
    """Validate that all required configuration is present"""
    required_vars = {
        "POLYGON_AMOY_RPC_URL": POLYGON_AMOY_RPC_URL,
        "MOCK_USDC_ADDRESS": MOCK_USDC_ADDRESS,
        "MOCK_EURC_ADDRESS": MOCK_EURC_ADDRESS,
    }
    
    missing = [name for name, value in required_vars.items() if not value]
    
    if missing:
        print(f"Missing required configuration: {', '.join(missing)}")
        return False
    
    return True

def get_config_summary() -> Dict[str, Any]:
    """Get a summary of current configuration"""
    return {
        "network": {
            "rpc_url": POLYGON_AMOY_RPC_URL,
            "chain_id": CHAIN_ID,
        },
        "contracts": {
            "mock_usdc": MOCK_USDC_ADDRESS,
            "mock_eurc": MOCK_EURC_ADDRESS,
            "yield_pool_share": YIELD_POOL_SHARE_ADDRESS,
            "settlement_vault": SETTLEMENT_VAULT_ADDRESS,
            "permit_puller": PERMIT_PULLER_ADDRESS,
            "facilitator_hook": FACILITATOR_HOOK_ADDRESS,
        },
        "api": {
            "eur_usd_api": EUR_USD_PRICE_API_URL,
            "server_host": HTTP_SERVER_HOST,
            "server_port": HTTP_SERVER_PORT,
        },
        "finality": {
            "confirmations": FINALITY_CONFIRMATIONS,
            "check_interval": FINALITY_CHECK_INTERVAL_SECONDS,
        }
    }

