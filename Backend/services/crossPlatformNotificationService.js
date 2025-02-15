const admin = require('firebase-admin');
const logger = require('../utils/logger');
const { sendNotificationToRestaurant, sendNotificationToUser } = require('./firebaseService');
const WebSocketService = require('./websocketService');

class CrossPlatformNotificationService {
  constructor() {
    this.webSocketService = new WebSocketService();
  }

  async handleOrderNotification(orderData, platform = 'app') {
    try {
      const {
        orderId,
        restaurantId,
        restaurantName,
        customerId,
        totalAmount,
        status = 'Placed',
        items,
        notificationType = 'ORDER_PLACED',
        title,
        message,
        url
      } = orderData;

      logger.info('Processing cross-platform notification:', {
        orderId,
        platform,
        restaurantId,
        notificationType
      });

      const notificationPromises = [
        // Send FCM notification to restaurant
        this.sendRestaurantNotification(orderData),

        // Send FCM notification to customer
        this.sendCustomerNotification(orderData),

        // Send WebSocket notification for real-time updates
        this.sendWebSocketNotification(orderData)
      ];

      await Promise.allSettled(notificationPromises);

      logger.info('Cross-platform notifications sent successfully', {
        orderId,
        platform,
        notificationType
      });
    } catch (error) {
      logger.error('Error in cross-platform notification:', error);
      // Don't throw error to prevent order creation failure
    }
  }

  async sendRestaurantNotification(orderData) {
    const {
      orderId,
      restaurantId,
      restaurantName,
      totalAmount,
      status,
      notificationType,
      platform
    } = orderData;

    // Create platform-specific notification data
    const notificationData = {
      type: notificationType,
      orderId: orderId.toString(),
      restaurantId,
      restaurantName,
      totalAmount: totalAmount.toString(),
      status,
      priority: this._getPriorityForType(notificationType),
      platform,
      timestamp: new Date().toISOString()
    };

    // Add platform-specific data for web
    if (platform === 'web') {
      notificationData.url = `/restaurant/orders/${orderId}`;
      notificationData.actions = this._getActionsForType(notificationType, 'restaurant');
    }

    const title = this._getNotificationTitle(notificationType, 'restaurant');
    const body = this._getNotificationBody(orderData, 'restaurant');

    return sendNotificationToRestaurant(
      restaurantId,
      title,
      body,
      notificationData
    );
  }

  async sendCustomerNotification(orderData) {
    const {
      orderId,
      customerId,
      restaurantName,
      totalAmount,
      status,
      notificationType,
      platform,
      url
    } = orderData;

    // Create platform-specific notification data
    const notificationData = {
      type: notificationType,
      orderId: orderId.toString(),
      restaurantName,
      totalAmount: totalAmount.toString(),
      status,
      platform,
      timestamp: new Date().toISOString()
    };

    // Add platform-specific data for web
    if (platform === 'web') {
      notificationData.url = url || `/orders/${orderId}`;
      notificationData.actions = this._getActionsForType(notificationType, 'customer');
    }

    const title = this._getNotificationTitle(notificationType, 'customer');
    const body = this._getNotificationBody(orderData, 'customer');

    return sendNotificationToUser(
      customerId,
      title,
      body,
      notificationData
    );
  }

  async sendWebSocketNotification(orderData) {
    const {
      orderId,
      restaurantId,
      customerId,
      notificationType,
      platform
    } = orderData;

    const wsData = {
      type: notificationType,
      data: {
        ...orderData,
        timestamp: new Date().toISOString()
      }
    };

    // Send to restaurant
    this.webSocketService.sendToRestaurant(restaurantId, {
      ...wsData,
      recipient: 'restaurant'
    });

    // Send to customer
    this.webSocketService.sendToUser(customerId, {
      ...wsData,
      recipient: 'customer'
    });
  }

