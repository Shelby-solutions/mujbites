const admin = require('firebase-admin');
const logger = require('../utils/logger');
const { createHash } = require('crypto');
const User = require('../models/user');
require('dotenv').config();

// Initialize Firebase Admin only if credentials are available
let firebaseInitialized = false;

try {
  if (process.env.FIREBASE_PROJECT_ID && 
      process.env.FIREBASE_PRIVATE_KEY && 
      process.env.FIREBASE_CLIENT_EMAIL) {
    
    const serviceAccount = {
      projectId: process.env.FIREBASE_PROJECT_ID,
      privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    };

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    
    firebaseInitialized = true;
    logger.info('Firebase Admin initialized successfully');
  } else {
    logger.warn('Firebase credentials not found, notifications will be disabled');
  }
} catch (error) {
  logger.error('Error initializing Firebase:', error);
}

// Maximum retry attempts for failed notifications
const MAX_RETRIES = 3;
const RETRY_DELAY = 2000; // 2 seconds
const BATCH_SIZE = 500; // Maximum batch size for notifications

// Notification priority levels
const PRIORITY = {
  HIGH: 'high',
  NORMAL: 'normal',
};

// Cache for active device tokens
const deviceTokenCache = new Map();

// Standardized notification payload structure
const createNotificationPayload = (type, data) => {
  const basePayload = {
    type,
    orderId: data.orderId,
    restaurantId: data.restaurantId,
    status: data.status || 'unknown',
    timestamp: new Date().toISOString(),
    messageId: createHash('sha256')
      .update(`${data.orderId}-${Date.now()}`)
      .digest('hex'),
  };

  // Add optional fields if they exist
  if (data.restaurantName) basePayload.restaurantName = data.restaurantName;
  if (data.totalAmount) basePayload.totalAmount = data.totalAmount;

  return basePayload;
};

// Validate device token
const validateDeviceToken = async (token) => {
  if (!token) return false;
  
  try {
    if (deviceTokenCache.has(token)) {
      return deviceTokenCache.get(token);
    }

    // Send a test message that will not actually be delivered
    await admin.messaging().send({
      token,
      data: { test: 'true' }
    }, true);

    deviceTokenCache.set(token, true);
    return true;
  } catch (error) {
    logger.error('Token validation error:', error);
    deviceTokenCache.set(token, false);
    return false;
  }
};

// Validate restaurant ID format
const isValidRestaurantId = (restaurantId) => {
  return restaurantId && 
         typeof restaurantId === 'string' && 
         restaurantId.match(/^[0-9a-fA-F]{24}$/);
};

const sendNotificationWithRetry = async (message, retryCount = 0) => {
  if (!firebaseInitialized) {
    logger.warn('Firebase not initialized, skipping notification');
    return { success: false, error: 'Firebase not initialized' };
  }

  try {
    const response = await admin.messaging().send(message);
    logger.info('Notification sent successfully:', response);
    return { success: true, response };
  } catch (error) {
    logger.error(`Error sending notification (attempt ${retryCount + 1}):`, error);

    if (error.code === 'messaging/invalid-argument' || 
        error.code === 'messaging/invalid-recipient') {
      return { 
        success: false, 
        error: error.message,
        code: error.code,
        permanent: true 
      };
    }

    if (retryCount < MAX_RETRIES) {
      await new Promise(resolve => 
        setTimeout(resolve, RETRY_DELAY * Math.pow(2, retryCount))
      );
      return sendNotificationWithRetry(message, retryCount + 1);
    }

    return { 
      success: false, 
      error: error.message,
      code: error.code 
    };
  }
};

const sendBatchNotifications = async (messages) => {
  const results = [];
  const failedTokens = new Set();
  
  // Split messages into batches
  for (let i = 0; i < messages.length; i += BATCH_SIZE) {
    const batch = messages.slice(i, i + BATCH_SIZE);
    try {
      const response = await admin.messaging().sendAll(batch);
      results.push(...response.responses);
      
      // Track failed tokens
      response.responses.forEach((resp, index) => {
        if (!resp.success) {
          const token = batch[index].token;
          failedTokens.add(token);
          logger.error('Batch notification failure:', {
            error: resp.error,
            token: token
          });
        }
      });
    } catch (error) {
      logger.error('Error sending batch notifications:', error);
      results.push(...batch.map(() => ({ success: false, error: error.message })));
      
      // Add all tokens from failed batch to retry
      batch.forEach(msg => failedTokens.add(msg.token));
    }
  }
  
  // Handle failed tokens
  if (failedTokens.size > 0) {
    await _handleFailedTokens(Array.from(failedTokens));
  }
  
  return results;
};

const _handleFailedTokens = async (failedTokens) => {
  try {
    const invalidTokens = [];
    const retryableTokens = [];

    // Validate each failed token
    for (const token of failedTokens) {
      try {
        const isValid = await validateDeviceToken(token);
        if (!isValid) {
          invalidTokens.push(token);
        } else {
          retryableTokens.push(token);
        }
      } catch (error) {
        logger.error('Error validating token:', { token, error });
      }
    }

    // Remove invalid tokens from database
    if (invalidTokens.length > 0) {
      await _removeInvalidTokens(invalidTokens);
      logger.info('Removed invalid tokens:', { count: invalidTokens.length });
    }

    // Retry sending to valid tokens with exponential backoff
    if (retryableTokens.length > 0) {
      await _retryNotifications(retryableTokens);
    }
  } catch (error) {
    logger.error('Error handling failed tokens:', error);
  }
};

