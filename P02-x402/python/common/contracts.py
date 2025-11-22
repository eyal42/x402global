"""Contract ABIs and helper functions"""
import json
from web3 import Web3
from web3.contract import Contract

# Minimal ABIs for our contracts

ERC20_PERMIT_ABI = [
    {
        "inputs": [
            {"internalType": "address", "name": "owner", "type": "address"},
            {"internalType": "address", "name": "spender", "type": "address"}
        ],
        "name": "allowance",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "address", "name": "account", "type": "address"}
        ],
        "name": "balanceOf",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "decimals",
        "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "name",
        "outputs": [{"internalType": "string", "name": "", "type": "string"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "address", "name": "owner", "type": "address"}
        ],
        "name": "nonces",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "address", "name": "owner", "type": "address"},
            {"internalType": "address", "name": "spender", "type": "address"},
            {"internalType": "uint256", "name": "value", "type": "uint256"},
            {"internalType": "uint256", "name": "deadline", "type": "uint256"},
            {"internalType": "uint8", "name": "v", "type": "uint8"},
            {"internalType": "bytes32", "name": "r", "type": "bytes32"},
            {"internalType": "bytes32", "name": "s", "type": "bytes32"}
        ],
        "name": "permit",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "address", "name": "to", "type": "address"},
            {"internalType": "uint256", "name": "amount", "type": "uint256"}
        ],
        "name": "transfer",
        "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
        "stateMutability": "nonpayable",
        "type": "function"
    }
]

SETTLEMENT_VAULT_ABI = [
    {
        "inputs": [
            {"internalType": "bytes32", "name": "orderId", "type": "bytes32"},
            {"internalType": "address", "name": "client", "type": "address"},
            {"internalType": "address", "name": "seller", "type": "address"},
            {"internalType": "address", "name": "assetToken", "type": "address"},
            {"internalType": "uint256", "name": "assetAmount", "type": "uint256"},
            {"internalType": "address", "name": "settlementToken", "type": "address"},
            {"internalType": "uint256", "name": "settlementAmount", "type": "uint256"},
            {"internalType": "uint256", "name": "deadline", "type": "uint256"}
        ],
        "name": "createPaymentRequest",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "bytes32", "name": "orderId", "type": "bytes32"},
            {"internalType": "address", "name": "paymentToken", "type": "address"},
            {"internalType": "uint256", "name": "amount", "type": "uint256"},
            {"internalType": "uint256", "name": "deadline", "type": "uint256"},
            {"internalType": "uint8", "name": "v", "type": "uint8"},
            {"internalType": "bytes32", "name": "r", "type": "bytes32"},
            {"internalType": "bytes32", "name": "s", "type": "bytes32"}
        ],
        "name": "pullPaymentWithPermit",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "bytes32", "name": "orderId", "type": "bytes32"},
            {"internalType": "uint256", "name": "amountOut", "type": "uint256"}
        ],
        "name": "completeSwapAndSettle",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "bytes32", "name": "orderId", "type": "bytes32"}
        ],
        "name": "releaseAsset",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "bytes32", "name": "orderId", "type": "bytes32"}
        ],
        "name": "getOrder",
        "outputs": [{
            "components": [
                {"internalType": "address", "name": "client", "type": "address"},
                {"internalType": "address", "name": "seller", "type": "address"},
                {"internalType": "address", "name": "assetToken", "type": "address"},
                {"internalType": "uint256", "name": "assetAmount", "type": "uint256"},
                {"internalType": "address", "name": "settlementToken", "type": "address"},
                {"internalType": "uint256", "name": "settlementAmount", "type": "uint256"},
                {"internalType": "address", "name": "paymentToken", "type": "address"},
                {"internalType": "uint256", "name": "maxPayment", "type": "uint256"},
                {"internalType": "uint256", "name": "deadline", "type": "uint256"},
                {"internalType": "uint8", "name": "status", "type": "uint8"},
                {"internalType": "uint256", "name": "actualPayment", "type": "uint256"},
                {"internalType": "uint256", "name": "refundAmount", "type": "uint256"}
            ],
            "internalType": "struct SettlementVault.Order",
            "name": "",
            "type": "tuple"
        }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": True, "internalType": "bytes32", "name": "orderId", "type": "bytes32"},
            {"indexed": True, "internalType": "address", "name": "client", "type": "address"},
            {"indexed": False, "internalType": "address", "name": "paymentToken", "type": "address"},
            {"indexed": False, "internalType": "uint256", "name": "requiredAmount", "type": "uint256"},
            {"indexed": False, "internalType": "uint256", "name": "deadline", "type": "uint256"}
        ],
        "name": "PaymentRequested",
        "type": "event"
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": True, "internalType": "bytes32", "name": "orderId", "type": "bytes32"},
            {"indexed": True, "internalType": "address", "name": "client", "type": "address"},
            {"indexed": False, "internalType": "address", "name": "token", "type": "address"},
            {"indexed": False, "internalType": "uint256", "name": "amount", "type": "uint256"}
        ],
        "name": "PermitConsumed",
        "type": "event"
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": True, "internalType": "bytes32", "name": "orderId", "type": "bytes32"},
            {"indexed": True, "internalType": "address", "name": "client", "type": "address"},
            {"indexed": False, "internalType": "address", "name": "token", "type": "address"},
            {"indexed": False, "internalType": "uint256", "name": "amount", "type": "uint256"}
        ],
        "name": "FundsPulled",
        "type": "event"
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": True, "internalType": "bytes32", "name": "orderId", "type": "bytes32"},
            {"indexed": False, "internalType": "uint256", "name": "amountIn", "type": "uint256"},
            {"indexed": False, "internalType": "uint256", "name": "amountOut", "type": "uint256"},
            {"indexed": False, "internalType": "uint256", "name": "surplus", "type": "uint256"}
        ],
        "name": "SwapCompleted",
        "type": "event"
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": True, "internalType": "bytes32", "name": "orderId", "type": "bytes32"},
            {"indexed": False, "internalType": "address", "name": "token", "type": "address"},
            {"indexed": False, "internalType": "uint256", "name": "amount", "type": "uint256"}
        ],
        "name": "VaultFunded",
        "type": "event"
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": True, "internalType": "bytes32", "name": "orderId", "type": "bytes32"},
            {"indexed": True, "internalType": "address", "name": "client", "type": "address"},
            {"indexed": False, "internalType": "address", "name": "asset", "type": "address"},
            {"indexed": False, "internalType": "uint256", "name": "amount", "type": "uint256"}
        ],
        "name": "AssetReleased",
        "type": "event"
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": True, "internalType": "bytes32", "name": "orderId", "type": "bytes32"},
            {"indexed": True, "internalType": "address", "name": "client", "type": "address"},
            {"indexed": False, "internalType": "address", "name": "token", "type": "address"},
            {"indexed": False, "internalType": "uint256", "name": "amount", "type": "uint256"}
        ],
        "name": "RefundSent",
        "type": "event"
    }
]

