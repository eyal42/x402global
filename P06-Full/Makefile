# Makefile for OTC API Project

.PHONY: help install build test deploy clean server client facilitator tracker

# Default target
help:
	@echo "OTC API Project - Makefile Commands"
	@echo "===================================="
	@echo ""
	@echo "Setup & Build:"
	@echo "  make install     - Install dependencies (Foundry + Python)"
	@echo "  make build       - Build Solidity contracts"
	@echo "  make test        - Run Solidity tests"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy      - Deploy contracts to Polygon Amoy"
	@echo "  make verify      - Verify contracts on Polygonscan"
	@echo "  make mint        - Mint test tokens"
	@echo ""
	@echo "Run Components:"
	@echo "  make tracker     - Start event tracker (port 5000)"
	@echo "  make server      - Start OTC server (port 8402)"
	@echo "  make facilitator - Start facilitator"
	@echo "  make client      - Run client (requires AMOUNT env var)"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean       - Clean build artifacts"
	@echo "  make logs        - Show recent logs"
	@echo ""

# Install dependencies
install:
	@echo "Installing Foundry dependencies..."
	forge install
	@echo "Installing Python dependencies..."
	cd python && pip install -r requirements.txt
	@echo "✓ Installation complete"

# Build contracts
build:
	@echo "Building contracts..."
	forge build
	@echo "✓ Build complete"

# Run tests
test:
	@echo "Running tests..."
	forge test -vvv

# Deploy contracts
deploy:
	@echo "Deploying contracts to Polygon Amoy..."
	@if [ -z "$$POLYGON_AMOY_RPC_URL" ]; then \
		echo "Error: POLYGON_AMOY_RPC_URL not set"; \
		exit 1; \
	fi
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url $$POLYGON_AMOY_RPC_URL \
		--broadcast \
		--verify \
		-vvvv
	@echo "✓ Deployment complete - check deployed_addresses.txt"

# Verify contracts
verify:
	@echo "Verifying contracts on Polygonscan..."
	@echo "Not implemented yet - use forge verify-contract manually"

# Mint test tokens
mint:
	@echo "Minting test tokens..."
	forge script script/Interact.s.sol:Interact \
		--sig "mintTestTokens()" \
		--rpc-url $$POLYGON_AMOY_RPC_URL \
		--broadcast \
		-vvv

# Start event tracker
tracker:
	@echo "Starting event tracker on http://localhost:5000..."
	cd python && python tracker.py

# Start OTC server
server:
	@echo "Starting OTC server on port 8402..."
	cd python && python server.py

# Start facilitator
facilitator:
	@echo "Starting facilitator..."
	cd python && python facilitator.py

# Run client
client:
	@if [ -z "$$AMOUNT" ]; then \
		echo "Error: AMOUNT not set"; \
		echo "Usage: make client AMOUNT=100000000000000000000"; \
		exit 1; \
	fi
	@echo "Running client to purchase $$AMOUNT assets..."
	cd python && python client.py $$AMOUNT

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	forge clean
	rm -rf out cache
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -delete
	@echo "✓ Clean complete"

# Show logs
logs:
	@echo "Recent logs:"
	@echo "Not implemented - check terminal outputs"

# Quick start (for demo)
demo: build
	@echo "Starting demo environment..."
	@echo "Open 4 terminals and run:"
	@echo "  Terminal 1: make tracker"
	@echo "  Terminal 2: make server"
	@echo "  Terminal 3: make facilitator"
	@echo "  Terminal 4: make client AMOUNT=100000000000000000000"