const _removeInvalidTokens = async (tokens) => {
  try {
    // Implement your token removal logic here
    // This might involve removing tokens from your user records in the database
    logger.info('Removing invalid tokens:', tokens);
  } catch (error) {
    logger.error('Error removing invalid tokens:', error);
  }
};

const _retryNotifications = async (tokens, attempt = 1, maxAttempts = 3) => {
  if (attempt > maxAttempts) {
    logger.warn('Max retry attempts reached for tokens:', tokens);
    return;
  }

  try {
    const delay = Math.pow(2, attempt - 1) * 1000; // Exponential backoff
    await new Promise(resolve => setTimeout(resolve, delay));

    const messages = tokens.map(token => ({
      token,
      notification: {
        title: 'Retry Notification',
        body: 'This is a retry of a failed notification'
      }
    }));

    const response = await admin.messaging().sendAll(messages);
    
    const failedTokens = [];
    response.responses.forEach((resp, index) => {
      if (!resp.success) {
        failedTokens.push(tokens[index]);
      }
    });

    if (failedTokens.length > 0) {
      await _retryNotifications(failedTokens, attempt + 1, maxAttempts);
    }
  } catch (error) {
    logger.error('Error retrying notifications:', error);
  }
};

const sendNotificationToRestaurant = async (restaurantId, title, body, data) => {
  try {
    // Validate restaurant ID
    if (!isValidRestaurantId(restaurantId)) {
      throw new Error('Invalid restaurant ID format');
    }

    logger.info('Sending notification to restaurant:', restaurantId);
    logger.debug('Notification data:', { title, body, data });

    // Retrieve the FCM token for the restaurant (implementation may vary)
    const fcmToken = await getFcmTokenForRestaurant(restaurantId);
    if (!fcmToken) {
      throw new Error('No FCM token found for restaurant ' + restaurantId);
    }

    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body
      },
      android: {
        priority: 'high',
        notification: {
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          sound: 'default'
        }
      },
      data: {
        ...data,
        title: title,
        body: body
      }
    };

    const result = await sendNotificationWithRetry(message);
    
    if (!result.success) {
      if (result.permanent) {
        logger.error('Permanent notification failure:', result.error);
      } else {
        throw new Error(`Failed to send notification after ${MAX_RETRIES} attempts`);
      }
    }

    return result.response;
  } catch (error) {
    logger.error('Error in sendNotificationToRestaurant:', error);
    throw error;
  }
};

const sendNotificationToUser = async (userId, title, body, data = {}) => {
  try {
    if (!userId) {
      throw new Error('User ID is required');
    }

    logger.info('Sending notification to user:', userId);

    // Convert all data values to strings
    const stringifiedData = {};
    Object.entries(data).forEach(([key, value]) => {
      stringifiedData[key] = String(value || '');
    });

    const message = {
      topic: `user_${userId.toString()}`,
      notification: {
        title: String(title),
        body: String(body),
      },
      data: stringifiedData,
      android: {
        priority: 'high',
        notification: {
          channelId: 'orders',
          sound: 'default',
          priority: 'high',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const result = await sendNotificationWithRetry(message);
    if (!result.success) {
      logger.warn('Notification not sent:', result.error);
    }
    return result;
  } catch (error) {
    logger.error('Error in sendNotificationToUser:', error);
    throw error;
  }
};

// Function to get FCM token for a restaurant
const getFcmTokenForRestaurant = async (restaurantId) => {
  try {
    logger.debug('Looking for restaurant user with:', { restaurantId });

    // Find the user with the given restaurant ID and role 'restaurant'
    const restaurantUser = await User.findOne({ 
      restaurant: restaurantId,
      role: 'restaurant'
    }).select('+fcmToken');  // Explicitly select fcmToken field

    if (!restaurantUser) {
      logger.warn(`No restaurant user found for restaurant ${restaurantId}`);
      return null;
    }

    logger.debug('Found restaurant user:', { 
      restaurantId, 
      userId: restaurantUser._id,
      role: restaurantUser.role,
      hasToken: !!restaurantUser.fcmToken,
      token: restaurantUser.fcmToken?.substring(0, 10) + '...',  // Log first 10 chars of token for debugging
      deviceType: restaurantUser.deviceType,
      lastTokenUpdate: restaurantUser.lastTokenUpdate
    });

    if (!restaurantUser.fcmToken) {
      logger.warn(`Restaurant user found but no FCM token available for ${restaurantId}`);
      return null;
    }

    return restaurantUser.fcmToken;
  } catch (error) {
    logger.error('Error getting FCM token for restaurant:', error);
    throw error;
  }
};

// Export functions
module.exports = {
  sendNotificationToRestaurant,
  sendNotificationToUser,
  validateDeviceToken,
  isValidRestaurantId,
  sendBatchNotifications,
  PRIORITY,
  getFcmTokenForRestaurant
}; 