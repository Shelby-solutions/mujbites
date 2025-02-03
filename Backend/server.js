const express = require('express');
// Remove duplicate express and app declarations
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const http = require('http');
const WebSocket = require('ws');
const portfinder = require('portfinder');
const { app } = require('./app');  // Only import app

// Create HTTP server
const server = http.createServer(app);

// Create WebSocket server
const wss = new WebSocket.Server({ server });

// Store connected clients
const clients = new Map();

// WebSocket connection handling
wss.on('connection', (ws, req) => {
  try {
    const url = new URL(req.url, `ws://${req.headers.host}`);
    const userId = url.searchParams.get('userId');
    const restaurantId = url.searchParams.get('restaurantId');
    const type = url.searchParams.get('type');

    console.log('WebSocket connection attempt:', { userId, restaurantId, type });

    if (userId && restaurantId) {
      clients.set(restaurantId, ws);
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

// Define notifyRestaurant function
const notifyRestaurant = (restaurantId, orderData) => {
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
      return true;
    } else {
      console.log(`Restaurant ${restaurantId} not connected to WebSocket`);
      return false;
    }
  } catch (error) {
    console.error('Error sending notification:', error);
    return false;
  }
};

// Make notifyRestaurant available globally
global.notifyRestaurant = notifyRestaurant;

// Export server and notifyRestaurant
module.exports = { server, notifyRestaurant };