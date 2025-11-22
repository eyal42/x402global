// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SwapSimulator
 * @notice Simulates EURC→USDC conversion without implementing a real liquidity pool
 * @dev Acts as a mock DEX that uses an oracle price for conversion
 */
contract SwapSimulator is Ownable {
    // ============ Events ============

    /// @notice Emitted when a swap is initiated
    event SwapInitiated(
        bytes32 indexed swapId,
        address indexed initiator,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 expectedOut
    );

    /// @notice Emitted when a swap is fulfilled
    event SwapFulfilled(
        bytes32 indexed swapId,
        uint256 amountIn,
        uint256 amountOut
    );

    /// @notice Emitted when exchange rate is updated
    event ExchangeRateUpdated(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 rate,
        uint256 decimals
    );

    // ============ Structs ============

    struct Swap {
        address initiator;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        bool fulfilled;
        uint256 timestamp;
    }

    struct ExchangeRate {
        uint256 rate; // Rate scaled by rateDecimals (e.g., 1.05e18 means 1 EUR = 1.05 USD)
        uint256 rateDecimals; // Decimals for the rate (typically 18)
        uint256 lastUpdate;
    }

    // ============ State Variables ============

    /// @notice Mapping of swap IDs to Swap structs
    mapping(bytes32 => Swap) public swaps;

    /// @notice Exchange rates: tokenIn => tokenOut => ExchangeRate
    mapping(address => mapping(address => ExchangeRate)) public exchangeRates;

    /// @notice Simulated fulfillment delay in seconds (for realism)
    uint256 public fulfillmentDelay;

    // ============ Constructor ============

    /**
     * @notice Initialize the SwapSimulator
     * @param initialOwner Owner address
     */
    constructor(address initialOwner) Ownable(initialOwner) {
        fulfillmentDelay = 0; // Instant by default, can be set to simulate delays
    }

    // ============ Configuration ============

    /**
     * @notice Set exchange rate between two tokens
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param rate Exchange rate (scaled by rateDecimals)
     * @param rateDecimals Decimals for the rate (e.g., 18)
     */
    function setExchangeRate(
        address tokenIn,
        address tokenOut,
        uint256 rate,
        uint256 rateDecimals
    ) external onlyOwner {
        require(tokenIn != address(0), "Invalid tokenIn");
        require(tokenOut != address(0), "Invalid tokenOut");
        require(rate > 0, "Invalid rate");

        exchangeRates[tokenIn][tokenOut] = ExchangeRate({
            rate: rate,
            rateDecimals: rateDecimals,
            lastUpdate: block.timestamp
        });

        emit ExchangeRateUpdated(tokenIn, tokenOut, rate, rateDecimals);
    }

    /**
     * @notice Set fulfillment delay
     * @param delay Delay in seconds
     */
    function setFulfillmentDelay(uint256 delay) external onlyOwner {
        fulfillmentDelay = delay;
    }

    // ============ Core Functions ============

    /**
     * @notice Initiate a simulated swap
     * @param swapId Unique swap identifier
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Amount of input tokens
     * @return expectedOut Expected output amount
     */
    function initiateSwap(
        bytes32 swapId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external returns (uint256 expectedOut) {
        require(swaps[swapId].initiator == address(0), "Swap already exists");
        require(amountIn > 0, "Invalid amount");

        // Get exchange rate
        ExchangeRate memory rate = exchangeRates[tokenIn][tokenOut];
        require(rate.rate > 0, "Exchange rate not set");

        // Calculate expected output
        // Formula: amountOut = amountIn * rate / (10^rateDecimals)
        expectedOut = (amountIn * rate.rate) / (10 ** rate.rateDecimals);

        // Create swap record
        swaps[swapId] = Swap({
            initiator: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOut: expectedOut,
            fulfilled: false,
            timestamp: block.timestamp
        });

        emit SwapInitiated(
            swapId,
            msg.sender,
            tokenIn,
            tokenOut,
            amountIn,
            expectedOut
        );

        return expectedOut;
    }

    /**
     * @notice Fulfill a simulated swap (can be called by owner or after delay)
     * @param swapId Swap identifier
     */
    function fulfillSwap(bytes32 swapId) external {
        Swap storage swap = swaps[swapId];
        require(swap.initiator != address(0), "Swap does not exist");
        require(!swap.fulfilled, "Swap already fulfilled");
        require(
            msg.sender == owner() ||
                block.timestamp >= swap.timestamp + fulfillmentDelay,
            "Fulfillment delay not met"
        );

        swap.fulfilled = true;

        emit SwapFulfilled(swapId, swap.amountIn, swap.amountOut);
    }

    /**
     * @notice Simulate instant swap (for testing)
     * @param swapId Unique swap identifier
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Amount of input tokens
     * @return amountOut Output amount
     */
    function instantSwap(
        bytes32 swapId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        require(swaps[swapId].initiator == address(0), "Swap already exists");
        require(amountIn > 0, "Invalid amount");

        // Get exchange rate
        ExchangeRate memory rate = exchangeRates[tokenIn][tokenOut];
        require(rate.rate > 0, "Exchange rate not set");

        // Calculate output
        amountOut = (amountIn * rate.rate) / (10 ** rate.rateDecimals);

        // Create and immediately fulfill swap
        swaps[swapId] = Swap({
            initiator: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOut: amountOut,
            fulfilled: true,
            timestamp: block.timestamp
        });

        emit SwapInitiated(
            swapId,
            msg.sender,
            tokenIn,
            tokenOut,
            amountIn,
            amountOut
        );
        emit SwapFulfilled(swapId, amountIn, amountOut);

        return amountOut;
    }

    /**
     * @notice Get swap details
     * @param swapId Swap identifier
     */
    function getSwap(bytes32 swapId) external view returns (Swap memory) {
        return swaps[swapId];
    }

    /**
     * @notice Get current exchange rate between tokens
     * @param tokenIn Input token
     * @param tokenOut Output token
     */
    function getExchangeRate(
        address tokenIn,
        address tokenOut
    )
        external
        view
        returns (uint256 rate, uint256 rateDecimals, uint256 lastUpdate)
    {
        ExchangeRate memory er = exchangeRates[tokenIn][tokenOut];
        return (er.rate, er.rateDecimals, er.lastUpdate);
    }

    /**
     * @notice Calculate output amount for a given input
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     */
    function calculateOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        ExchangeRate memory rate = exchangeRates[tokenIn][tokenOut];
        require(rate.rate > 0, "Exchange rate not set");

        amountOut = (amountIn * rate.rate) / (10 ** rate.rateDecimals);
        return amountOut;
    }
}
