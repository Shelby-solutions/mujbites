const admin = require('firebase-admin');
require('dotenv').config();

const serviceAccount = {
  projectId: process.env.FIREBASE_PROJECT_ID,
  privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
  clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
};

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// Maximum retry attempts for failed notifications
const MAX_RETRIES = 3;
const RETRY_DELAY = 2000; // 2 seconds

// Standardized notification payload structure
const createNotificationPayload = (type, data) => {
  const basePayload = {
    type,
    orderId: data.orderId,
    restaurantId: data.restaurantId,
    status: data.status || 'unknown',
    timestamp: new Date().toISOString(),
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
    // Send a test message that will not actually be delivered
    await admin.messaging().send({
      token,
      data: { test: 'true' }
    }, true);
    return true;
  } catch (error) {
    console.error('Token validation error:', error);
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
  try {
    const response = await admin.messaging().send(message);
    console.log('Notification sent successfully:', response);
    return { success: true, response };
  } catch (error) {
    console.error(`Error sending notification (attempt ${retryCount + 1}):`, error);

    if (retryCount < MAX_RETRIES) {
      await new Promise(resolve => setTimeout(resolve, RETRY_DELAY * (retryCount + 1)));
      return sendNotificationWithRetry(message, retryCount + 1);
    }

    return { 
      success: false, 
      error: error.message,
      code: error.code 
    };
  }
};

const sendNotificationToRestaurant = async (restaurantId, title, body, data) => {
  try {
    // Validate restaurant ID
    if (!isValidRestaurantId(restaurantId)) {
      throw new Error('Invalid restaurant ID format');
    }

    console.log('Sending notification to restaurant:', restaurantId);
    console.log('Notification data:', { title, body, data });

    // Create standardized payload
    const payload = createNotificationPayload(data.type || 'unknown', {
      ...data,
      restaurantId
    });

    const message = {
      topic: `restaurant_${restaurantId}`,
      notification: {
        title,
        body,
        sound: 'default',
      },
      data: {
        ...payload,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        sound: 'default',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'restaurant_orders',
          sound: 'default',
          priority: 'max',
          visibility: 'public',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            'content-available': 1,
            'mutable-content': 1,
            'category': 'restaurant_orders',
          },
        },
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'alert'
        }
      },
    };

    const result = await sendNotificationWithRetry(message);
    
    if (!result.success) {
      throw new Error(`Failed to send notification after ${MAX_RETRIES} attempts`);
    }

    return result.response;
  } catch (error) {
    console.error('Error in sendNotificationToRestaurant:', error);
    throw error;
  }
};

// Export functions
module.exports = {
  sendNotificationToRestaurant,
  validateDeviceToken,
  isValidRestaurantId
}; 