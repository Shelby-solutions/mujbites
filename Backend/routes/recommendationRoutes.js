const express = require('express');
const router = express.Router();
const authenticateToken = require('../middleware/authMiddleware');
const recommendationsController = require('../controllers/recommendationsController');

// Debug middleware to log all requests
router.use((req, res, next) => {
  console.log('Recommendations middleware:', {
    method: req.method,
    path: req.path,
    baseUrl: req.baseUrl,
    headers: req.headers,
    user: req.user
  });
  next();
});

// Test route (no auth required)
router.get('/test', (req, res) => {
  res.json({
    success: true,
    message: 'Recommendations route is working'
  });
});

// Health check route (no auth required)
router.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'Recommendations service is healthy',
    timestamp: new Date().toISOString()
  });
});

// Main recommendations route
router.get('/', authenticateToken, async (req, res) => {
  console.log('GET /recommendations handler called');
  try {
    // Ensure user is authenticated and has the correct role
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required'
      });
    }

    if (req.user.role !== 'user') {
      return res.status(403).json({
        success: false,
        message: 'Only customers can get recommendations'
      });
    }

    await recommendationsController.getRecommendations(req, res);
  } catch (error) {
    console.error('Recommendations route error:', error);
    res.status(500).json({
      success: false,
      message: 'Error processing recommendations request',
      error: error.message
    });
  }
});

module.exports = router;
