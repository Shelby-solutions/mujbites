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
const { app, wss, notifyRestaurant, handleUpgrade } = require('./app');
const http = require('http');
const portfinder = require('portfinder');

// Create HTTP server
const server = http.createServer(app);

// Remove these duplicate declarations
// const wss = new WebSocket.Server({ server });
// const clients = new Map();

// Attach WebSocket server to HTTP server
wss.on('connection', (ws, req) => {
  try {
    const url = new URL(req.url, `ws://${req.headers.host}`);
    const userId = url.searchParams.get('userId');
    const restaurantId = url.searchParams.get('restaurantId');
    const type = url.searchParams.get('type');

    console.log('WebSocket connection attempt:', { userId, restaurantId, type });

    if (userId && restaurantId) {
      // Use the clients Map from app.js through the wss context
      wss.clients.set(restaurantId, ws);
      console.log(`Restaurant ${restaurantId} connected to WebSocket`);
      
      ws.on('close', () => {
        wss.clients.delete(restaurantId);
        console.log(`Restaurant ${restaurantId} disconnected from WebSocket`);
      });

      ws.send(JSON.stringify({
        type: 'connectionConfirmed',
        message: 'Successfully connected to WebSocket server'
      }));
    }
  } catch (error) {
    console.error('Error in WebSocket connection:', error);
    ws.close();
  }
});

// Remove the entire notifyRestaurant function since it's imported from app.js

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

// Export only what's needed
module.exports = { server };