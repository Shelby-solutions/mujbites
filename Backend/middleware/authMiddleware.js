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
    console.log('\n=== Auth Middleware ===');
    console.log('Headers:', req.headers);
    
    const authHeader = req.headers['authorization'];
    console.log('Auth header:', authHeader);
    
    const token = authHeader && authHeader.split(' ')[1];
    console.log('Extracted token:', token ? 'exists' : 'missing');

    if (!token) {
      console.log('No token provided');
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
          message: 'Invalid or expired token',
          error: process.env.NODE_ENV === 'development' ? err.message : undefined
        });
      }

      try {
        console.log('Token decoded:', decoded);
        
        // Verify user exists and is active
        const user = await User.findById(decoded.userId);
        console.log('User found:', user ? 'yes' : 'no');
        
        if (!user) {
          console.log('User not found for ID:', decoded.userId);
          return res.status(404).json({ 
            success: false,
            message: 'User not found' 
          });
        }

        req.user = {
          userId: decoded.userId,
          role: decoded.role
        };
        console.log('User authenticated:', req.user);
        next();
      } catch (error) {
        console.error('User verification error:', error);
        res.status(500).json({ 
          success: false,
          message: 'Error verifying user',
          error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
      }
    });
  } catch (error) {
    console.error('Authentication error:', error);
    res.status(500).json({ 
      success: false,
      message: 'Authentication error',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

module.exports = authenticateToken;