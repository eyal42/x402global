# Python Components for OTC API

This directory contains the Python implementation of the x402 OTC API system.

## Components

1. **server.py** - HTTP server (seller-side) exposing assets via x402 protocol
2. **client.py** - HTTP client (buyer-side) for purchasing assets
3. **facilitator.py** - Off-chain facilitator for settlement orchestration
4. **tracker.py** - Real-time event tracker with web UI
5. **web3_utils.py** - Web3 utilities for blockchain interaction
6. **x402_types.py** - x402 protocol types and structures
7. **config.py** - Configuration management

## Setup

### 1. Install Dependencies

```bash
cd python
pip install -r requirements.txt
```

### 2. Configure Environment

Copy the example environment file and fill in your values:

```bash
cp ../env.example ../.env
```

Required environment variables:
- `POLYGON_AMOY_RPC_URL` - Polygon Amoy RPC endpoint
- `MOCK_USDC_ADDRESS_POLYGON` - MockUSDC contract address
- `MOCK_EURC_ADDRESS_POLYGON` - MockEURC contract address
- `YIELD_POOL_SHARE_ADDRESS` - YieldPoolShare contract address
- `SETTLEMENT_VAULT_ADDRESS` - SettlementVault contract address
- `PERMIT_PULLER_ADDRESS` - PermitPuller contract address
- `FACILITATOR_HOOK_ADDRESS` - FacilitatorHook contract address
- `SELLER_PRIVATE_KEY` - Seller's private key
- `BUYER_PRIVATE_KEY` - Buyer's private key
- `PRIVATE_KEY` - Facilitator's private key

## Usage

### Running the Complete System

For a full demo, you need to run 4 components in separate terminals:

#### Terminal 1: Event Tracker (Web UI)

```bash
python tracker.py
```

Then open http://localhost:5000 in your browser to see real-time events.

#### Terminal 2: OTC Server (Seller)

```bash
python server.py
```

This starts the HTTP server on port 8402 exposing the `/buy-asset` endpoint.

#### Terminal 3: Facilitator

```bash
python facilitator.py
```

This monitors settlements and executes swaps and final settlements.

#### Terminal 4: Client (Buyer)

```bash
# Purchase 100 YPS tokens (100 * 10^18)
python client.py 100000000000000000000
```

## Architecture

### x402 Protocol Flow

1. **Client → Server**: `GET /buy-asset?amount=X`
2. **Server → Client**: `HTTP 402` with payment requirements
3. **Client**: Calculates EUR/USD rate and max EURC budget
4. **Client**: Creates EIP-2612 permit signature
5. **Client → Server**: `GET /buy-asset?amount=X` with `X-PAYMENT` header
6. **Server**: Creates settlement on-chain
7. **Facilitator**: Detects settlement and pulls funds via PermitPuller
8. **Facilitator**: Executes MockEURC → MockUSDC swap via Uniswap V4
9. **Facilitator**: Waits for block finality
10. **Facilitator**: Executes final settlement (distributes assets & funds)

### Component Responsibilities

#### Server (seller.py)
- Exposes HTTP 402 API for asset sales
- Calculates prices in MockUSDC
- Creates settlements on-chain
- Returns payment requirements to clients

#### Client (client.py)
- Queries EUR/USD exchange rate
- Calculates max EURC budget
- Creates EIP-2612 permit signatures
- Submits payment proof to server

#### Facilitator (facilitator.py)
- Monitors on-chain events
- Pulls funds from buyer and seller using permits
- Executes swaps via Uniswap V4
- Monitors block finality
- Executes final settlement after finality

#### Tracker (tracker.py)
- Real-time event monitoring
- Web UI dashboard
- Visual progress tracking
- Settlement status display

## API Reference

### Server Endpoints

#### `GET /buy-asset?amount=<asset_amount>`

Purchase assets via OTC.

**Without X-PAYMENT header:**
- Returns: `HTTP 402` with payment requirements

**With X-PAYMENT header:**
- Returns: `HTTP 200` with settlement details

**Query Parameters:**
- `amount` (int, required) - Amount of asset to purchase in smallest unit

**Headers:**
- `X-PAYMENT` (string, optional) - x402 payment proof (base64 encoded JSON)

**Response (402):**
```json
{
  "error": "Payment Required",
  "message": "Payment required to access this resource",
  "payment_requirement": {
    "version": "1.0",
    "chain": "polygon-amoy",
    "chain_id": 80002,
    "settlement_token": "0x...",
    "required_amount": 110000000,
    "settlement_vault": "0x...",
    "payment_deadline": 1234567890,
    "resource": "/buy-asset?amount=100000000000000000000",
    "asset_token": "0x...",
    "asset_amount": 100000000000000000000,
    "seller": "0x..."
  }
}
```

**Response (200):**
```json
{
  "settlement_id": "0x1234...",
  "status": "created",
  "message": "Settlement created successfully",
  "required_usdc": 110000000,
  "max_eurc": 121000000,
  "asset_amount": 100000000000000000000
}
```

#### `GET /settlement/<settlement_id>`

Get settlement status.

**Response:**
```json
{
  "settlement_id": "0x1234...",
  "client": "0x...",
  "asset_amount": 100000000000000000000,
  "required_usdc": 110000000,
  "max_eurc": 121000000,
  "status": "pending"
}
```

#### `GET /health`

Health check endpoint.

## Testing

### Manual Testing Flow

1. Start all components (tracker, server, facilitator)
2. Ensure buyer has MockEURC tokens
3. Ensure seller has YieldPoolShare tokens
4. Run client to initiate purchase
5. Watch events in tracker UI
6. Verify settlement completion

### Example Test Scenario

```bash
# Terminal 1: Start tracker
python tracker.py

# Terminal 2: Start server
python server.py

# Terminal 3: Start facilitator
python facilitator.py

# Terminal 4: Purchase 100 YPS
python client.py 100000000000000000000
```

## Troubleshooting

### Common Issues

**"Settlement failed: insufficient allowance"**
- Ensure seller has approved PermitPuller to spend YieldPoolShares
- Check buyer has sufficient MockEURC balance

**"Swap failed: insufficient output"**
- MockEURC/MockUSDC pool may not have enough liquidity
- Adjust slippage tolerance in client

**"Finality timeout"**
- Increase `FINALITY_CONFIRMATIONS` in config
- Check Polygon Amoy network status

**"Contract not found"**
- Ensure all contract addresses are set in `.env`
- Verify contracts are deployed to Polygon Amoy

## Development

### Adding New Event Types

1. Add event handler in `facilitator.py`
2. Add event display in `tracker.py`
3. Update UI template if needed

### Modifying Pricing

Edit `handle_payment_required()` in `server.py`:

```python
price_per_unit_usdc = 1.10  # Change price here
```

### Adjusting Finality

Edit `.env`:

```
FINALITY_CONFIRMATIONS=10  # Number of block confirmations
```

## License

MIT

