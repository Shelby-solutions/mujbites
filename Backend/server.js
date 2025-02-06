const express = require('express');
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const session = require('express-session');
const http = require('http');
const websocketService = require('./services/websocketService');
const auth = require('./middleware/authMiddleware');
const Cart = require('./models/Cart');
const recommendationRoutes = require('./routes/recommendationRoutes');

dotenv.config();

const app = express();
const server = http.createServer(app);

// Initialize WebSocket service
websocketService.initialize(server);

// Updated CORS configuration with WebSocket support
app.use(cors({
  origin: [
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
    'http://localhost:49421',
    'http://localhost:*',
    'https://localhost:*',
    'https://mujbites-app.vercel.app',
    'https://mujbites-app-*',
    'https://*.mujbites-app.com',
    'https://*.onrender.com'
  ],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true
}));

// Security middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" },
  crossOriginOpenerPolicy: { policy: "same-origin-allow-popups" },
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      connectSrc: ["'self'", 'ws:', 'wss:', 'http:', 'https:'],
      // Add other CSP directives as needed
    }
  }
}));

// Request parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging middleware
app.use(morgan('dev'));

// Session middleware with secure configuration
app.use(
  session({
    secret: process.env.SESSION_SECRET || 'your-secret-key',
    resave: false,
    saveUninitialized: false,
    cookie: { 
      secure: process.env.NODE_ENV === 'production',
      sameSite: process.env.NODE_ENV === 'production' ? 'none' : 'lax',
      maxAge: 24 * 60 * 60 * 1000, // 24 hours
      httpOnly: true
    }
  })
);

// Request logging middleware with sensitive data filtering
app.use((req, res, next) => {
  const sanitizedBody = { ...req.body };
  if (sanitizedBody.password) sanitizedBody.password = '[FILTERED]';
  if (sanitizedBody.token) sanitizedBody.token = '[FILTERED]';
  
  console.log('Request:', {
    method: req.method,
    path: req.path,
    body: sanitizedBody,
    headers: {
      ...req.headers,
      authorization: req.headers.authorization ? '[FILTERED]' : undefined
    }
  });
  next();
});

// MongoDB connection with retry logic
const connectToMongoDB = async (retryCount = 0) => {
  const maxRetries = 5;
  const retryDelay = 5000; // 5 seconds

  try {
    const mongoURI = process.env.MONGODB_URI || process.env.MONGO_URI;
    await mongoose.connect(mongoURI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
      serverSelectionTimeoutMS: 5000,
    });
    console.log('MongoDB connected successfully');
  } catch (err) {
    console.error('MongoDB connection error:', err);
    
    if (retryCount < maxRetries) {
      console.log(`Retrying connection in ${retryDelay/1000} seconds... (Attempt ${retryCount + 1}/${maxRetries})`);
      await new Promise(resolve => setTimeout(resolve, retryDelay));
      return connectToMongoDB(retryCount + 1);
    } else {
      console.error('Failed to connect to MongoDB after maximum retries');
      process.exit(1);
    }
  }
};

connectToMongoDB();

// Import routes
const restaurantRoutes = require('./routes/restaurantRoutes');
const userRoutes = require('./routes/userRoutes');
const orderRoutes = require('./routes/orders');
const recaptchaRouter = require('./routes/recaptchaRouter');

// Cart routes with improved error handling
const cartRoutes = express.Router();

cartRoutes.post('/add', auth, async (req, res) => {
  try {
    const { restaurantId, itemId, quantity, size } = req.body;
    
    // Validate input
    if (!restaurantId || !itemId || !quantity) {
      return res.status(400).json({ 
        message: 'Missing required fields',
        required: ['restaurantId', 'itemId', 'quantity']
      });
    }

    const userId = req.user.id;
    let cart = await Cart.findOne({ user: userId });
    
    if (!cart) {
      cart = new Cart({ user: userId, items: [] });
    }

    const itemIndex = cart.items.findIndex(item => 
      item.item.toString() === itemId && 
      (!size || item.size === size)
    );

    if (itemIndex > -1) {
      cart.items[itemIndex].quantity += quantity;
    } else {
      cart.items.push({
        item: itemId,
        quantity,
        size,
        restaurant: restaurantId
      });
    }

    await cart.save();
    res.json(cart);
  } catch (err) {
    console.error('Cart add error:', err);
    res.status(500).json({ 
      message: 'Failed to add item to cart',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

cartRoutes.get('/', auth, async (req, res) => {
  try {
    const cart = await Cart.findOne({ user: req.user.id })
      .populate('items.item')
      .populate('items.restaurant');
    res.json(cart || { items: [] });
  } catch (err) {
    console.error('Cart fetch error:', err);
    res.status(500).json({ 
      message: 'Failed to fetch cart',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// API routes
app.use('/api/restaurants', restaurantRoutes);
app.use('/api/users', userRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/users', recaptchaRouter);
app.use('/api/cart', cartRoutes);
app.use('/api/recommendations', recommendationRoutes);

// Health check route with detailed status
app.get('/health', (req, res) => {
  const mongoStatus = mongoose.connection.readyState === 1 ? 'connected' : 'disconnected';
  
  res.status(200).json({ 
    status: 'OK',
    timestamp: new Date(),
    environment: process.env.NODE_ENV || 'development',
    services: {
      mongodb: mongoStatus,
      websocket: websocketService.wss ? 'running' : 'not initialized'
    }
  });
});

// 404 Route Not Found with detailed response
app.use((req, res) => {
  res.status(404).json({ 
    message: 'Route not found',
    path: req.originalUrl,
    method: req.method,
    timestamp: new Date()
  });
});

// Error handling middleware with improved error responses
app.use((err, req, res, next) => {
  console.error('Error details:', {
    message: err.message,
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined,
    path: req.originalUrl,
    method: req.method,
    timestamp: new Date()
  });
  
  const statusCode = err.statusCode || 500;
  const errorResponse = {
    message: err.message || 'Internal server error',
    status: statusCode,
    path: req.originalUrl,
    timestamp: new Date()
  };

  if (process.env.NODE_ENV === 'development') {
    errorResponse.stack = err.stack;
    errorResponse.details = err;
  }

  res.status(statusCode).json(errorResponse);
});

// Graceful shutdown handling
const gracefulShutdown = async () => {
  console.log('Received shutdown signal');
  
  try {
    // Close WebSocket server
    if (websocketService.wss) {
      await new Promise(resolve => {
        websocketService.wss.close(() => {
          console.log('WebSocket server closed');
          resolve();
        });
      });
    }

    // Close MongoDB connection
    if (mongoose.connection.readyState === 1) {
      await mongoose.connection.close();
      console.log('MongoDB connection closed');
    }

    // Close HTTP server
    await new Promise(resolve => {
      server.close(() => {
        console.log('HTTP server closed');
        resolve();
      });
    });

    process.exit(0);
  } catch (err) {
    console.error('Error during graceful shutdown:', err);
    process.exit(1);
  }
};

// Register shutdown handlers
process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);

// Start the server
const PORT = process.env.PORT || 5000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`WebSocket server running on ws://0.0.0.0:${PORT}`);
});