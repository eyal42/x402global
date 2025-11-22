"""
Real-time Event Tracker for x402 OTC API
Monitors on-chain events and displays live progress
"""
import os
import sys
import time
import json
from datetime import datetime
from web3 import Web3
from typing import Dict, List

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from common.config import Config
from common.contracts import get_contract, SETTLEMENT_VAULT_ABI, SWAP_SIMULATOR_ABI


class EventTracker:
    """Tracks and displays on-chain events for the x402 flow"""
    
    def __init__(self):
        self.w3 = Web3(Web3.HTTPProvider(Config.RPC_URL))
        
        # Load contracts
        self.vault_contract = get_contract(self.w3, Config.SETTLEMENT_VAULT_ADDRESS, SETTLEMENT_VAULT_ABI)
        self.simulator_contract = get_contract(self.w3, Config.SWAP_SIMULATOR_ADDRESS, SWAP_SIMULATOR_ABI)
        
        # Track events
        self.events = []
        self.orders = {}
        
        print(f"Event Tracker initialized")
        print(f"Vault: {Config.SETTLEMENT_VAULT_ADDRESS}")
        print(f"Simulator: {Config.SWAP_SIMULATOR_ADDRESS}")
        print(f"Chain ID: {Config.CHAIN_ID}")
        print()
        
    def format_timestamp(self, timestamp: int = None) -> str:
        """Format timestamp for display"""
        if timestamp is None:
            timestamp = time.time()
        return datetime.fromtimestamp(timestamp).strftime('%H:%M:%S')
    
    def format_event(self, event_name: str, data: dict) -> str:
        """Format event for display"""
        timestamp = self.format_timestamp()
        
        if event_name == "PaymentRequested":
            order_id = data['orderId'].hex()
            client = data['client']
            amount = data['requiredAmount']
            deadline = data['deadline']
            return f"[{timestamp}] 💳 Payment Requested - Order: {order_id[:8]}... Client: {client[:8]}... Amount: {amount / 10**6} USDC"
        
        elif event_name == "PermitConsumed":
            order_id = data['orderId'].hex()
            client = data['client']
            amount = data['amount']
            return f"[{timestamp}] ✍️  Permit Signed & Consumed - Order: {order_id[:8]}... Amount: {amount / 10**6} EURC"
        
        elif event_name == "FundsPulled":
            order_id = data['orderId'].hex()
            amount = data['amount']
            return f"[{timestamp}] 💰 Funds Pulled - Order: {order_id[:8]}... Amount: {amount / 10**6} EURC"
        
        elif event_name == "SwapCompleted":
            order_id = data['orderId'].hex()
            amount_in = data['amountIn']
            amount_out = data['amountOut']
            surplus = data['surplus']
            rate = amount_out / amount_in if amount_in > 0 else 0
            return f"[{timestamp}] 🔄 Swap Completed - Order: {order_id[:8]}... In: {amount_in / 10**6} EURC, Out: {amount_out / 10**6} USDC (Rate: {rate:.4f})"
        
        elif event_name == "VaultFunded":
            order_id = data['orderId'].hex()
            amount = data['amount']
            return f"[{timestamp}] 🏦 Vault Funded - Order: {order_id[:8]}... Amount: {amount / 10**6} USDC"
        
        elif event_name == "AssetReleased":
            order_id = data['orderId'].hex()
            client = data['client']
            amount = data['amount']
            return f"[{timestamp}] ✅ Asset Released - Order: {order_id[:8]}... Client: {client[:8]}... Amount: {amount / 10**18} YPS"
        
        elif event_name == "RefundSent":
            order_id = data['orderId'].hex()
            amount = data['amount']
            return f"[{timestamp}] 💸 Refund Sent - Order: {order_id[:8]}... Amount: {amount / 10**6} EURC"
        
        else:
            return f"[{timestamp}] 📋 {event_name}: {json.dumps(data, indent=2)}"
    
    def process_event(self, event):
        """Process and display an event"""
        event_name = event['event']
        event_data = dict(event['args'])
        
        # Format and print
        formatted = self.format_event(event_name, event_data)
        print(formatted)
        
        # Store event
        self.events.append({
            'name': event_name,
            'data': event_data,
            'timestamp': time.time(),
            'block': event['blockNumber'],
            'tx_hash': event['transactionHash'].hex()
        })
        
        # Update order tracking
        if 'orderId' in event_data:
            order_id = event_data['orderId'].hex()
            if order_id not in self.orders:
                self.orders[order_id] = {
                    'events': [],
                    'status': 'pending'
                }
            
            self.orders[order_id]['events'].append(event_name)
            
            # Update status
            if event_name == "AssetReleased":
                self.orders[order_id]['status'] = 'completed'
                print(f"\n{'='*60}")
                print(f"✅ Order {order_id[:8]}... COMPLETED!")
                print(f"{'='*60}\n")
    
    def get_events_from_block(self, from_block: int, to_block: int):
        """Get events from a block range"""
        events = []
        
        # Get vault events
        try:
            vault_events = self.vault_contract.events.PaymentRequested.get_logs(
                fromBlock=from_block, toBlock=to_block
            )
            events.extend(vault_events)
            
            vault_events = self.vault_contract.events.PermitConsumed.get_logs(
                fromBlock=from_block, toBlock=to_block
            )
            events.extend(vault_events)
            
            vault_events = self.vault_contract.events.FundsPulled.get_logs(
                fromBlock=from_block, toBlock=to_block
            )
            events.extend(vault_events)
            
            vault_events = self.vault_contract.events.SwapCompleted.get_logs(
                fromBlock=from_block, toBlock=to_block
            )
            events.extend(vault_events)
            
            vault_events = self.vault_contract.events.VaultFunded.get_logs(
                fromBlock=from_block, toBlock=to_block
            )
            events.extend(vault_events)
            
            vault_events = self.vault_contract.events.AssetReleased.get_logs(
                fromBlock=from_block, toBlock=to_block
            )
            events.extend(vault_events)
            
            vault_events = self.vault_contract.events.RefundSent.get_logs(
                fromBlock=from_block, toBlock=to_block
            )
            events.extend(vault_events)
            
        except Exception as e:
            print(f"Error fetching events: {e}")
        
        # Sort by block number and log index
        events.sort(key=lambda x: (x['blockNumber'], x['logIndex']))
        
        return events
    
    def watch(self, poll_interval: int = 2):
        """Watch for new events in real-time"""
        print(f"\n{'='*60}")
        print(f"🔍 Starting real-time event tracking")
        print(f"{'='*60}\n")
        
        # Get current block
        current_block = self.w3.eth.block_number
        print(f"Starting from block: {current_block}\n")
        
        try:
            while True:
                # Get latest block
                latest_block = self.w3.eth.block_number
                
                if latest_block > current_block:
                    # Get events from new blocks
                    events = self.get_events_from_block(current_block + 1, latest_block)
                    
                    # Process events
                    for event in events:
                        self.process_event(event)
                    
                    current_block = latest_block
                
                # Wait before next poll
                time.sleep(poll_interval)
                
        except KeyboardInterrupt:
            print("\n\nTracking stopped by user")
            self.print_summary()
    
    def print_summary(self):
        """Print summary of tracked events"""
        print(f"\n{'='*60}")
        print(f"📊 Event Tracking Summary")
        print(f"{'='*60}")
        print(f"Total events: {len(self.events)}")
        print(f"Total orders: {len(self.orders)}")
        
        if self.orders:
            print("\nOrder Status:")
            for order_id, order_data in self.orders.items():
                status_emoji = "✅" if order_data['status'] == 'completed' else "⏳"
                print(f"  {status_emoji} {order_id[:16]}... - {order_data['status']} ({len(order_data['events'])} events)")
        
        print()
    
    def track_historical(self, from_block: int = None, to_block: int = None):
        """Track historical events"""
        if from_block is None:
            from_block = self.w3.eth.block_number - 1000  # Last ~1000 blocks
        
        if to_block is None:
            to_block = self.w3.eth.block_number
        
        print(f"\n{'='*60}")
        print(f"📜 Fetching historical events")
        print(f"{'='*60}")
        print(f"From block: {from_block}")
        print(f"To block: {to_block}\n")
        
        events = self.get_events_from_block(from_block, to_block)
        
        if not events:
            print("No events found in this range")
            return
        
        print(f"Found {len(events)} events:\n")
        
        for event in events:
            self.process_event(event)
        
        self.print_summary()


def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='x402 Event Tracker')
    parser.add_argument('--mode', choices=['watch', 'historical'], default='watch',
                       help='Tracking mode (default: watch)')
    parser.add_argument('--from-block', type=int,
                       help='Starting block for historical mode')
    parser.add_argument('--to-block', type=int,
                       help='Ending block for historical mode')
    parser.add_argument('--poll-interval', type=int, default=2,
                       help='Poll interval in seconds for watch mode (default: 2)')
    
    args = parser.parse_args()
    
    # Validate configuration
    try:
        Config.validate()
    except ValueError as e:
        print(f"Configuration error: {e}")
        sys.exit(1)
    
    # Create tracker
    tracker = EventTracker()
    
    # Run in selected mode
    if args.mode == 'watch':
        tracker.watch(args.poll_interval)
    else:
        tracker.track_historical(args.from_block, args.to_block)


if __name__ == '__main__':
    main()

