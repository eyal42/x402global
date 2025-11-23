"""
Real-time Event Tracker with Web UI
Tracks and displays settlement progress in real-time
"""
import time
import json
from typing import Dict, List, Any
from flask import Flask, render_template_string, jsonify
from threading import Thread
import config
import web3_utils

app = Flask(__name__)

# Global event storage
events: List[Dict[str, Any]] = []
settlements: Dict[str, Dict[str, Any]] = {}

# HTML Template with embedded CSS/JS
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>OTC Settlement Tracker</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
            padding: 20px;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        
        .header {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            margin-bottom: 30px;
        }
        
        .header h1 {
            color: #667eea;
            margin-bottom: 10px;
        }
        
        .header .stats {
            display: flex;
            gap: 30px;
            margin-top: 20px;
        }
        
        .stat {
            flex: 1;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 8px;
            text-align: center;
        }
        
        .stat-value {
            font-size: 32px;
            font-weight: bold;
            color: #667eea;
        }
        
        .stat-label {
            font-size: 14px;
            color: #666;
            margin-top: 5px;
        }
        
        .content {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
        }
        
        .panel {
            background: white;
            border-radius: 10px;
            padding: 25px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        
        .panel h2 {
            color: #667eea;
            margin-bottom: 20px;
            font-size: 20px;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        
        .event {
            padding: 15px;
            margin-bottom: 12px;
            border-left: 4px solid #667eea;
            background: #f8f9fa;
            border-radius: 5px;
            animation: slideIn 0.3s ease-out;
        }
        
        @keyframes slideIn {
            from {
                opacity: 0;
                transform: translateX(-20px);
            }
            to {
                opacity: 1;
                transform: translateX(0);
            }
        }
        
        .event-type {
            font-weight: bold;
            color: #667eea;
            margin-bottom: 8px;
            font-size: 14px;
        }
        
        .event-details {
            font-size: 13px;
            color: #666;
            line-height: 1.6;
        }
        
        .event-time {
            font-size: 11px;
            color: #999;
            margin-top: 5px;
        }
        
        .settlement {
            padding: 20px;
            margin-bottom: 15px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            background: white;
            transition: all 0.3s ease;
        }
        
        .settlement:hover {
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            transform: translateY(-2px);
        }
        
        .settlement-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
        }
        
        .settlement-id {
            font-family: monospace;
            font-size: 12px;
            color: #666;
            background: #f0f0f0;
            padding: 4px 8px;
            border-radius: 4px;
        }
        
        .status {
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: bold;
            text-transform: uppercase;
        }
        
        .status-created { background: #ffd93d; color: #000; }
        .status-funds_pulled { background: #6bcf7f; color: white; }
        .status-funded { background: #4d96ff; color: white; }
        .status-settled { background: #667eea; color: white; }
        
        .settlement-info {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
            font-size: 13px;
        }
        
        .info-item {
            padding: 8px;
            background: #f8f9fa;
            border-radius: 4px;
        }
        
        .info-label {
            color: #999;
            font-size: 11px;
            text-transform: uppercase;
        }
        
        .info-value {
            color: #333;
            font-weight: 600;
            margin-top: 3px;
        }
        
        .progress-bar {
            width: 100%;
            height: 6px;
            background: #e0e0e0;
            border-radius: 3px;
            margin-top: 15px;
            overflow: hidden;
        }
        
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #667eea, #764ba2);
            transition: width 0.5s ease;
        }
        
        .empty-state {
            text-align: center;
            padding: 40px;
            color: #999;
        }
        
        .empty-state-icon {
            font-size: 48px;
            margin-bottom: 10px;
        }
        
        @media (max-width: 968px) {
            .content {
                grid-template-columns: 1fr;
            }
            .header .stats {
                flex-direction: column;
                gap: 15px;
            }
        }
        
        .badge {
            display: inline-block;
            padding: 2px 6px;
            background: #667eea;
            color: white;
            border-radius: 10px;
            font-size: 11px;
            margin-left: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔄 OTC Settlement Tracker</h1>
            <p>Real-time monitoring of x402 settlements on Polygon Amoy</p>
            <div class="stats">
                <div class="stat">
                    <div class="stat-value" id="totalSettlements">0</div>
                    <div class="stat-label">Total Settlements</div>
                </div>
                <div class="stat">
                    <div class="stat-value" id="totalEvents">0</div>
                    <div class="stat-label">Total Events</div>
                </div>
                <div class="stat">
                    <div class="stat-value" id="currentBlock">-</div>
                    <div class="stat-label">Current Block</div>
                </div>
            </div>
        </div>
        
        <div class="content">
            <div class="panel">
                <h2>📊 Active Settlements</h2>
                <div id="settlements">
                    <div class="empty-state">
                        <div class="empty-state-icon">📦</div>
                        <p>No settlements yet</p>
                    </div>
                </div>
            </div>
            
            <div class="panel">
                <h2>📝 Recent Events <span class="badge" id="eventCount">0</span></h2>
                <div id="events">
                    <div class="empty-state">
                        <div class="empty-state-icon">🔍</div>
                        <p>Waiting for events...</p>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        function updateData() {
            fetch('/api/data')
                .then(response => response.json())
                .then(data => {
                    // Update stats
                    document.getElementById('totalSettlements').textContent = data.total_settlements;
                    document.getElementById('totalEvents').textContent = data.total_events;
                    document.getElementById('currentBlock').textContent = data.current_block;
                    document.getElementById('eventCount').textContent = data.total_events;
                    
                    // Update settlements
                    const settlementsDiv = document.getElementById('settlements');
                    if (Object.keys(data.settlements).length === 0) {
                        settlementsDiv.innerHTML = '<div class="empty-state"><div class="empty-state-icon">📦</div><p>No settlements yet</p></div>';
                    } else {
                        let html = '';
                        for (const [id, settlement] of Object.entries(data.settlements)) {
                            const progress = getProgress(settlement.status);
                            html += `
                                <div class="settlement">
                                    <div class="settlement-header">
                                        <div class="settlement-id">${id.substring(0, 16)}...</div>
                                        <div class="status status-${settlement.status}">${settlement.status}</div>
                                    </div>
                                    <div class="settlement-info">
                                        <div class="info-item">
                                            <div class="info-label">Client</div>
                                            <div class="info-value">${settlement.client ? settlement.client.substring(0, 10) + '...' : 'N/A'}</div>
                                        </div>
                                        <div class="info-item">
                                            <div class="info-label">Seller</div>
                                            <div class="info-value">${settlement.seller ? settlement.seller.substring(0, 10) + '...' : 'N/A'}</div>
                                        </div>
                                        <div class="info-item">
                                            <div class="info-label">Asset Amount</div>
                                            <div class="info-value">${(settlement.asset_amount / 1e18).toFixed(2)} YPS</div>
                                        </div>
                                        <div class="info-item">
                                            <div class="info-label">Required USDC</div>
                                            <div class="info-value">${(settlement.required_usdc / 1e6).toFixed(2)} USDC</div>
                                        </div>
                                    </div>
                                    <div class="progress-bar">
                                        <div class="progress-fill" style="width: ${progress}%"></div>
                                    </div>
                                </div>
                            `;
                        }
                        settlementsDiv.innerHTML = html;
                    }
                    
                    // Update events
                    const eventsDiv = document.getElementById('events');
                    if (data.events.length === 0) {
                        eventsDiv.innerHTML = '<div class="empty-state"><div class="empty-state-icon">🔍</div><p>Waiting for events...</p></div>';
                    } else {
                        let html = '';
                        for (const event of data.events.slice(-10).reverse()) {
                            html += `
                                <div class="event">
                                    <div class="event-type">${event.type}</div>
                                    <div class="event-details">${event.details}</div>
                                    <div class="event-time">${new Date(event.timestamp * 1000).toLocaleTimeString()}</div>
                                </div>
                            `;
                        }
                        eventsDiv.innerHTML = html;
                    }
                })
                .catch(error => console.error('Error fetching data:', error));
        }
        
        function getProgress(status) {
            const statusMap = {
                'created': 25,
                'funds_pulled': 50,
                'funded': 75,
                'settled': 100
            };
            return statusMap[status] || 0;
        }
        
        // Update every 5 seconds
        updateData();
        setInterval(updateData, 5000);
    </script>
</body>
</html>
"""

@app.route("/")
def index():
    """Serve the main UI"""
    return render_template_string(HTML_TEMPLATE)

@app.route("/api/data")
def get_data():
    """API endpoint for real-time data"""
    return jsonify({
        "total_settlements": len(settlements),
        "total_events": len(events),
        "current_block": web3_utils.get_block_number(),
        "settlements": settlements,
        "events": events[-50:],  # Last 50 events
    })

class EventTracker:
    """Tracks events from the settlement system"""
    
    def __init__(self):
        self.vault = self._load_vault_contract()
        self.running = False
    
    def _load_vault_contract(self):
        """Load SettlementVault contract"""
        abi = web3_utils.load_abi("SettlementVault")
        return web3_utils.get_contract(config.SETTLEMENT_VAULT_ADDRESS, abi)
    
    def start(self):
        """Start tracking events"""
        self.running = True
        print("\n" + "="*60)
        print("EVENT TRACKER STARTED")
        print("="*60)
        print(f"Web UI: http://localhost:5000")
        print(f"Monitoring vault: {config.SETTLEMENT_VAULT_ADDRESS}")
        print("="*60 + "\n")
        
        self._track_events()
    
    def stop(self):
        """Stop tracking"""
        self.running = False
    
    def _track_events(self):
        """Main tracking loop"""
        last_block = web3_utils.get_block_number()
        
        while self.running:
            try:
                current_block = web3_utils.get_block_number()
                
                if current_block > last_block:
                    self._process_blocks(last_block + 1, current_block)
                    last_block = current_block
                
                time.sleep(5)
                
            except KeyboardInterrupt:
                break
            except Exception as e:
                print(f"Error in tracking loop: {e}")
                time.sleep(5)
    
    def _process_blocks(self, from_block: int, to_block: int):
        """Process blocks for events"""
        try:
            # SettlementCreated
            for event in self.vault.events.SettlementCreated.create_filter(
                fromBlock=from_block, toBlock=to_block
            ).get_all_entries():
                self._handle_settlement_created(event)
            
            # FundsPulled
            for event in self.vault.events.FundsPulled.create_filter(
                fromBlock=from_block, toBlock=to_block
            ).get_all_entries():
                self._handle_funds_pulled(event)
            
            # VaultFunded
            for event in self.vault.events.VaultFunded.create_filter(
                fromBlock=from_block, toBlock=to_block
            ).get_all_entries():
                self._handle_vault_funded(event)
            
            # SettlementExecuted
            for event in self.vault.events.SettlementExecuted.create_filter(
                fromBlock=from_block, toBlock=to_block
            ).get_all_entries():
                self._handle_settlement_executed(event)
                
        except Exception as e:
            print(f"Error processing blocks: {e}")
    
    def _handle_settlement_created(self, event):
        """Handle SettlementCreated event"""
        args = event['args']
        settlement_id = args['settlementId'].hex()
        
        settlements[settlement_id] = {
            "client": args['client'],
            "seller": args['seller'],
            "asset_token": args['assetToken'],
            "asset_amount": args['assetAmount'],
            "required_usdc": args['requiredUSDC'],
            "max_eurc": args['maxEURC'],
            "status": "created",
            "block": event['blockNumber'],
        }
        
        events.append({
            "type": "SettlementCreated",
            "details": f"Client {args['client'][:10]}... wants {args['assetAmount'] / 10**18:.2f} YPS",
            "timestamp": time.time(),
            "block": event['blockNumber'],
        })
        
        print(f"[EVENT] SettlementCreated: {settlement_id}")
    
    def _handle_funds_pulled(self, event):
        """Handle FundsPulled event"""
        args = event['args']
        settlement_id = args['settlementId'].hex()
        
        if settlement_id in settlements:
            settlements[settlement_id]['status'] = 'funds_pulled'
        
        events.append({
            "type": "FundsPulled",
            "details": f"{args['eurcAmount'] / 10**6:.2f} EURC and assets pulled",
            "timestamp": time.time(),
            "block": event['blockNumber'],
        })
        
        print(f"[EVENT] FundsPulled: {settlement_id}")
    
    def _handle_vault_funded(self, event):
        """Handle VaultFunded event"""
        args = event['args']
        settlement_id = args['settlementId'].hex()
        
        if settlement_id in settlements:
            settlements[settlement_id]['status'] = 'funded'
            settlements[settlement_id]['funded_block'] = args['blockNumber']
        
        events.append({
            "type": "VaultFunded",
            "details": f"Vault funded with {args['usdcAmount'] / 10**6:.2f} USDC at block {args['blockNumber']}",
            "timestamp": time.time(),
            "block": event['blockNumber'],
        })
        
        print(f"[EVENT] VaultFunded: {settlement_id}")
    
    def _handle_settlement_executed(self, event):
        """Handle SettlementExecuted event"""
        args = event['args']
        settlement_id = args['settlementId'].hex()
        
        if settlement_id in settlements:
            settlements[settlement_id]['status'] = 'settled'
        
        events.append({
            "type": "SettlementExecuted",
            "details": f"Settlement completed! {args['assetAmount'] / 10**18:.2f} YPS → {args['client'][:10]}...",
            "timestamp": time.time(),
            "block": event['blockNumber'],
        })
        
        print(f"[EVENT] SettlementExecuted: {settlement_id}")

def run_tracker():
    """Run the event tracker in a separate thread"""
    tracker = EventTracker()
    tracker.start()

def main():
    """Run the tracker with web UI"""
    # Start event tracker in background thread
    tracker_thread = Thread(target=run_tracker, daemon=True)
    tracker_thread.start()
    
    # Start Flask web UI
    app.run(host="0.0.0.0", port=5000, debug=False)

if __name__ == "__main__":
    main()