SWAP_SIMULATOR_ABI = [
    {
        "inputs": [
            {"internalType": "bytes32", "name": "swapId", "type": "bytes32"},
            {"internalType": "address", "name": "tokenIn", "type": "address"},
            {"internalType": "address", "name": "tokenOut", "type": "address"},
            {"internalType": "uint256", "name": "amountIn", "type": "uint256"}
        ],
        "name": "instantSwap",
        "outputs": [{"internalType": "uint256", "name": "amountOut", "type": "uint256"}],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "address", "name": "tokenIn", "type": "address"},
            {"internalType": "address", "name": "tokenOut", "type": "address"},
            {"internalType": "uint256", "name": "amountIn", "type": "uint256"}
        ],
        "name": "calculateOutput",
        "outputs": [{"internalType": "uint256", "name": "amountOut", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "bytes32", "name": "swapId", "type": "bytes32"}
        ],
        "name": "getSwap",
        "outputs": [{
            "components": [
                {"internalType": "address", "name": "initiator", "type": "address"},
                {"internalType": "address", "name": "tokenIn", "type": "address"},
                {"internalType": "address", "name": "tokenOut", "type": "address"},
                {"internalType": "uint256", "name": "amountIn", "type": "uint256"},
                {"internalType": "uint256", "name": "amountOut", "type": "uint256"},
                {"internalType": "bool", "name": "fulfilled", "type": "bool"},
                {"internalType": "uint256", "name": "timestamp", "type": "uint256"}
            ],
            "internalType": "struct SwapSimulator.Swap",
            "name": "",
            "type": "tuple"
        }],
        "stateMutability": "view",
        "type": "function"
    }
]


def get_contract(w3: Web3, address: str, abi: list) -> Contract:
    """Get a contract instance"""
    return w3.eth.contract(address=Web3.to_checksum_address(address), abi=abi)

