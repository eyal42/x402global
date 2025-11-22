"""
Utility functions for x402 OTC API
Includes helper scripts for minting tokens, checking balances, etc.
"""
import os
import sys
from web3 import Web3
from eth_account import Account

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from common.config import Config
from common.contracts import get_contract, ERC20_PERMIT_ABI


def mint_tokens_to_client(client_address: str, eurc_amount: int, usdc_amount: int = 0):
    """
    Mint MockEURC and MockUSDC tokens to a client address
    (Requires admin/minter permissions)
    """
    w3 = Web3(Web3.HTTPProvider(Config.RPC_URL))
    account = Account.from_key(Config.FACILITATOR_PRIVATE_KEY)
    
    mock_eurc = get_contract(w3, Config.MOCK_EURC_ADDRESS, ERC20_PERMIT_ABI)
    mock_usdc = get_contract(w3, Config.MOCK_USDC_ADDRESS, ERC20_PERMIT_ABI)
    
    print(f"Minting tokens to: {client_address}")
    
    # Note: This assumes the account has minting permissions
    # You may need to call this from the contract owner or minter account
    
    if eurc_amount > 0:
        print(f"Minting {eurc_amount / 10**6} MockEURC...")
        # This will fail if account doesn't have minting permissions
        # In that case, use the P01 scripts to mint tokens
        print("⚠️  Please use P01 Mock_Tokens scripts to mint tokens")
        print(f"   cd ../P01-Mock_Tokens")
        print(f"   forge script script/MintTokens.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast")
    
    if usdc_amount > 0:
        print(f"Minting {usdc_amount / 10**6} MockUSDC...")
        print("⚠️  Please use P01 Mock_Tokens scripts to mint tokens")


def check_balances(address: str):
    """Check token balances for an address"""
    w3 = Web3(Web3.HTTPProvider(Config.RPC_URL))
    
    mock_eurc = get_contract(w3, Config.MOCK_EURC_ADDRESS, ERC20_PERMIT_ABI)
    mock_usdc = get_contract(w3, Config.MOCK_USDC_ADDRESS, ERC20_PERMIT_ABI)
    yps_token = get_contract(w3, Config.YPS_ADDRESS, ERC20_PERMIT_ABI)
    
    eurc_balance = mock_eurc.functions.balanceOf(address).call()
    usdc_balance = mock_usdc.functions.balanceOf(address).call()
    yps_balance = yps_token.functions.balanceOf(address).call()
    
    print(f"\nBalances for {address}:")
    print(f"  MockEURC: {eurc_balance / 10**6}")
    print(f"  MockUSDC: {usdc_balance / 10**6}")
    print(f"  YPS: {yps_balance / 10**18}")
    print()


def check_vault_balances():
    """Check vault balances"""
    print("\n=== Vault Balances ===")
    check_balances(Config.SETTLEMENT_VAULT_ADDRESS)


if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='x402 Utilities')
    parser.add_argument('command', choices=['balances', 'vault-balances'],
                       help='Utility command to run')
    parser.add_argument('--address', help='Address to check balances for')
    
    args = parser.parse_args()
    
    if args.command == 'balances':
        if not args.address:
            print("Error: --address required for balances command")
            sys.exit(1)
        check_balances(args.address)
    elif args.command == 'vault-balances':
        check_vault_balances()

