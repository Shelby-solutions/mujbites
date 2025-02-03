const jwt = require('jsonwebtoken');
const User = require('../models/user');

/**
 * Middleware to authenticate JWT tokens.
 * @param {Object} req - The request object.
 * @param {Object} res - The response object.
 * @param {Function} next - The next middleware function.
 * @returns {void}
 */
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ 
      success: false,
      error: 'Access denied. No token provided.',
    });
  }

  jwt.verify(token, process.env.JWT_SECRET, async (err, decoded) => {
    if (err) {
      // If the token is expired, clear the cache and force logout
      if (err.name === 'TokenExpiredError') {
        return res.status(401).json({ 
          success: false,
          error: 'Token expired. Please log in again.',
          clearCache: true, // Signal the frontend to clear cache
        });
      }

      // Handle other JWT errors
      return res.status(401).json({ 
        success: false,
        error: 'Invalid token',
      });
    }

    // Check if the user exists
    try {
      const user = await User.findById(decoded.userId).select('-password');
      if (!user) {
        return res.status(401).json({ 
          success: false,
          error: 'User not found',
        });
      }

      // Attach user details to the request object
      req.user = {
        userId: user._id,
        role: user.role,
        username: user.username,
        restaurant: user.restaurant, // Include restaurant ID if applicable
      };

      next();
    } catch (error) {
      console.error('Database error:', {
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ 
        success: false,
        error: 'Database error',
        message: error.message,
      });
    }
  });
};

module.exports = authenticateToken;