  _getPriorityForType(type) {
    switch (type) {
      case 'ORDER_PLACED':
      case 'ORDER_CANCELLED':
        return 'high';
      default:
        return 'normal';
    }
  }

  _getActionsForType(type, recipient) {
    const actions = [];
    
    if (recipient === 'customer') {
      switch (type) {
        case 'ORDER_PLACED':
          actions.push(
            { action: 'view', title: 'View Order' },
            { action: 'track', title: 'Track Order' }
          );
          break;
        case 'ORDER_CONFIRMED':
          actions.push(
            { action: 'track', title: 'Track Order' },
            { action: 'contact', title: 'Contact Restaurant' }
          );
          break;
        case 'ORDER_READY':
          actions.push(
            { action: 'track', title: 'Track Order' },
            { action: 'directions', title: 'Get Directions' }
          );
          break;
        case 'ORDER_DELIVERED':
          actions.push(
            { action: 'review', title: 'Rate Order' },
            { action: 'reorder', title: 'Order Again' }
          );
          break;
      }
    } else if (recipient === 'restaurant') {
      switch (type) {
        case 'ORDER_PLACED':
          actions.push(
            { action: 'accept', title: 'Accept Order' },
            { action: 'view', title: 'View Details' }
          );
          break;
        case 'ORDER_CONFIRMED':
        case 'ORDER_READY':
          actions.push(
            { action: 'view', title: 'View Order' },
            { action: 'contact', title: 'Contact Customer' }
          );
          break;
      }
    }

    return actions;
  }

  _getNotificationTitle(type, recipient) {
    if (recipient === 'customer') {
      switch (type) {
        case 'ORDER_PLACED':
          return 'Order Placed Successfully';
        case 'ORDER_CONFIRMED':
          return 'Order Confirmed';
        case 'ORDER_READY':
          return 'Order Ready for Pickup';
        case 'ORDER_DELIVERED':
          return 'Order Delivered';
        case 'ORDER_CANCELLED':
          return 'Order Cancelled';
        default:
          return 'Order Update';
      }
    } else {
      switch (type) {
        case 'ORDER_PLACED':
          return 'New Order Received';
        case 'ORDER_CONFIRMED':
          return 'Order Confirmed';
        case 'ORDER_READY':
          return 'Order Ready for Pickup';
        case 'ORDER_DELIVERED':
          return 'Order Delivered';
        case 'ORDER_CANCELLED':
          return 'Order Cancelled';
        default:
          return 'Order Update';
      }
    }
  }

  _getNotificationBody(orderData, recipient) {
    const { orderId, restaurantName, totalAmount, status, notificationType } = orderData;
    const orderNumber = orderId.toString().slice(-6);

    if (recipient === 'customer') {
      switch (notificationType) {
        case 'ORDER_PLACED':
          return `Your order at ${restaurantName} has been placed`;
        case 'ORDER_CONFIRMED':
          return `${restaurantName} has confirmed your order`;
        case 'ORDER_READY':
          return `Your order at ${restaurantName} is ready for pickup`;
        case 'ORDER_DELIVERED':
          return `Your order from ${restaurantName} has been delivered`;
        case 'ORDER_CANCELLED':
          return `Your order at ${restaurantName} has been cancelled`;
        default:
          return `Update for your order at ${restaurantName}`;
      }
    } else {
      switch (notificationType) {
        case 'ORDER_PLACED':
          return `New order #${orderNumber} - ₹${totalAmount}`;
        case 'ORDER_CONFIRMED':
          return `Order #${orderNumber} has been confirmed`;
        case 'ORDER_READY':
          return `Order #${orderNumber} is ready for pickup`;
        case 'ORDER_DELIVERED':
          return `Order #${orderNumber} has been delivered`;
        case 'ORDER_CANCELLED':
          return `Order #${orderNumber} has been cancelled`;
        default:
          return `Update for order #${orderNumber}`;
      }
    }
  }
}

module.exports = new CrossPlatformNotificationService(); 