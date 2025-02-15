const admin = require('firebase-admin');
const logger = require('../utils/logger');
const { sendNotificationToRestaurant, sendNotificationToUser } = require('./firebaseService');
const WebSocketService = require('./websocketService');
const User = require('../models/user');
const Restaurant = require('../models/restaurantModel');

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

      // Get restaurant owner's FCM tokens
      const restaurant = await Restaurant.findById(restaurantId).populate('owner');
      if (!restaurant || !restaurant.owner) {
        logger.error('Restaurant or owner not found', { restaurantId });
        return;
      }

      const notificationPromises = [
        // Send FCM notification to customer
        this.sendCustomerNotification(orderData),

        // Send FCM notification to restaurant owner
        this.sendRestaurantOwnerNotification(restaurant.owner._id, orderData),

        // Send WebSocket notification for real-time updates
        this.sendWebSocketNotification(orderData)
      ];

      const results = await Promise.allSettled(notificationPromises);
      
      // Log results
      results.forEach((result, index) => {
        if (result.status === 'rejected') {
          logger.error('Notification failed:', {
            error: result.reason,
            index,
            orderId
          });
        } else {
          logger.info('Notification sent successfully:', {
            index,
            orderId,
            result: result.value
          });
        }
      });

    } catch (error) {
      logger.error('Error in cross-platform notification:', error);
    }
  }

  async sendRestaurantOwnerNotification(ownerId, orderData) {
    try {
      const {
        orderId,
        restaurantId,
        restaurantName,
        totalAmount,
        status,
        notificationType,
        platform
      } = orderData;

      // Get owner's FCM tokens
      const owner = await User.findById(ownerId);
      if (!owner) {
        logger.error('Owner not found', { ownerId });
        return { success: false, error: 'Owner not found' };
      }

      // Get active tokens using the new method
      const tokens = owner.getActiveFCMTokens();
      if (tokens.length === 0) {
        logger.error('No active FCM tokens found for owner', { ownerId });
        return { success: false, error: 'No active FCM tokens' };
      }

      logger.info('Preparing to send FCM notifications to tokens:', tokens);

      // Create notification payload
      const notificationPayload = {
        notification: {
          title: this._getNotificationTitle(notificationType, 'restaurant'),
          body: this._getNotificationBody(orderData, 'restaurant'),
        },
        data: {
          type: notificationType,
          url: platform === 'web' ? '/restaurant' : null,
          orderId: orderId.toString(),
          amount: totalAmount.toString(),
          timestamp: new Date().toISOString(),
          restaurantId: restaurantId.toString(),
          restaurantName,
          status,
          platform
        }
      };

      // Send to all active tokens
      const results = await Promise.all(tokens.map(async (token) => {
        try {
          await admin.messaging().send({
            token,
            ...notificationPayload
          });
          // Update device last active timestamp
          await owner.updateDevice({
            fcmToken: token,
            deviceInfo: { lastNotification: new Date().toISOString() }
          });
          return { success: true, token };
        } catch (error) {
          logger.error('Error sending to token:', { token, error });
          if (error.code === 'messaging/registration-token-not-registered') {
            // Remove invalid token
            await owner.removeToken(token);
            logger.info('Removed invalid token:', token);
          }
          return { success: false, token, error: error.message };
        }
      }));

      const successCount = results.filter(r => r.success).length;
      const failureCount = results.length - successCount;

      return {
        success: successCount > 0,
        response: {
          successCount,
          failureCount,
          results
        }
      };
    } catch (error) {
      logger.error('Error in sendRestaurantOwnerNotification:', error);
      return { success: false, error: error.message };
    }
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

    try {
      const customer = await User.findById(customerId);
      if (!customer) {
        logger.error('Customer not found', { customerId });
        return { success: false, error: 'Customer not found' };
      }

      // Get active tokens
      const tokens = customer.getActiveFCMTokens();
      if (tokens.length === 0) {
        logger.error('No active FCM tokens found for customer', { customerId });
        return { success: false, error: 'No active FCM tokens' };
      }

      const notificationPayload = {
        notification: {
          title: this._getNotificationTitle(notificationType, 'customer'),
          body: this._getNotificationBody(orderData, 'customer'),
        },
        data: {
          type: notificationType,
          url: platform === 'web' ? (url || `/orders/${orderId}`) : null,
          orderId: orderId.toString(),
          amount: totalAmount.toString(),
          timestamp: new Date().toISOString(),
          restaurantName,
          status,
          platform
        }
      };

      // Send to all active tokens
      const results = await Promise.all(tokens.map(async (token) => {
        try {
          await admin.messaging().send({
            token,
            ...notificationPayload
          });
          // Update device last active timestamp
          await customer.updateDevice({
            fcmToken: token,
            deviceInfo: { lastNotification: new Date().toISOString() }
          });
          return { success: true, token };
        } catch (error) {
          if (error.code === 'messaging/registration-token-not-registered') {
            // Remove invalid token
            await customer.removeToken(token);
            logger.info('Removed invalid token:', token);
          }
          return { success: false, token, error: error.message };
        }
      }));

      const successCount = results.filter(r => r.success).length;
      return {
        success: successCount > 0,
        message: 'Notifications sent',
        response: {
          successCount,
          failureCount: results.length - successCount,
          results
        }
      };
    } catch (error) {
      logger.error('Error sending customer notification:', error);
      return { success: false, error: error.message };
    }
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