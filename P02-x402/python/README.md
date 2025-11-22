# Python Components - x402 OTC API

This directory contains all Python components for the x402 OTC API system.

---

## Directory Structure

```
python/
├── common/               # Shared utilities
│   ├── __init__.py
│   ├── config.py        # Configuration management
│   └── contracts.py     # Contract ABIs and helpers
│
├── server/              # HTTP server
│   └── server.py        # Flask app with /buy-asset endpoint
│
├── client/              # HTTP client
│   └── client.py        # x402 client with EIP-2612 signing
│
├── tracker/             # Event monitoring
│   └── tracker.py       # Real-time event tracker
│
├── requirements.txt     # Python dependencies
├── setup.sh            # Setup script
├── run_demo.sh         # Demo runner
└── utils.py            # Utility functions
```

---

## Quick Start

### Setup
```bash
bash setup.sh
source venv/bin/activate
```

### Run Components

#### Server
```bash
python server/server.py
```

#### Client
```bash
python client/client.py --amount 1.0
```

#### Event Tracker
```bash
python tracker/tracker.py --mode watch
```

---

## Configuration

All configuration is managed through environment variables (from `.env` in parent directory):

- `RPC_URL` - Polygon Amoy RPC endpoint
- `CHAIN_ID` - Network chain ID (80002)
- `PRIVATE_KEY` - Server/deployer private key
- `CLIENT_PRIVATE_KEY` - Client private key
- Contract addresses (YPS, Vault, Simulator, MockEURC, MockUSDC)

See `common/config.py` for all configuration options.

---

## Dependencies

- `web3==6.15.1` - Ethereum interaction
- `flask==3.0.0` - HTTP server
- `requests==2.31.0` - HTTP client
- `eth-account==0.11.0` - Account management and signing
- `python-dotenv==1.0.0` - Environment variables
- `pydantic==2.5.0` - Data validation

Install with:
```bash
pip install -r requirements.txt
```

---

## Usage Examples

### Check Balances
```bash
python utils.py balances --address 0xYourAddress
```

### Check Vault Balances
```bash
python utils.py vault-balances
```

### Buy Assets with Custom Server
```bash
python client/client.py --server http://custom:5000 --amount 5.0
```

### Track Historical Events
```bash
python tracker/tracker.py --mode historical --from-block 12345678
```

---

## API Reference

### Server Endpoints

#### GET /buy-asset
Purchase on-chain assets using x402 flow.

**Parameters:**
- `client` (required) - Client address
- `amount` (required) - Amount of assets to buy

**Headers (second request):**
- `X-PAYMENT` - JSON with order_id and permit_signature

**Responses:**
- `402 Payment Required` - First request, returns payment requirements
- `200 OK` - Payment processed successfully
- `400 Bad Request` - Invalid parameters
- `500 Internal Server Error` - Server error

#### GET /status/<order_id>
Get order status.

**Response:**
```json
{
  "order_id": "...",
  "client": "0x...",
  "status": "completed",
  "tx_hash": "0x..."
}
```

#### GET /health
Health check.

**Response:**
```json
{
  "status": "healthy",
  "server": "0x...",
  "chain_id": 80002
}
```

---

## Development

### Adding New Endpoints

Edit `server/server.py`:

```python
@app.route('/your-endpoint', methods=['GET'])
def your_endpoint():
    # Your logic here
    return jsonify({"result": "success"}), 200
```

### Custom Event Handlers

Edit `tracker/tracker.py`:

```python
def format_event(self, event_name: str, data: dict) -> str:
    if event_name == "YourEvent":
        # Custom formatting
        return f"Your event: {data}"
    # ...
```

---

## Troubleshooting

### "Configuration error"
Make sure `.env` file exists in parent directory with all required values.

### "Connection refused"
- Check server is running
- Verify port (default: 5000)
- Check firewall settings

### "Insufficient balance"
Mint tokens using P01 project:
```bash
cd ../../P01-Mock_Tokens
forge script script/MintTokens.s.sol --rpc-url $RPC_URL --broadcast
```

### "Transaction reverted"
- Check contract addresses in `.env`
- Verify vault has YPS tokens
- Check gas price and limits
- Review server logs for details

---

## Testing

The Python components can be tested manually using the demo flow or by running individual scripts.

For automated testing, consider using:
- `pytest` for unit tests
- `unittest` for integration tests
- Mock Web3 providers for offline testing

---

## Security Notes

⚠️ **Important:**
- Never commit private keys
- Use environment variables for sensitive data
- This is a demo - audit before production use
- Implement rate limiting for production
- Add input validation and sanitization
- Use HTTPS in production

---

## Performance

### Server
- Flask development server (not for production)
- Consider using Gunicorn or uWSGI for production
- Add caching for repeated queries
- Implement connection pooling

### Client
- Synchronous requests (blocking)
- Consider async/await for multiple orders
- Add retry logic with exponential backoff

### Tracker
- Poll-based (2-second interval)
- Consider WebSocket for real-time
- Add batch event processing

---

## License

MIT License - See parent directory LICENSE file

---

For more information, see the main [README](../README.md).

