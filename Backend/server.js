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
const { app, wss } = require('./app');  // Remove notifyRestaurant from import
const http = require('http');
const portfinder = require('portfinder');

// Create HTTP server
const server = http.createServer(app);

// Store connected clients
const clients = new Map();

// Attach WebSocket server to HTTP server
wss.on('connection', (ws, req) => {
  try {
    const url = new URL(req.url, `ws://${req.headers.host}`);
    const userId = url.searchParams.get('userId');
    const restaurantId = url.searchParams.get('restaurantId');
    const type = url.searchParams.get('type');

    console.log('WebSocket connection attempt:', { userId, restaurantId, type });

    if (userId && restaurantId) {
      clients.set(restaurantId, ws);  // Use local clients Map
      console.log(`Restaurant ${restaurantId} connected to WebSocket`);
      
      ws.on('close', () => {
        clients.delete(restaurantId);
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

// Define notifyRestaurant function here
function notifyRestaurant(restaurantId, orderData) {
  try {
    console.log('Attempting to notify restaurant:', restaurantId);
    const client = clients.get(restaurantId);
    
    if (client && client.readyState === WebSocket.OPEN) {
      const notification = {
        type: 'newOrder',
        order: orderData
      };
      
      client.send(JSON.stringify(notification));
      console.log(`Notification sent to restaurant ${restaurantId}`);
    } else {
      console.log(`Restaurant ${restaurantId} not connected to WebSocket`);
    }
  } catch (error) {
    console.error('Error sending notification:', error);
  }
}

// Export both server and notifyRestaurant
module.exports = { server, notifyRestaurant };