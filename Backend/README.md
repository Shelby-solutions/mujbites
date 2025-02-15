# MujBites Cross-Platform Notification System

## Overview
This system handles notifications for orders placed through both the mobile app and the web platform. It ensures that notifications are delivered consistently regardless of the order's origin.

## Architecture

### Components
1. **CrossPlatformNotificationService**
   - Handles notifications for all platforms
   - Manages FCM (Firebase Cloud Messaging) notifications
   - Handles WebSocket real-time updates
   - Supports both mobile app and web notifications

2. **Firebase Cloud Messaging (FCM)**
   - Used for push notifications to mobile devices
   - Handles notifications for restaurant owners and customers
   - Supports both Android and iOS platforms

3. **WebSocket Service**
   - Provides real-time updates
   - Used by both web and mobile platforms
   - Ensures instant order status updates

### Notification Flow
1. Order is placed (from either platform)
2. Order is saved to MongoDB
3. CrossPlatformNotificationService is triggered
4. Notifications are sent through:
   - FCM for mobile push notifications
   - WebSocket for real-time updates
   - Email notifications (if configured)

## Setup Requirements

### Environment Variables
Make sure these environment variables are set in your `.env` file:
```
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY=your-private-key
FIREBASE_CLIENT_EMAIL=your-client-email
FIREBASE_SERVER_KEY=your-server-key
BASE_URL=your-base-url
```

### Firebase Setup
1. Create a Firebase project
2. Download service account credentials
3. Enable FCM in your project
4. Add the Firebase configuration to your environment

## Usage

### Sending Notifications
```javascript
const notificationService = require('./services/crossPlatformNotificationService');

// Example: Sending notification for new order
await notificationService.handleOrderNotification({
  orderId: "order_id",
  restaurantId: "restaurant_id",
  restaurantName: "Restaurant Name",
  customerId: "customer_id",
  totalAmount: 1000,
  status: "Placed",
  platform: "web" // or "app"
});
```

### Platform-Specific Considerations

#### Mobile App
- Requires FCM token registration
- Handles background and foreground notifications
- Uses local notification channels for Android

#### Web Platform
- Uses WebSocket for real-time updates
- Supports browser notifications
- Maintains WebSocket connection for live updates

## Troubleshooting

### Common Issues
1. **Missing Notifications**
   - Check FCM token validity
   - Verify WebSocket connection
   - Check environment variables

2. **Delayed Notifications**
   - Check network connectivity
   - Verify Firebase service status
   - Check server load

### Logging
- All notification attempts are logged
- Check logs for detailed error information
- Monitor notification delivery status

## Security
- All WebSocket connections are authenticated
- FCM tokens are validated and refreshed
- Sensitive data is encrypted
- Rate limiting is implemented

## Testing
```bash
# Test notification service
npm run test:notifications

# Test WebSocket connection
npm run test:websocket
``` 