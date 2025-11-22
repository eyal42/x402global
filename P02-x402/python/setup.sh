#!/bin/bash
# Setup script for x402 OTC API demo

set -e

echo "=== x402 OTC API Setup ==="
echo ""

# Check if .env file exists
if [ ! -f ../.env ]; then
    echo "❌ .env file not found in parent directory"
    echo "Please create a .env file with required variables:"
    echo "  - PRIVATE_KEY"
    echo "  - RPC_URL"
    echo "  - MOCK_EURC_ADDRESS_POLYGON"
    echo "  - MOCK_USDC_ADDRESS_POLYGON"
    echo "  - YPS_ADDRESS"
    echo "  - SWAP_SIMULATOR_ADDRESS"
    echo "  - SETTLEMENT_VAULT_ADDRESS"
    exit 1
fi

# Create virtual environment
echo "1. Creating virtual environment..."
python3 -m venv venv

# Activate virtual environment
echo "2. Activating virtual environment..."
source venv/bin/activate

# Install requirements
echo "3. Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo ""
echo "✅ Setup complete!"
echo ""
echo "To activate the virtual environment:"
echo "  source venv/bin/activate"
echo ""
echo "Available commands:"
echo "  python server/server.py          # Start the OTC API server"
echo "  python client/client.py          # Make a purchase"
echo "  python tracker/tracker.py        # Track events in real-time"
echo ""

