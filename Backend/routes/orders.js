const express = require("express");
const router = express.Router();
const Order = require("../models/orders");
const Restaurant = require("../models/restaurantModel");
const authenticateToken = require("../middleware/authMiddleware");
const { notifyRestaurant } = require('../app');

// POST /api/orders - Place a new order
// Update the POST route
router.post("/", authenticateToken, async (req, res) => {
  try {
    const { restaurant, restaurantName, items, totalAmount, address } = req.body;
    const customer = req.user.userId;

    // Input Validation
    if (!restaurant || !items || !totalAmount || !address) {
      return res.status(400).json({ message: "Missing required fields" });
    }

    // Create order
    const order = new Order({
      restaurant,
      restaurantName,
      customer,
      items,
      totalAmount,
      address,
      orderStatus: "Placed"
    });

    await order.save();

    // Notify restaurant about new order
    const { notifyRestaurant } = require('../server');
    notifyRestaurant(restaurant, order);

    res.status(201).json({
      message: 'Order placed successfully',
      order: order
    });
  } catch (error) {
    console.error("Error placing order:", error);
    res.status(500).json({ message: "Server error", error: error.message });
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
      .populate("customer", "username phone address") // Populate customer details
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
    const userId = req.user.userId;

    // Verify that the user is the owner of the restaurant
    const restaurant = await Restaurant.findById(restaurantId).populate("owner");
    if (!restaurant || restaurant.owner._id.toString() !== userId) {
      return res.status(403).json({ message: "Forbidden: You do not own this restaurant." });
    }

    // Fetch orders for the restaurant
    const orders = await Order.find({ restaurant: restaurantId })
      .populate("customer", "username phone address") // Populate customer details
      .populate("items.menuItem", "name price") // Populate menu item details
      .sort({ createdAt: -1 });

    res.status(200).json({ orders });
  } catch (error) {
    console.error("Error fetching restaurant orders:", {
      error: error.message,
      stack: error.stack,
    });
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
    );

    if (!order) {
      return res.status(404).json({ message: "Order not found." });
    }

    res.json(order);
  } catch (error) {
    console.error("Error confirming order:", error);
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
    );

    if (!order) {
      return res.status(404).json({ message: "Order not found." });
    }

    res.json(order);
  } catch (error) {
    console.error("Error delivering order:", error);
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
        cancellationReason: reason 
      },
      { new: true }
    );

    if (!order) {
      return res.status(404).json({ message: "Order not found." });
    }

    res.json(order);
  } catch (error) {
    console.error("Error cancelling order:", error);
    res.status(500).json({ message: "Server error.", error: error.message });
  }
});

module.exports = router;