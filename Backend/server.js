const express = require('express');
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const session = require('express-session');
const MongoStore = require('connect-mongo');
const auth = require('./middleware/authMiddleware');
const Cart = require('./models/Cart');
const { app } = require('./app');
const http = require('http');
const WebSocket = require('ws');
const portfinder = require('portfinder');

// Load environment variables
dotenv.config();

// Set mongoose options
mongoose.set('strictQuery', true);

// Create HTTP server
const server = http.createServer(app);

// Initialize WebSocket server
const wss = new WebSocket.Server({ server });

// Store connected clients
const clients = new Map();

// Add notifyRestaurant function
const notifyRestaurant = (restaurantId, orderData) => {
  const client = clients.get(restaurantId);
  if (client && client.readyState === WebSocket.OPEN) {
    client.send(JSON.stringify({
      type: 'newOrder',
      order: orderData
    }));
    console.log(`Notification sent to restaurant ${restaurantId}`);
  } else {
    console.log(`Restaurant ${restaurantId} not connected to WebSocket`);
  }
};

// WebSocket connection handling
wss.on('connection', (ws, req) => {
  const { userId, restaurantId } = req.query;
  if (userId && restaurantId) {
    clients.set(restaurantId, ws);
    console.log(`Restaurant ${restaurantId} connected to WebSocket`);
    
    ws.on('close', () => {
      clients.delete(restaurantId);
      console.log(`Restaurant ${restaurantId} disconnected from WebSocket`);
    });
  }
});

// Graceful shutdown
process.on('SIGINT', async () => {
  try {
    await mongoose.connection.close();
    server.close(() => {
      console.log('Server and MongoDB connection closed');
      process.exit(0);
    });
  } catch (err) {
    console.error('Error during shutdown:', err);
    process.exit(1);
  }
});

// Add startServer function
const startServer = async () => {
  try {
    // Connect to MongoDB only once
    if (mongoose.connection.readyState === 0) {  // Only connect if not connected
      await mongoose.connect(process.env.MONGODB_URI, {
        useNewUrlParser: true,
        useUnifiedTopology: true
      });
      console.log('Connected to MongoDB');
    }

    // Use portfinder directly instead of manual check
    const port = await portfinder.getPortPromise({
      port: parseInt(process.env.PORT) || 3000,    // Start with desired port
      stopPort: 65535                             // Maximum port number
    });

    server.listen(port, () => {
      console.log(`Server running on port ${port}`);
      console.log(`Environment: ${process.env.NODE_ENV}`);
    });
  } catch (err) {
    console.error('Failed to start server:', err);
    process.exit(1);
  }
};
// Start server
startServer().catch(err => {
  console.error('Failed to start server:', err);
  process.exit(1);
});

// Export notification function
module.exports = { notifyRestaurant };