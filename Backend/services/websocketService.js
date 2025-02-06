const WebSocket = require('ws');
const jwt = require('jsonwebtoken');

class WebSocketService {
  constructor() {
    this.wss = null;
    this.clients = new Map(); // Map to store client connections
  }

  initialize(server) {
    this.wss = new WebSocket.Server({ server });

    this.wss.on('connection', (ws, req) => {
      console.log('New WebSocket connection');

      // Handle authentication
      this._handleAuthentication(ws, req);

      ws.on('message', (message) => {
        this._handleMessage(ws, message);
      });

      ws.on('close', () => {
        this._handleDisconnection(ws);
      });

      // Send a ping every 30 seconds to keep the connection alive
      const pingInterval = setInterval(() => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.ping();
        }
      }, 30000);

      ws.on('close', () => {
        clearInterval(pingInterval);
      });
    });
  }

  async _handleAuthentication(ws, req) {
    try {
      const token = req.url.split('token=')[1];
      if (!token) {
        ws.close(4001, 'Authentication required');
        return;
      }

      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      ws.userId = decoded.userId;
      ws.userType = decoded.userType;

      // Store the connection
      if (!this.clients.has(decoded.userId)) {
        this.clients.set(decoded.userId, new Set());
      }
      this.clients.get(decoded.userId).add(ws);

      // Send confirmation
      ws.send(JSON.stringify({
        type: 'connection_established',
        userId: decoded.userId
      }));
    } catch (error) {
      console.error('WebSocket authentication error:', error);
      ws.close(4002, 'Authentication failed');
    }
  }

  _handleMessage(ws, message) {
    try {
      const data = JSON.parse(message);
      console.log('Received WebSocket message:', data);

      // Handle different message types
      switch (data.type) {
        case 'ping':
          ws.send(JSON.stringify({ type: 'pong' }));
          break;
        // Add more message type handlers as needed
        default:
          console.log('Unknown message type:', data.type);
      }
    } catch (error) {
      console.error('Error handling WebSocket message:', error);
    }
  }

  _handleDisconnection(ws) {
    console.log('Client disconnected');
    
    // Remove the connection from our stored clients
    if (ws.userId) {
      const userConnections = this.clients.get(ws.userId);
      if (userConnections) {
        userConnections.delete(ws);
        if (userConnections.size === 0) {
          this.clients.delete(ws.userId);
        }
      }
    }
  }

  // Send a message to a specific user
  sendToUser(userId, message) {
    const userConnections = this.clients.get(userId);
    if (!userConnections) return;

    const messageString = JSON.stringify(message);
    userConnections.forEach(ws => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(messageString);
      }
    });
  }

  // Send a message to all connected clients
  broadcast(message) {
    const messageString = JSON.stringify(message);
    this.wss.clients.forEach(client => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(messageString);
      }
    });
  }

  // Send a message to all clients of a specific restaurant
  sendToRestaurant(restaurantId, message) {
    const messageString = JSON.stringify(message);
    this.wss.clients.forEach(client => {
      if (client.readyState === WebSocket.OPEN && 
          client.userType === 'restaurant' && 
          client.restaurantId === restaurantId) {
        client.send(messageString);
      }
    });
  }
}

// Create and export a singleton instance
const websocketService = new WebSocketService();
module.exports = websocketService; 