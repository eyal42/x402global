"""
Off-chain Facilitator for Settlement Orchestration
Monitors events, executes swaps, waits for finality, and settles vaults
"""
import time
import json
from typing import Dict, List, Optional, Any
from eth_account import Account
from web3.logs import DISCARD
import config
import web3_utils
from web3_utils import w3

class Facilitator:
    """
    Off-chain facilitator that orchestrates the settlement process
    
    Responsibilities:
    1. Monitor vault events
    2. Execute MockEURC -> MockUSDC swaps via Uniswap V4
    3. Wait for finality on funded blocks
    4. Execute final settlement after finality
    """
    
    def __init__(self, private_key: str):
        """
        Initialize facilitator
        
        Args:
            private_key: Facilitator's private key
        """
        self.account = Account.from_key(private_key)
        self.running = False
        
        # Load contracts
        self.vault = self._load_vault_contract()
        self.hook = self._load_hook_contract()
        self.permit_puller = self._load_permit_puller_contract()
        
        # Track settlements
        self.pending_settlements: Dict[str, Dict] = {}
        self.funded_settlements: Dict[str, Dict] = {}
        
        print(f"Facilitator initialized: {self.account.address}")
        print(f"Vault: {config.SETTLEMENT_VAULT_ADDRESS}")
        print(f"Hook: {config.FACILITATOR_HOOK_ADDRESS}")
    
    def _load_vault_contract(self):
        """Load SettlementVault contract"""
        abi = web3_utils.load_abi("SettlementVault")
        return web3_utils.get_contract(config.SETTLEMENT_VAULT_ADDRESS, abi)
    
    def _load_hook_contract(self):
        """Load FacilitatorHook contract"""
        abi = web3_utils.load_abi("FacilitatorHook")
        return web3_utils.get_contract(config.FACILITATOR_HOOK_ADDRESS, abi)
    
    def _load_permit_puller_contract(self):
        """Load PermitPuller contract"""
        abi = web3_utils.load_abi("PermitPuller")
        return web3_utils.get_contract(config.PERMIT_PULLER_ADDRESS, abi)
    
    def start(self):
        """Start the facilitator"""
        self.running = True
        print("\n" + "="*60)
        print("FACILITATOR STARTED")
        print("="*60)
        print("Monitoring for settlement events...")
        print(f"Finality confirmations required: {config.FINALITY_CONFIRMATIONS}")
        print(f"Check interval: {config.FINALITY_CHECK_INTERVAL_SECONDS}s")
        print("="*60 + "\n")
        
        self._run_event_loop()
    
    def stop(self):
        """Stop the facilitator"""
        self.running = False
        print("\nFacilitator stopped")
    
    def _run_event_loop(self):
        """Main event loop"""
        last_block = web3_utils.get_block_number()
        
        while self.running:
            try:
                current_block = web3_utils.get_block_number()
                
                # Process new blocks
                if current_block > last_block:
                    self._process_blocks(last_block + 1, current_block)
                    last_block = current_block
                
                # Check finality on funded settlements
                self._check_finality()
                
                # Wait before next iteration
                time.sleep(config.FINALITY_CHECK_INTERVAL_SECONDS)
                
            except KeyboardInterrupt:
                print("\nReceived interrupt signal")
                break
            except Exception as e:
                print(f"Error in event loop: {e}")
                time.sleep(5)
    
    def _process_blocks(self, from_block: int, to_block: int):
        """Process blocks for relevant events"""
        try:
            # Get SettlementCreated events
            settlement_created_filter = self.vault.events.SettlementCreated.create_filter(
                fromBlock=from_block,
                toBlock=to_block
            )
            
            for event in settlement_created_filter.get_all_entries():
                self._handle_settlement_created(event)
            
            # Get FundsPulled events
            funds_pulled_filter = self.vault.events.FundsPulled.create_filter(
                fromBlock=from_block,
                toBlock=to_block
            )
            
            for event in funds_pulled_filter.get_all_entries():
                self._handle_funds_pulled(event)
            
            # Get VaultFunded events
            vault_funded_filter = self.vault.events.VaultFunded.create_filter(
                fromBlock=from_block,
                toBlock=to_block
            )
            
            for event in vault_funded_filter.get_all_entries():
                self._handle_vault_funded(event)
                
        except Exception as e:
            print(f"Error processing blocks {from_block}-{to_block}: {e}")
    
    def _handle_settlement_created(self, event):
        """Handle SettlementCreated event"""
        args = event['args']
        settlement_id = args['settlementId'].hex()
        
        print(f"\n[EVENT] SettlementCreated")
        print(f"  Settlement ID: {settlement_id}")
        print(f"  Client: {args['client']}")
        print(f"  Seller: {args['seller']}")
        print(f"  Asset Amount: {args['assetAmount'] / 10**18}")
        print(f"  Required USDC: {args['requiredUSDC'] / 10**6}")
        print(f"  Max EURC: {args['maxEURC'] / 10**6}")
        
        self.pending_settlements[settlement_id] = {
            "client": args['client'],
            "seller": args['seller'],
            "asset_token": args['assetToken'],
            "asset_amount": args['assetAmount'],
            "required_usdc": args['requiredUSDC'],
            "max_eurc": args['maxEURC'],
            "status": "created",
            "block": event['blockNumber'],
        }
    
    def _handle_funds_pulled(self, event):
        """Handle FundsPulled event - trigger swap"""
        args = event['args']
        settlement_id = args['settlementId'].hex()
        
        print(f"\n[EVENT] FundsPulled")
        print(f"  Settlement ID: {settlement_id}")
        print(f"  EURC Amount: {args['eurcAmount'] / 10**6}")
        print(f"  Asset Amount: {args['assetAmount'] / 10**18}")
        
        if settlement_id in self.pending_settlements:
            self.pending_settlements[settlement_id]['status'] = 'funds_pulled'
            
            # Execute swap
            print(f"\n[ACTION] Triggering swap for settlement {settlement_id}...")
            self._execute_swap(settlement_id)
    
    def _handle_vault_funded(self, event):
        """Handle VaultFunded event - start finality monitoring"""
        args = event['args']
        settlement_id = args['settlementId'].hex()
        
        print(f"\n[EVENT] VaultFunded")
        print(f"  Settlement ID: {settlement_id}")
        print(f"  Client: {args['client']}")
        print(f"  USDC Amount: {args['usdcAmount'] / 10**6}")
        print(f"  Block Number: {args['blockNumber']}")
        
        # Move to funded settlements and start finality monitoring
        if settlement_id in self.pending_settlements:
            settlement = self.pending_settlements.pop(settlement_id)
            settlement['status'] = 'funded'
            settlement['funded_block'] = args['blockNumber']
            settlement['funded_at'] = time.time()
            
            self.funded_settlements[settlement_id] = settlement
            
            print(f"  Waiting for {config.FINALITY_CONFIRMATIONS} confirmations...")
    
    def _execute_swap(self, settlement_id: str):
        """
        Execute MockEURC -> MockUSDC swap via FacilitatorHook
        
        Args:
            settlement_id: Settlement identifier
        """
        try:
            settlement = self.pending_settlements.get(settlement_id)
            if not settlement:
                print(f"Error: Settlement {settlement_id} not found")
                return
            
            # Execute swap via hook
            eurc_amount = settlement['max_eurc']
            min_usdc_out = settlement['required_usdc']
            
            print(f"  Swapping up to {eurc_amount / 10**6} EURC for min {min_usdc_out / 10**6} USDC...")
            
            tx_hash = web3_utils.send_transaction(
                contract=self.hook,
                function_name="executeSwap",
                args=[
                    bytes.fromhex(settlement_id[2:]),  # settlement_id as bytes32
                    eurc_amount,
                    min_usdc_out,
                ],
                private_key=self.account.key.hex(),
            )
            
            print(f"  Swap tx: {tx_hash}")
            
            # Wait for transaction
            receipt = web3_utils.wait_for_transaction(tx_hash)
            
            if receipt['status'] == 1:
                print(f"  ✓ Swap completed successfully")
            else:
                print(f"  ✗ Swap failed")
                
        except Exception as e:
            print(f"Error executing swap: {e}")
    
    def _check_finality(self):
        """Check finality for funded settlements and execute settlement"""
        settlements_to_finalize = []
        
        for settlement_id, settlement in self.funded_settlements.items():
            if settlement['status'] == 'funded':
                funded_block = settlement['funded_block']
                
                if web3_utils.is_block_finalized(funded_block):
                    settlements_to_finalize.append(settlement_id)
        
        # Finalize settlements
        for settlement_id in settlements_to_finalize:
            self._finalize_settlement(settlement_id)
    
    def _finalize_settlement(self, settlement_id: str):
        """
        Finalize settlement after finality is confirmed
        
        Args:
            settlement_id: Settlement identifier
        """
        try:
            settlement = self.funded_settlements[settlement_id]
            
            print(f"\n[ACTION] Finalizing settlement {settlement_id}")
            print(f"  Block {settlement['funded_block']} is now final")
            
            # Step 1: Confirm finality on-chain
            tx_hash = web3_utils.send_transaction(
                contract=self.vault,
                function_name="confirmFinality",
                args=[bytes.fromhex(settlement_id[2:])],
                private_key=self.account.key.hex(),
            )
            
            print(f"  Finality confirmation tx: {tx_hash}")
            receipt = web3_utils.wait_for_transaction(tx_hash)
            
            if receipt['status'] != 1:
                print(f"  ✗ Finality confirmation failed")
                return
            
            print(f"  ✓ Finality confirmed on-chain")
            
            # Step 2: Execute settlement
            print(f"  Executing settlement...")
            
            tx_hash = web3_utils.send_transaction(
                contract=self.vault,
                function_name="executeSettlement",
                args=[bytes.fromhex(settlement_id[2:])],
                private_key=self.account.key.hex(),
            )
            
            print(f"  Settlement execution tx: {tx_hash}")
            receipt = web3_utils.wait_for_transaction(tx_hash)
            
            if receipt['status'] == 1:
                print(f"  ✓ Settlement executed successfully!")
                print(f"\n{'='*60}")
                print(f"SETTLEMENT COMPLETE")
                print(f"{'='*60}")
                print(f"Settlement ID: {settlement_id}")
                print(f"Client: {settlement['client']}")
                print(f"Asset Amount: {settlement['asset_amount'] / 10**18} YPS")
                print(f"USDC Amount: {settlement['required_usdc'] / 10**6}")
                print(f"{'='*60}\n")
                
                # Mark as complete
                settlement['status'] = 'settled'
            else:
                print(f"  ✗ Settlement execution failed")
                
        except Exception as e:
            print(f"Error finalizing settlement: {e}")
    
    def get_status(self) -> Dict[str, Any]:
        """Get facilitator status"""
        return {
            "running": self.running,
            "facilitator": self.account.address,
            "current_block": web3_utils.get_block_number(),
            "pending_settlements": len(self.pending_settlements),
            "funded_settlements": len(self.funded_settlements),
            "settlements": {
                "pending": list(self.pending_settlements.keys()),
                "funded": list(self.funded_settlements.keys()),
            }
        }

def main():
    """Run the facilitator"""
    if not config.FACILITATOR_PRIVATE_KEY:
        print("Error: FACILITATOR_PRIVATE_KEY not set")
        return
    
    facilitator = Facilitator(config.FACILITATOR_PRIVATE_KEY)
    
    try:
        facilitator.start()
    except KeyboardInterrupt:
        print("\nShutting down facilitator...")
        facilitator.stop()

if __name__ == "__main__":
    main()

