const express = require("express");
const router = express.Router();
const Order = require("../models/orders");
const Restaurant = require("../models/restaurantModel");
const authenticateToken = require("../middleware/authMiddleware");
const { sendNotificationToUser, sendNotificationToRestaurant } = require("../services/firebaseService");
const logger = require("../utils/logger");
const User = require("../models/user");

// POST /api/orders - Place a new order
router.post("/", authenticateToken, async (req, res) => {
  try {
    // Check if user is a restaurant owner
    if (req.user.role === 'restaurant') {
      return res.status(403).json({ 
        message: "Restaurant owners cannot place orders. Please use a customer account."
      });
    }

    const { restaurant, restaurantName, items, totalAmount, address } = req.body;
    const customer = req.user.userId;

    // Input Validation
    if (!restaurant) {
      return res.status(400).json({ message: "Restaurant ID is required." });
    }
    if (!restaurantName) {
      return res.status(400).json({ message: "Restaurant name is required." });
    }
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ message: "Order items are required." });
    }
    if (!totalAmount || totalAmount <= 0) {
      return res.status(400).json({ message: "Valid total amount is required." });
    }
    if (!address) {
      return res.status(400).json({ message: "Delivery address is required." });
    }

    // Create a new order
    const order = new Order({
      restaurant,
      restaurantName,
      customer,
      items,
      totalAmount,
      address,
      orderStatus: "Placed",
    });

    await order.save();
    logger.info('New order created:', { orderId: order._id });

    // Send notification to restaurant
    try {
      const notificationData = {
        type: 'ORDER_PLACED',
        orderId: order._id.toString(),
        restaurantId: restaurant,
        restaurantName,
        totalAmount: totalAmount.toString(),
        status: 'Placed',
        timestamp: new Date().toISOString(),
      };

      await sendNotificationToRestaurant(
        restaurant,
        'New Order Received',
        `New order worth ₹${totalAmount} received!`,
        notificationData
      );
    } catch (notificationError) {
      logger.error('Error sending notification to restaurant:', notificationError);
    }

    res.status(201).json({ message: "Order placed successfully.", order });
  } catch (error) {
    logger.error("Error placing order:", error);
    res.status(500).json({ message: "Server error.", error: error.message });
  }
});

