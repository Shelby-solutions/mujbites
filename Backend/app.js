const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const WebSocket = require('ws');
require('dotenv').config();

const app = express();

// Define PORT before using it
const PORT = process.env.PORT || 5000;

// Create WebSocket server
const wss = new WebSocket.Server({ noServer: true });

// Store connected clients
const clients = new Map();

wss.on('connection', (ws, request) => {
  const { userId, restaurantId, type } = request.query;
  
  if (userId && restaurantId) {
    clients.set(restaurantId, {
      ws,
      userId,
      type,
      connected: true
    });
    console.log(`Restaurant ${restaurantId} connected to WebSocket`);
    
    ws.on('message', (message) => {
      try {
        const data = JSON.parse(message);
        console.log('Received message:', data);
        // Handle different message types
      } catch (e) {
        console.error('Error parsing message:', e);
      }
    });
    
    ws.on('close', () => {
      const client = clients.get(restaurantId);
      if (client) {
        client.connected = false;
      }
      clients.delete(restaurantId);
      console.log(`Restaurant ${restaurantId} disconnected from WebSocket`);
    });

    // Send connection confirmation
    ws.send(JSON.stringify({
      type: 'connected',
      restaurantId
    }));
  }
});

// Add this to handle WebSocket upgrade
const server = app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});

server.on('upgrade', (request, socket, head) => {
  const pathname = new URL(request.url, 'ws://localhost').pathname;
  
  if (pathname === '/ws') {
    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit('connection', ws, request);
    });
  } else {
    socket.destroy();
  }
});

// Add this function to notify restaurants of new orders
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
    'http://localhost:3000',          // React web
    'http://localhost',               // Flutter web
    'http://10.0.2.2:5000',          // Android emulator
    'http://localhost:5000',          // iOS simulator
    'http://127.0.0.1:5000',         // Local testing
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// MongoDB connection
mongoose.connect(process.env.MONGODB_URI)
  .then(() => console.log('Connected to MongoDB'))
  .catch(err => console.error('MongoDB connection error:', err));

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

// Remove this export
// module.exports = app;

// MongoDB connection
mongoose.connect(process.env.MONGODB_URI)
  .then(() => console.log('Connected to MongoDB'))
  .catch(err => console.error('MongoDB connection error:', err));

// Remove the server.listen call from here since it's now handled in server.js
// Remove these lines:
// const server = app.listen(PORT, () => {
//   console.log(`Server is running on port ${PORT}`);
// });

// Keep only one export at the end of the file
module.exports = { app, notifyRestaurant };