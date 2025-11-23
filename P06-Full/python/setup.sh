#!/bin/bash
# Setup script for Python OTC client

echo "Setting up Python environment for OTC API..."

# Build contracts to generate ABIs
echo "Building contracts..."
cd ..
forge build
cd python

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install -q -r requirements.txt

echo ""
echo "✓ Setup complete!"
echo ""
echo "To activate the environment:"
echo "  source venv/bin/activate"
echo ""
echo "To run the client:"
echo "  python client.py 100000000000000000000"
echo ""