// GET /api/orders - Fetch orders for the currently logged-in user
router.get("/", authenticateToken, async (req, res) => {
  try {
    const customerId = req.user.userId; // Get the user ID from the token
    console.log("Fetching orders for customer ID:", customerId); // Debug log

    // Fetch orders for the logged-in user
    const orders = await Order.find({ customer: customerId })
      .populate("restaurant", "name") // Populate restaurant details
      .populate("items.menuItem", "name price") // Populate menu item details
      .populate("customer", "username mobileNumber address") // Populate customer details
      .sort({ createdAt: -1 });

    console.log("Orders fetched:", orders); // Debug log
    res.status(200).json({ orders });
  } catch (error) {
    console.error("Error fetching orders:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ message: "Server error.", error: error.message });
  }
});

// GET /api/orders/restaurant/:restaurantId - Fetch orders for a specific restaurant
router.get("/restaurant/:restaurantId", authenticateToken, async (req, res) => {
  try {
    const { restaurantId } = req.params;
    const { status } = req.query;
    const userId = req.user.userId;

    // Verify restaurant ownership
    const restaurant = await Restaurant.findById(restaurantId).populate("owner");
    if (!restaurant || restaurant.owner._id.toString() !== userId) {
      return res.status(403).json({ message: "Forbidden: You do not own this restaurant." });
    }

    // Build query
    const query = { restaurant: restaurantId };
    if (status) {
      query.orderStatus = status;
    }

    // Add date filter for today's orders
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    query.createdAt = { $gte: today };

    // Fetch orders
    const orders = await Order.find(query)
      .populate("customer", "username mobileNumber address")
      .populate("items.menuItem", "name price")
      .sort({ 
        ...(status === 'Accepted' ? { createdAt: 1 } : { createdAt: -1 })
      });

    logger.info(`Fetched ${orders.length} orders with status: ${status || 'all'}`);
    res.status(200).json(orders);
  } catch (error) {
    logger.error("Error fetching restaurant orders:", error);
    res.status(500).json({ message: "Server error.", error: error.message });
  }
});

// GET /api/orders/all - Fetch all orders (without admin check)
router.get("/all", authenticateToken, async (req, res) => {
  try {
    // Fetch all orders
    const orders = await Order.find()
      .populate("restaurant", "name") // Populate restaurant details
      .populate("items.menuItem", "name price") // Populate menu item details
      .populate("customer", "username phone address") // Populate customer details
      .sort({ createdAt: -1 });

    res.status(200).json({ orders });
  } catch (error) {
    console.error("Error fetching all orders:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ message: "Server error.", error: error.message });
  }
});

// PATCH /api/orders/:orderId/confirm - Accept an order
router.patch('/:orderId/confirm', authenticateToken, async (req, res) => {
  try {
    const order = await Order.findByIdAndUpdate(
      req.params.orderId,
      { orderStatus: 'Accepted' },
      { new: true }
    ).populate('customer', 'username mobileNumber address')
     .populate('items.menuItem', 'name price');

    if (!order) {
      return res.status(404).json({ message: "Order not found." });
    }

    // Send notification to customer
    try {
      const notificationData = {
        type: 'ORDER_ACCEPTED',
        orderId: order._id.toString(),
        restaurantId: order.restaurant.toString(),
        restaurantName: order.restaurantName,
        status: 'Accepted',
        timestamp: new Date().toISOString(),
      };

      await sendNotificationToUser(
        order.customer._id.toString(),
        'Order Accepted',
        `Your order from ${order.restaurantName} has been accepted!`,
        notificationData
      );
    } catch (notificationError) {
      logger.error('Error sending notification to customer:', notificationError);
    }

    res.json(order);
  } catch (error) {
    logger.error("Error confirming order:", error);
    res.status(500).json({ message: "Server error.", error: error.message });
  }
});

// PATCH /api/orders/:orderId/deliver - Mark order as delivered
router.patch('/:orderId/deliver', authenticateToken, async (req, res) => {
  try {
    const order = await Order.findByIdAndUpdate(
      req.params.orderId,
      { orderStatus: 'Delivered' },
      { new: true }
    ).populate('customer', 'username mobileNumber address')
     .populate('items.menuItem', 'name price');

    if (!order) {
      return res.status(404).json({ message: "Order not found." });
    }

    // Send notification to customer
    try {
      const notificationData = {
        type: 'ORDER_DELIVERED',
        orderId: order._id.toString(),
        restaurantId: order.restaurant.toString(),
        restaurantName: order.restaurantName,
        status: 'Delivered',
        timestamp: new Date().toISOString(),
      };

      await sendNotificationToUser(
        order.customer._id.toString(),
        'Order Delivered',
        `Your order from ${order.restaurantName} has been delivered!`,
        notificationData
      );
    } catch (notificationError) {
      logger.error('Error sending notification to customer:', notificationError);
    }

    res.json(order);
  } catch (error) {
    logger.error("Error delivering order:", error);
    res.status(500).json({ message: "Server error.", error: error.message });
  }
});

// PATCH /api/orders/:orderId/cancel - Cancel an order
router.patch('/:orderId/cancel', authenticateToken, async (req, res) => {
  try {
    const { reason } = req.body;
    const order = await Order.findByIdAndUpdate(
      req.params.orderId,
      { 
        orderStatus: 'Cancelled',
        cancelReason: reason || 'No reason provided'
      },
      { new: true }
    ).populate('customer', 'username phone address')
     .populate('items.menuItem', 'name price');

    if (!order) {
      return res.status(404).json({ message: "Order not found." });
    }

    // Send notification to customer
    try {
      const notificationData = {
        type: 'ORDER_CANCELLED',
        orderId: order._id.toString(),
        restaurantId: order.restaurant.toString(),
        restaurantName: order.restaurantName,
        status: 'Cancelled',
        reason: reason || 'No reason provided',
        timestamp: new Date().toISOString(),
      };

      await sendNotificationToUser(
        order.customer._id.toString(),
        'Order Cancelled',
        `Your order from ${order.restaurantName} has been cancelled. Reason: ${reason || 'No reason provided'}`,
        notificationData
      );
    } catch (notificationError) {
      logger.error('Error sending notification to customer:', notificationError);
    }

    res.json(order);
  } catch (error) {
    logger.error("Error cancelling order:", error);
    res.status(500).json({ message: "Server error.", error: error.message });
  }
});

module.exports = router;