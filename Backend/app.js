const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
require('dotenv').config();

const app = express();

// CORS configuration
app.use(cors({
  origin: function(origin, callback) {
    const allowedOrigins = [
      'http://localhost:3000',
      'http://localhost',
      'http://10.0.2.2:5000',
      'http://localhost:5000',
      'http://127.0.0.1:5000',
      'ws://localhost:5000',
      'https://mujbites-app.onrender.com',
      'wss://mujbites-app.onrender.com',
      'https://mujbites-app.netlify.app',
      'http://localhost:3001',
      'http://localhost:5173',
      'capacitor://localhost',
      'ionic://localhost',
      'http://localhost:49421'
    ];
    if (!origin || allowedOrigins.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      console.log('Blocked origin:', origin);
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'Origin', 'X-Requested-With'],
  exposedHeaders: ['Content-Length', 'X-Requested-With'],
  maxAge: 86400
}));

// Add security headers
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  next();
});

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