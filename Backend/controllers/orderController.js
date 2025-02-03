const Order = require('../models/orders');
const Restaurant = require('../models/restaurantModel');
const { sendOrderNotification } = require('../notifications/orderNotifications');

/**
 * @route   POST /api/orders
 * @desc    Create a new order
 * @access  Private (Customer)
 */
const createOrder = async (req, res) => {
  try {
    const { restaurant, restaurantName, items, totalAmount, address } = req.body;
    const customer = req.user.userId;

    // Input validation
    if (!restaurant || !restaurantName || !Array.isArray(items) || items.length === 0 || !totalAmount || !address) {
      return res.status(400).json({ 
        message: "Missing required fields" 
      });
    }

    // Validate each item
    const validatedItems = items.map(item => {
      if (!item.menuItem || !item.itemName || !item.quantity || !item.size) {
        throw new Error("Invalid item data");
      }
      return {
        menuItem: item.menuItem,
        itemName: item.itemName,
        quantity: item.quantity,
        size: item.size,
      };
    });

    // Create order
    const order = new Order({
      restaurant,
      restaurantName,
      customer,
      items: validatedItems,
      totalAmount,
      address,
      orderStatus: "Placed",
    });

    await order.save();

    // Send notifications
    try {
      // Notify customer
      await sendOrderNotification(
        customer,
        'ORDER_PLACED',
        { restaurantName }
      );

      // Notify restaurant owner
      const restaurantData = await Restaurant.findById(restaurant).populate("owner");
      if (restaurantData?.owner) {
        await sendOrderNotification(
          restaurantData.owner._id,
          'NEW_ORDER',
          { restaurantName }
        );
      }
    } catch (notificationError) {
      console.error('Notification error:', notificationError);
      // Don't fail the order if notifications fail
    }

    res.status(201).json({
      message: "Order placed successfully",
      order
    });
  } catch (error) {
    console.error("Error creating order:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ 
      message: "Failed to create order",
      error: error.message 
    });
  }
};

/**
 * @route   GET /api/orders
 * @desc    Get all orders for the logged-in customer
 * @access  Private (Customer)
 */
const getCustomerOrders = async (req, res) => {
  try {
    const customerId = req.user.userId; // Get the user ID from the token

    // Fetch orders for the logged-in customer
    const orders = await Order.find({ customer: customerId })
      .populate("restaurant", "name") // Populate restaurant details
      .populate("items.menuItem", "name price") // Populate menu item details
      .sort({ createdAt: -1 }); // Sort by creation date (newest first)

    res.status(200).json({ orders });
  } catch (error) {
    console.error("Error fetching customer orders:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ message: "Server error.", error: error.message });
  }
};

/**
 * @route   GET /api/orders/restaurant/:restaurantId
 * @desc    Get all orders for a specific restaurant
 * @access  Private (Restaurant Owner)
 */
const getRestaurantOrders = async (req, res) => {
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
      .sort({ createdAt: -1 }); // Sort by creation date (newest first)

    res.status(200).json({ orders });
  } catch (error) {
    console.error("Error fetching restaurant orders:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ message: "Server error.", error: error.message });
  }
};

/**
 * @route   PATCH /api/orders/:orderId/confirm
 * @desc    Confirm an order (Restaurant Owner)
 * @access  Private (Restaurant Owner)
 */
const confirmOrder = async (req, res) => {
  try {
    const { orderId } = req.params;

    // Update the order status to "Accepted"
    const order = await Order.findByIdAndUpdate(
      orderId,
      { orderStatus: "Accepted" },
      { new: true }
    );

    if (!order) {
      return res.status(404).json({ message: "Order not found." });
    }

    // Send notification to the customer
    try {
      const result = await sendOrderNotification(
        order.customer,
        'ORDER_CONFIRMED'
      );

      if (result.success) {
        console.log("Notification sent successfully:", result);
      } else {
        console.error("Failed to send notification:", result.error);
      }
    } catch (error) {
      console.error("Error sending notification:", error);
    }

    res.status(200).json({ message: "Order confirmed successfully.", order });
  } catch (error) {
    console.error("Error confirming order:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ message: "Server error.", error: error.message });
  }
};

/**
 * @route   PATCH /api/orders/:orderId/deliver
 * @desc    Mark an order as delivered (Restaurant Owner)
 * @access  Private (Restaurant Owner)
 */
const deliverOrder = async (req, res) => {
  try {
    const { orderId } = req.params;

    // Update the order status to "Delivered"
    const order = await Order.findByIdAndUpdate(
      orderId,
      { orderStatus: "Delivered" },
      { new: true }
    );

    if (!order) {
      return res.status(404).json({ message: "Order not found." });
    }

    // Send notification to the customer
    try {
      const result = await sendOrderNotification(
        order.customer,
        'ORDER_DELIVERED'
      );

      if (result.success) {
        console.log("Notification sent successfully:", result);
      } else {
        console.error("Failed to send notification:", result.error);
      }
    } catch (error) {
      console.error("Error sending notification:", error);
    }

    res.status(200).json({ message: "Order marked as delivered.", order });
  } catch (error) {
    console.error("Error delivering order:", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ message: "Server error.", error: error.message });
  }
};

module.exports = {
  createOrder,
  getCustomerOrders,
  getRestaurantOrders,
  confirmOrder,
  deliverOrder,
};