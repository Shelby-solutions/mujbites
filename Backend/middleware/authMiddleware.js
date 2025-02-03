const jwt = require('jsonwebtoken');
const User = require('../models/user');

/**
 * Middleware to authenticate JWT tokens.
 * @param {Object} req - The request object.
 * @param {Object} res - The response object.
 * @param {Function} next - The next middleware function.
 * @returns {void}
 */
const authenticateToken = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({ 
        success: false,
        message: 'No token provided' 
      });
    }

    jwt.verify(token, process.env.JWT_SECRET, async (err, decoded) => {
      if (err) {
        console.error('Token verification error:', err);
        return res.status(403).json({ 
          success: false,
          message: 'Invalid or expired token' 
        });
      }

      try {
        // Verify user exists and is active
        const user = await User.findById(decoded.userId);
        if (!user) {
          return res.status(404).json({ 
            success: false,
            message: 'User not found' 
          });
        }

        req.user = {
          userId: decoded.userId,
          role: decoded.role
        };
        next();
      } catch (error) {
        console.error('User verification error:', error);
        res.status(500).json({ 
          success: false,
          message: 'Error verifying user' 
        });
      }
    });
  } catch (error) {
    console.error('Authentication error:', error);
    res.status(500).json({ 
      success: false,
      message: 'Authentication error' 
    });
  }
};

module.exports = authenticateToken;