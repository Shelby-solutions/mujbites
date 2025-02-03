const express = require('express');
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const http = require('http');
const WebSocket = require('ws');
const portfinder = require('portfinder');
const { app } = require('./app');

// Configure portfinder
portfinder.basePort = process.env.PORT || 5000;
portfinder.highestPort = 65535;

// Create HTTP server with timeout settings
const server = http.createServer(app);

// Configure server timeouts
server.timeout = 60000; // 60 seconds timeout
server.keepAliveTimeout = 30000; // 30 seconds keep-alive
server.headersTimeout = 35000; // Slightly higher than keepAliveTimeout

// Create WebSocket server
const wss = new WebSocket.Server({ 
  server,
  // WebSocket specific timeouts
  clientTracking: true,
  perMessageDeflate: {
    zlibDeflateOptions: {
      chunkSize: 1024,
      memLevel: 7,
      level: 3
    }
  }
});

// Store connected clients
const clients = new Map();

// WebSocket connection handling
wss.on('connection', (ws, req) => {
  try {
    const url = new URL(req.url, `ws://${req.headers.host}`);
    const userId = url.searchParams.get('userId');
    const restaurantId = url.searchParams.get('restaurantId');

    if (userId && restaurantId) {
      ws.restaurantId = restaurantId;
      clients.set(restaurantId, ws);
      console.log(`Restaurant ${restaurantId} connected to WebSocket`);
      
      // Set WebSocket timeout
      ws.isAlive = true;
      ws.on('pong', () => { ws.isAlive = true; });
      
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

// Implement WebSocket heartbeat
const interval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) return ws.terminate();
    ws.isAlive = false;
    ws.ping(() => {});
  });
}, 30000);

wss.on('close', () => {
  clearInterval(interval);
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