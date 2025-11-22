#!/bin/bash
# Demo script that runs all components

set -e

echo "=== x402 OTC API Demo ==="
echo ""

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Virtual environment not found. Running setup..."
    bash setup.sh
fi

# Activate virtual environment
source venv/bin/activate

echo "This demo will:"
echo "  1. Start the event tracker in the background"
echo "  2. Start the server"
echo "  3. (You can then run the client in another terminal)"
echo ""
read -p "Press Enter to continue..."

# Start event tracker in background
echo ""
echo "Starting event tracker..."
python tracker/tracker.py --mode watch &
TRACKER_PID=$!

# Give tracker time to start
sleep 2

# Start server
echo ""
echo "Starting server..."
python server/server.py

# Cleanup on exit
trap "kill $TRACKER_PID 2>/dev/null" EXIT

