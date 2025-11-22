// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SettlementVault
 * @notice Vault contract for handling x402 payments with EIP-2612 permit and asset settlement
 * @dev Coordinates the flow: permit → pull EURC → simulate swap → settle → release assets
 */
contract SettlementVault is Ownable, ReentrancyGuard {
    
    // ============ Events ============
    
    /// @notice Emitted when a payment is requested (x402 flow initiated)
    event PaymentRequested(
        bytes32 indexed orderId,
        address indexed client,
        address paymentToken,
        uint256 requiredAmount,
        uint256 deadline
    );
    
    /// @notice Emitted when a permit signature is consumed
    event PermitConsumed(
        bytes32 indexed orderId,
        address indexed client,
        address token,
        uint256 amount
    );
    
    /// @notice Emitted when funds are pulled from client using permit+transferFrom
    event FundsPulled(
        bytes32 indexed orderId,
        address indexed client,
        address token,
        uint256 amount
    );
    
    /// @notice Emitted when swap is requested to simulator
    event SwapRequested(
        bytes32 indexed orderId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    );
    
    /// @notice Emitted when swap simulation completes
    event SwapCompleted(
        bytes32 indexed orderId,
        uint256 amountIn,
        uint256 amountOut,
        uint256 surplus
    );
    
    /// @notice Emitted when vault is funded with required settlement tokens
    event VaultFunded(
        bytes32 indexed orderId,
        address token,
        uint256 amount
    );
    
    /// @notice Emitted when assets are released to client
    event AssetReleased(
        bytes32 indexed orderId,
        address indexed client,
        address asset,
        uint256 amount
    );
    
    /// @notice Emitted when surplus payment is refunded
    event RefundSent(
        bytes32 indexed orderId,
        address indexed client,
        address token,
        uint256 amount
    );
    
    /// @notice Emitted when seller withdraws settlement tokens
    event SellerWithdrawal(
        address indexed seller,
        address token,
        uint256 amount
    );
    
    // ============ Structs ============
    
    struct Order {
        address client;
        address seller;
        address assetToken;
        uint256 assetAmount;
        address settlementToken; // MockUSDC
        uint256 settlementAmount;
        address paymentToken; // MockEURC
        uint256 maxPayment;
        uint256 deadline;
        OrderStatus status;
        uint256 actualPayment;
        uint256 refundAmount;
    }
    
    enum OrderStatus {
        None,
        Requested,
        FundsPulled,
        SwapCompleted,
        Settled,
        AssetReleased,
        Cancelled
    }
    
    // ============ State Variables ============
    
    /// @notice Mapping of order IDs to Order structs
    mapping(bytes32 => Order) public orders;
    
    /// @notice Address of the swap simulator contract
    address public swapSimulator;
    
    /// @notice Seller's balance of settlement tokens
    mapping(address => uint256) public sellerBalances;
    
    // ============ Constructor ============
    
    /**
     * @notice Initialize the SettlementVault
     * @param initialOwner Owner address (typically the server/facilitator)
     */
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    // ============ Configuration ============
    
    /**
     * @notice Set the swap simulator address
     * @param _swapSimulator Address of SwapSimulator contract
     */
    function setSwapSimulator(address _swapSimulator) external onlyOwner {
        require(_swapSimulator != address(0), "Invalid simulator address");
        swapSimulator = _swapSimulator;
    }
    
    // ============ Core Functions ============
    
    /**
     * @notice Create a new payment request (HTTP 402 response)
     * @param orderId Unique order identifier
     * @param client Client address
     * @param seller Seller address
     * @param assetToken Token being sold
     * @param assetAmount Amount of asset to sell
     * @param settlementToken Token for settlement (MockUSDC)
     * @param settlementAmount Required settlement amount
     * @param deadline Payment deadline
     */
    function createPaymentRequest(
        bytes32 orderId,
        address client,
        address seller,
        address assetToken,
        uint256 assetAmount,
        address settlementToken,
        uint256 settlementAmount,
        uint256 deadline
    ) external onlyOwner {
        require(orders[orderId].status == OrderStatus.None, "Order already exists");
        require(client != address(0), "Invalid client");
        require(seller != address(0), "Invalid seller");
        require(assetAmount > 0, "Invalid asset amount");
        require(settlementAmount > 0, "Invalid settlement amount");
        require(deadline > block.timestamp, "Invalid deadline");
        
        orders[orderId] = Order({
            client: client,
            seller: seller,
            assetToken: assetToken,
            assetAmount: assetAmount,
            settlementToken: settlementToken,
            settlementAmount: settlementAmount,
            paymentToken: address(0), // Set when funds pulled
            maxPayment: 0,
            deadline: deadline,
            status: OrderStatus.Requested,
            actualPayment: 0,
            refundAmount: 0
        });
        
        emit PaymentRequested(orderId, client, settlementToken, settlementAmount, deadline);
    }
    
    /**
     * @notice Pull payment using EIP-2612 permit + transferFrom
     * @param orderId Order identifier
     * @param paymentToken Token being paid (MockEURC)
     * @param amount Amount to pull
     * @param deadline Permit deadline
     * @param v Signature v
     * @param r Signature r
     * @param s Signature s
     */
    function pullPaymentWithPermit(
        bytes32 orderId,
        address paymentToken,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant onlyOwner {
        Order storage order = orders[orderId];
        require(order.status == OrderStatus.Requested, "Invalid order status");
        require(block.timestamp <= order.deadline, "Order expired");
        
        // Consume the permit signature
        IERC20Permit(paymentToken).permit(
            order.client,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );
        emit PermitConsumed(orderId, order.client, paymentToken, amount);
        
        // Pull funds from client
        require(
            IERC20(paymentToken).transferFrom(order.client, address(this), amount),
            "Transfer failed"
        );
        
        order.paymentToken = paymentToken;
        order.maxPayment = amount;
        order.actualPayment = amount;
        order.status = OrderStatus.FundsPulled;
        
        emit FundsPulled(orderId, order.client, paymentToken, amount);
    }
    
    /**
     * @notice Complete swap simulation and settle order
     * @param orderId Order identifier
     * @param amountOut Amount of settlement tokens received from swap
     */
    function completeSwapAndSettle(
        bytes32 orderId,
        uint256 amountOut
    ) external nonReentrant onlyOwner {
        Order storage order = orders[orderId];
        require(order.status == OrderStatus.FundsPulled, "Invalid order status");
        
        // Mark swap as completed
        order.status = OrderStatus.SwapCompleted;
        
        uint256 surplus = 0;
        if (amountOut > order.settlementAmount) {
            surplus = amountOut - order.settlementAmount;
        }
        
        emit SwapCompleted(orderId, order.actualPayment, amountOut, surplus);
        
        // Check if we have enough settlement tokens
        require(amountOut >= order.settlementAmount, "Insufficient swap output");
        
        // Vault is now funded with settlement tokens
        order.status = OrderStatus.Settled;
        emit VaultFunded(orderId, order.settlementToken, order.settlementAmount);
        
        // Credit seller's balance
        sellerBalances[order.seller] += order.settlementAmount;
        
        // Handle refund if there's surplus
        if (surplus > 0) {
            // Calculate proportional refund in payment token
            uint256 refund = (surplus * order.actualPayment) / amountOut;
            order.refundAmount = refund;
        }
    }
    
    /**
     * @notice Release asset to client (final step)
     * @param orderId Order identifier
     */
    function releaseAsset(bytes32 orderId) external nonReentrant onlyOwner {
        Order storage order = orders[orderId];
        require(order.status == OrderStatus.Settled, "Invalid order status");
        
        // Transfer asset tokens from vault to client
        require(
            IERC20(order.assetToken).transfer(order.client, order.assetAmount),
            "Asset transfer failed"
        );
        
        order.status = OrderStatus.AssetReleased;
        emit AssetReleased(orderId, order.client, order.assetToken, order.assetAmount);
            
        // Send refund if applicable
        if (order.refundAmount > 0) {
            require(
                IERC20(order.paymentToken).transfer(order.client, order.refundAmount),
                "Refund failed"
            );
            emit RefundSent(orderId, order.client, order.paymentToken, order.refundAmount);
        }
    }
    
    /**
     * @notice Seller withdraws their settlement token balance
     * @param token Settlement token address
     * @param amount Amount to withdraw
     */
    function sellerWithdraw(address token, uint256 amount) external nonReentrant {
        require(sellerBalances[msg.sender] >= amount, "Insufficient balance");
        
        sellerBalances[msg.sender] -= amount;
        require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");
        
        emit SellerWithdrawal(msg.sender, token, amount);
    }
    
    /**
     * @notice Cancel an order (only before funds pulled)
     * @param orderId Order identifier
     */
    function cancelOrder(bytes32 orderId) external onlyOwner {
        Order storage order = orders[orderId];
        require(
            order.status == OrderStatus.Requested,
            "Can only cancel requested orders"
        );
        
        order.status = OrderStatus.Cancelled;
    }
    
    /**
     * @notice Get order details
     * @param orderId Order identifier
     */
    function getOrder(bytes32 orderId) external view returns (Order memory) {
        return orders[orderId];
    }
    
    /**
     * @notice Emergency withdraw (owner only)
     * @param token Token to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(IERC20(token).transfer(owner(), amount), "Transfer failed");
    }
}
