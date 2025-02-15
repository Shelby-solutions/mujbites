const Order = require('../models/orders');
const Restaurant = require('../models/restaurantModel');
const crossPlatformNotificationService = require('../services/crossPlatformNotificationService');
const logger = require('../utils/logger');
const { createError } = require('../utils/error');

/**
 * @route   POST /api/orders
 * @desc    Create a new order
 * @access  Private (Customer)
 */
const createOrder = async (req, res, next) => {
  try {
    const { restaurant, restaurantName, items, totalAmount, address, platform = 'app' } = req.body;
    const customer = req.user.userId;

    // Input validation
    if (!restaurant || !restaurantName || !Array.isArray(items) || items.length === 0 || !totalAmount || !address) {
      throw createError(400, 'Missing required fields');
    }

    // Validate each item
    const validatedItems = items.map(item => {
      if (!item.menuItem || !item.itemName || !item.quantity || !item.size) {
        throw createError(400, 'Invalid item data');
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
      platform // Track which platform the order came from
    });

    await order.save();
    logger.info('New order created', { 
      orderId: order._id,
      platform,
      restaurantId: restaurant
    });

    // Send notifications using the cross-platform service
    await crossPlatformNotificationService.handleOrderNotification({
      orderId: order._id,
      restaurantId: restaurant,
      restaurantName,
      customerId: customer,
      totalAmount,
      status: order.orderStatus,
      items: validatedItems,
      platform
    });

    res.status(201).json({
      status: 'success',
      message: "Order placed successfully",
      data: { order }
    });
  } catch (error) {
    logger.error("Error creating order:", {
      error: error.message,
      stack: error.stack,
    });
    next(error);
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
const confirmOrder = async (req, res, next) => {
  try {
    const { orderId } = req.params;

    // Update the order status to "Accepted"
    const order = await Order.findByIdAndUpdate(
      orderId,
      { orderStatus: "Accepted" },
      { new: true }
    ).populate('customer restaurant');

    if (!order) {
      throw createError(404, 'Order not found');
    }

    logger.info('Order confirmed', { orderId });

    // Send notifications using cross-platform service
    await crossPlatformNotificationService.handleOrderNotification({
      orderId: order._id,
      restaurantId: order.restaurant._id,
      restaurantName: order.restaurantName,
      customerId: order.customer._id,
      totalAmount: order.totalAmount,
      status: 'Accepted',
      items: order.items,
      platform: order.platform || 'app', // Use the platform from order or default to 'app'
      notificationType: 'ORDER_CONFIRMED',
      title: 'Order Confirmed',
      message: `Your order at ${order.restaurantName} has been confirmed`,
      url: `/orders/${order._id}`
    });

    res.json({
      status: 'success',
      message: "Order confirmed successfully",
      data: { order }
    });
  } catch (error) {
    logger.error("Error confirming order:", {
      error: error.message,
      stack: error.stack,
    });
    next(error);
  }
};

/**
 * @route   PATCH /api/orders/:orderId/deliver
 * @desc    Mark an order as delivered (Restaurant Owner)
 * @access  Private (Restaurant Owner)
 */
const deliverOrder = async (req, res, next) => {
  try {
    const { orderId } = req.params;

    // Update the order status to "Delivered" and set updatedAt
    const order = await Order.findByIdAndUpdate(
      orderId,
      { 
        orderStatus: "Delivered",
        updatedAt: new Date()
      },
      { new: true }
    ).populate('customer restaurant');

    if (!order) {
      throw createError(404, 'Order not found');
    }

    logger.info('Order marked as delivered', { orderId });

    // Send notifications using cross-platform service
    await crossPlatformNotificationService.handleOrderNotification({
      orderId: order._id,
      restaurantId: order.restaurant._id,
      restaurantName: order.restaurantName,
      customerId: order.customer._id,
      totalAmount: order.totalAmount,
      status: 'Delivered',
      items: order.items,
      platform: order.platform || 'app', // Use the platform from order or default to 'app'
      notificationType: 'ORDER_DELIVERED',
      title: 'Order Delivered',
      message: `Your order from ${order.restaurantName} has been delivered`,
      url: `/orders/${order._id}/review` // Direct to review page for web platform
    });

    res.json({
      status: 'success',
      message: "Order marked as delivered",
      data: { order }
    });
  } catch (error) {
    logger.error("Error delivering order:", {
      error: error.message,
      stack: error.stack,
    });
    next(error);
  }
};

module.exports = {
  createOrder,
  getCustomerOrders,
  getRestaurantOrders,
  confirmOrder,
  deliverOrder,
};