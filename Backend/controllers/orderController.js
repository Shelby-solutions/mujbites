const Order = require('../models/orders');
const Restaurant = require('../models/restaurantModel');
const { sendOrderNotification } = require('../notifications/orderNotifications');
const { sendNotificationToRestaurant, sendBatchNotifications, PRIORITY } = require('../services/firebaseService');
const logger = require('../utils/logger');
const { createError } = require('../utils/error');

/**
 * @route   POST /api/orders
 * @desc    Create a new order
 * @access  Private (Customer)
 */
const createOrder = async (req, res, next) => {
  try {
    const { restaurant, restaurantName, items, totalAmount, address } = req.body;
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
    });

    await order.save();
    logger.info('New order created', { orderId: order._id });

    // Send notifications
    try {
      const notificationPromises = [
        // Notify customer
        sendOrderNotification(
          customer,
          'ORDER_PLACED',
          { 
            restaurantName,
            orderId: order._id,
            totalAmount: order.totalAmount.toString()
          }
        ),

        // Notify restaurant owner
        Restaurant.findById(restaurant)
          .populate("owner")
          .then(restaurantData => {
            if (restaurantData?.owner) {
              return sendOrderNotification(
                restaurantData.owner._id,
                'NEW_ORDER',
                { 
                  restaurantName,
                  orderId: order._id,
                  totalAmount: order.totalAmount.toString()
                }
              );
            }
          }),

        // Send notification to restaurant
        sendNotificationToRestaurant(
          order.restaurant,
          'New Order Received!',
          `Order #${order._id.toString().slice(-6)}`,
          {
            orderId: order._id.toString(),
            restaurantId: order.restaurant,
            restaurantName: order.restaurantName,
            totalAmount: order.totalAmount.toString(),
            status: order.orderStatus,
            type: 'order',
            priority: PRIORITY.HIGH
          }
        )
      ];

      // Wait for all notifications to be sent
      const results = await Promise.allSettled(notificationPromises);
      
      // Log any notification failures
      results.forEach((result, index) => {
        if (result.status === 'rejected') {
          logger.error('Notification failed', {
            error: result.reason,
            notificationIndex: index,
            orderId: order._id
          });
        }
      });
    } catch (notificationError) {
      logger.error('Error sending notifications', {
        error: notificationError,
        orderId: order._id
      });
      // Don't fail the order if notifications fail
    }

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
    );

    if (!order) {
      throw createError(404, 'Order not found');
    }

    logger.info('Order confirmed', { orderId });

    // Send notifications
    try {
      const notificationPromises = [
        // Notify customer
        sendOrderNotification(
          order.customer,
          'ORDER_CONFIRMED',
          {
            orderId: order._id,
            restaurantName: order.restaurantName
          }
        ),

        // Notify restaurant
        sendNotificationToRestaurant(
          order.restaurant,
          'Order Accepted',
          `Order #${order._id.toString().slice(-6)} has been accepted`,
          {
            orderId: order._id.toString(),
            restaurantId: order.restaurant,
            status: 'Accepted',
            type: 'order',
            priority: PRIORITY.NORMAL
          }
        )
      ];

      const results = await Promise.allSettled(notificationPromises);
      
      results.forEach((result, index) => {
        if (result.status === 'rejected') {
          logger.error('Confirmation notification failed', {
            error: result.reason,
            notificationIndex: index,
            orderId
          });
        }
      });
    } catch (error) {
      logger.error('Error sending confirmation notifications', {
        error,
        orderId
      });
    }

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
    );

    if (!order) {
      throw createError(404, 'Order not found');
    }

    logger.info('Order marked as delivered', { orderId });

    // Send notifications
    try {
      const notificationPromises = [
        // Notify customer
        sendOrderNotification(
          order.customer,
          'ORDER_DELIVERED',
          {
            orderId: order._id,
            restaurantName: order.restaurantName
          }
        ),

        // Notify restaurant
        sendNotificationToRestaurant(
          order.restaurant,
          'Order Delivered',
          `Order #${order._id.toString().slice(-6)} has been delivered`,
          {
            orderId: order._id.toString(),
            restaurantId: order.restaurant,
            status: 'Delivered',
            type: 'order',
            priority: PRIORITY.NORMAL
          }
        )
      ];

      const results = await Promise.allSettled(notificationPromises);
      
      results.forEach((result, index) => {
        if (result.status === 'rejected') {
          logger.error('Delivery notification failed', {
            error: result.reason,
            notificationIndex: index,
            orderId
          });
        }
      });
    } catch (error) {
      logger.error('Error sending delivery notifications', {
        error,
        orderId
      });
    }

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