const express = require('express');
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const http = require('http');
const WebSocket = require('ws');
const portfinder = require('portfinder');
const { app } = require('./app');

// Configure port
const PORT = process.env.PORT || 5000;

// Validate port
if (!PORT) {
  console.error('Port is not defined');
  process.exit(1);
}

// Create HTTP server with timeout settings
const server = http.createServer(app);

// Configure server timeouts
server.timeout = 60000; // 60 seconds timeout
server.keepAliveTimeout = 30000; // 30 seconds keep-alive
server.headersTimeout = 35000; // Slightly higher than keepAliveTimeout

// Create WebSocket server with improved settings
const wss = new WebSocket.Server({ 
  noServer: true,
  clientTracking: true,
  maxPayload: 50 * 1024 * 1024, // 50MB max payload
  perMessageDeflate: {
    zlibDeflateOptions: {
      chunkSize: 1024,
      memLevel: 7,
      level: 3
    },
    serverNoContextTakeover: true,
    clientNoContextTakeover: true,
    concurrencyLimit: 10,
    threshold: 1024
  }
});

// Store connected clients
const clients = new Map();

// Heartbeat function
function heartbeat() {
  this.isAlive = true;
}

// WebSocket connection handling
wss.on('connection', (ws, req) => {
  try {
    const url = new URL(req.url, `ws://${req.headers.host}`);
    const userId = url.searchParams.get('userId');
    const restaurantId = url.searchParams.get('restaurantId');
    const token = url.searchParams.get('token');

    if (!userId || !restaurantId || !token) {
      console.log('Invalid connection attempt - missing parameters');
      ws.close();
      return;
    }

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
    ws.restaurantId = restaurantId;
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
  } catch (error) {
    console.error('Error in WebSocket connection:', error);
    ws.close();
  }
});

// Implement WebSocket heartbeat
const interval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) {
      console.log('Terminating inactive connection');
      if (ws.restaurantId) {
        clients.delete(ws.restaurantId);
      }
      return ws.terminate();
    }
    ws.isAlive = false;
    ws.ping();
  });
}, 30000);

wss.on('close', () => {
  clearInterval(interval);
});

// Handle WebSocket upgrade with improved error handling
server.on('upgrade', (request, socket, head) => {
  try {
    const url = new URL(request.url, `ws://${request.headers.host}`);
    const token = url.searchParams.get('token');
    
    if (!token) {
      console.log('WebSocket upgrade rejected: Missing token');
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
      return;
    }

    // Set socket timeout
    socket.setTimeout(30000);
    socket.setKeepAlive(true, 30000);

    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit('connection', ws, request);
    });
  } catch (error) {
    console.error('Error during WebSocket upgrade:', error);
    socket.write('HTTP/1.1 500 Internal Server Error\r\n\r\n');
    socket.destroy();
  }
});

// Start server
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on port ${PORT}`);
});

// Define notifyRestaurant function
const notifyRestaurant = (restaurantId, orderData) => {
  try {
    const ws = clients.get(restaurantId);
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        type: 'newOrder',
        order: orderData
      }));
      console.log(`Order notification sent to restaurant ${restaurantId}`);
      return true;
    }
    console.log(`Restaurant ${restaurantId} not connected to WebSocket`);
    return false;
  } catch (error) {
    console.error('Error sending notification:', error);
    return false;
  }
};

// Make notifyRestaurant available globally
global.notifyRestaurant = notifyRestaurant;

// Export server and notifyRestaurant
module.exports = { server, notifyRestaurant };