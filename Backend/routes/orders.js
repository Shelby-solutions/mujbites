const express = require("express");
const router = express.Router();
const Order = require("../models/orders");
const Restaurant = require("../models/restaurantModel");
const authenticateToken = require("../middleware/authMiddleware");

// POST /api/orders - Place a new order
router.post("/", authenticateToken, async (req, res) => {
  try {
    const { restaurant, restaurantName, items, totalAmount, address } = req.body;
    const customer = req.user.userId; // Get the user ID from the token

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

    // Validate each item in the order
    const validatedItems = items.map((item) => {
      if (!item.menuItem || !item.itemName || !item.quantity) {
        throw new Error("Each item must include menuItem, itemName, and quantity.");
      }
      return {
        menuItem: item.menuItem,
        itemName: item.itemName, // Include itemName
        quantity: item.quantity,
        size: item.size || "Regular", // Default size if not provided
      };
    });

    // Create a new order
    const order = new Order({
      restaurant,
      restaurantName, // Include restaurantName
      customer,
      items: validatedItems, // Use the validated items
      totalAmount,
      address,
      orderStatus: "Placed", // Updated to match schema
    });

    await order.save();

    res.status(201).json({ message: "Order placed successfully.", order });
  } catch (error) {
    console.error("Error placing order:", {
      error: error.message,
      stack: error.stack,
    });
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