const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const WebSocket = require('ws');
require('dotenv').config();

const app = express();

// Define PORT before using it
const PORT = process.env.PORT || 5000;

// Create WebSocket server with proper error handling
const wss = new WebSocket.Server({ 
  noServer: true,
  handleProtocols: (protocols, request) => {
    return protocols[0];
  }
});

// Add connection tracking
let upgradeInProgress = new Set();

// Function to handle WebSocket upgrade
function handleUpgrade(request, socket, head) {
  const key = `${request.headers['sec-websocket-key']}`;
  
  if (upgradeInProgress.has(key)) {
    console.log('Duplicate upgrade request detected, ignoring');
    return;
  }

  upgradeInProgress.add(key);
  
  try {
    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit('connection', ws, request);
    });
  } catch (error) {
    console.error('Error during WebSocket upgrade:', error);
    socket.destroy();
  } finally {
    upgradeInProgress.delete(key);
  }
}

// WebSocket connection handling
wss.on('connection', (ws, request) => {
  try {
    const url = new URL(request.url, `ws://${request.headers.host}`);
    const userId = url.searchParams.get('userId');
    const restaurantId = url.searchParams.get('restaurantId');
    const token = url.searchParams.get('token');

    console.log('WebSocket connection attempt:', { userId, restaurantId });

    if (userId && restaurantId && token) {
      // Check if restaurant is already connected
      const existingClient = clients.get(restaurantId);
      if (existingClient) {
        console.log(`Closing existing connection for restaurant ${restaurantId}`);
        existingClient.close();
        clients.delete(restaurantId);
      }

      // Setup new connection
      ws.isAlive = true;
      ws.on('pong', heartbeat);
      clients.set(restaurantId, ws);
      
      console.log(`Restaurant ${restaurantId} connected to WebSocket`);
      
      ws.on('close', () => {
        clients.delete(restaurantId);
        console.log(`Restaurant ${restaurantId} disconnected from WebSocket`);
      });

      // Send connection confirmation
      ws.send(JSON.stringify({
        type: 'connectionConfirmed',
        message: 'Successfully connected to WebSocket server'
      }));

      // Setup message handling
      ws.on('message', (message) => {
        try {
          const data = JSON.parse(message);
          console.log('Received message:', data);
          
          if (data.type === 'ping') {
            ws.send(JSON.stringify({ type: 'pong' }));
          }
        } catch (error) {
          console.error('Error processing message:', error);
        }
      });
    } else {
      console.log('Invalid connection attempt - missing parameters');
      ws.close();
    }
  } catch (error) {
    console.error('Error in WebSocket connection:', error);
    ws.close();
  }
});

// Add ping interval to keep connections alive
const interval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) {
      console.log('Terminating inactive connection');
      return ws.terminate();
    }
    
    ws.isAlive = false;
    ws.ping();
  });
}, 30000);

wss.on('close', () => {
  clearInterval(interval);
});

// Function to notify restaurants of new orders
function notifyRestaurant(restaurantId, orderData) {
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
}

// CORS configuration
app.use(cors({
  origin: [
    'http://localhost:3000',
    'http://localhost',
    'http://10.0.2.2:5000',
    'http://localhost:5000',
    'http://127.0.0.1:5000',
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
const userRoutes = require('./routes/userRoutes');
const restaurantRoutes = require('./routes/restaurantRoutes');
const orderRoutes = require('./routes/orders');
const recaptchaRouter = require('./routes/recaptchaRouter');
const cartRoutes = require('./routes/cartRoutes');

// Mount routes
app.use('/api/restaurants', restaurantRoutes);
app.use('/api/users', userRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/verify', recaptchaRouter);
app.use('/api/cart', cartRoutes);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// Export app and WebSocket server
// Export the handleUpgrade function along with other exports
// Remove these lines from app.js
// const WebSocket = require('ws');
// const wss = new WebSocket.Server({ noServer: true });
// const clients = new Map();

module.exports = { app };  // Only export app