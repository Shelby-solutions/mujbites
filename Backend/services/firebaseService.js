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

const sendNotificationToRestaurant = async (restaurantId, title, body, data) => {
  try {
    console.log('Sending notification to restaurant:', restaurantId);
    console.log('Notification data:', { title, body, data });

    const message = {
      topic: `restaurant_${restaurantId}`,
      notification: {
        title,
        body,
        sound: 'default',
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        sound: 'default',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'restaurant_orders',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            'content-available': 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log('Notification sent successfully:', response);
    return response;
  } catch (error) {
    console.error('Error sending notification:', error);
    throw error;
  }
};

module.exports = {
  sendNotificationToRestaurant
}; 