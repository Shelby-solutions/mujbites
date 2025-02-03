const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const mongoose = require('mongoose');
const User = require('../models/user');
const Restaurant = require('../models/restaurantModel');
const Order = require('../models/orders');
const authenticateToken = require('../middleware/authMiddleware');
const userController = require('../controllers/userController'); // Import userController
const { loginValidationRules, registerValidationRules } = require('../middleware/validation');

// --- Helper Function ---
const isAdmin = (req, res, next) => {
  if (req.user && req.user.role === 'admin') {
    next();
  } else {
    res.status(403).json({ message: 'Forbidden: Only admins can perform this action' });
  }
};

// --- WhatsApp OTP Routes ---
router.post('/send-otp', userController.sendOTP); // Route to send OTP
router.post('/verify-otp', userController.verifyOTP); // Route to verify OTP

// --- User Authentication Routes ---

// POST /api/users/register (Signup)
router.post('/register', registerValidationRules, userController.signup);

// POST /api/users/login
router.post('/login', loginValidationRules, userController.login);

// Get user profile
router.get('/profile', authenticateToken, userController.getProfile);

// Assign Role (Admin only)
router.post('/assign-role/:userId', authenticateToken, isAdmin, async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const { userId } = req.params;
    const { role, restaurantId, newRestaurantData } = req.body;

    if (!userId || !role) {
      throw new Error('User ID and role are required');
    }

    if (!['admin', 'restaurant', 'user'].includes(role)) {
      throw new Error('Invalid role specified. Role must be one of: admin, restaurant, user.');
    }

    const user = await User.findById(userId).session(session);
    if (!user) {
      throw new Error('User not found');
    }

    if (role === 'restaurant') {
      let restaurant;

      if (restaurantId) {
        restaurant = await Restaurant.findById(restaurantId).session(session);
        if (!restaurant) {
          throw new Error('Restaurant not found');
        }
        if (restaurant.owner && restaurant.owner.toString() !== userId) {
          throw new Error('Restaurant already has an owner');
        }
      } else if (newRestaurantData) {
        const { name, address } = newRestaurantData;
        if (!name) {
          return res.status(400).json({ message: 'Restaurant name is required' });
        }
        restaurant = new Restaurant({
          ...newRestaurantData,
          owner: user._id,
          isActive: true,
        });
        await restaurant.save({ session });
      } else {
        throw new Error('Restaurant ID or new restaurant data is required for restaurant role');
      }

      if (user.restaurant) {
        const prevRestaurant = await Restaurant.findById(user.restaurant).session(session);
        if (prevRestaurant) {
          prevRestaurant.owner = null;
          await prevRestaurant.save({ session });
        }
      }

      restaurant.owner = user._id;
      await restaurant.save({ session });
      user.restaurant = restaurant._id;
    } else {
      if (user.role === 'restaurant' && user.restaurant) {
        const oldRestaurant = await Restaurant.findById(user.restaurant).session(session);
        if (oldRestaurant) {
          oldRestaurant.owner = null;
          await oldRestaurant.save({ session });
        }
        user.restaurant = null;
      }
    }

    user.role = role;
    await user.save({ session });

    await session.commitTransaction();
    session.endSession();

    const updatedUser = await User.findById(userId).populate('restaurant');

    return res.json({
      message: 'Role updated successfully',
      user: updatedUser,
    });
  } catch (error) {
    console.error('Assign role error:', error);
    await session.abortTransaction();
    session.endSession();
    return res.status(400).json({
      message: error.message || 'Error updating user role',
    });
  }
});

// Get All Users (Admin only)
router.get('/', authenticateToken, isAdmin, userController.getAllUsers);

// Get User by ID (Admin only)
router.get('/:id', authenticateToken, isAdmin, userController.getUserById);

// Profile update
router.put('/profile', authenticateToken, userController.updateProfile);

// Update User (Admin only)
router.put('/:id', authenticateToken, isAdmin, userController.updateUser);

// Delete User (Admin only)
router.delete('/:id', authenticateToken, isAdmin, userController.deleteUser);

// Update User Address
router.patch('/profile/address', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { address } = req.body;

    const user = await User.findByIdAndUpdate(
      userId,
      { address },
      { new: true }
    );

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.status(200).json({ message: 'Address updated successfully', user });
  } catch (error) {
    console.error('Error updating address:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Fetch Orders for a User
router.get('/orders', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const orders = await Order.find({ userId }).populate('restaurant items.menuItem');
    res.status(200).json({ orders });
  } catch (error) {
    console.error('Error fetching orders:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Create Order
router.post('/orders', authenticateToken, async (req, res) => {
  try {
    const { restaurant, items, totalAmount, address } = req.body;
    const userId = req.user.userId;

    if (!restaurant || !items || !totalAmount || !address) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ message: 'Items must be a non-empty array' });
    }

    const order = new Order({
      restaurant,
      items,
      totalAmount,
      address,
      userId,
      orderStatus: 'Placed',
    });

    await order.save();

    res.status(201).json({ message: 'Order created successfully', order });
  } catch (error) {
    console.error('Error creating order:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Add this route near the top with other authentication routes
router.get('/verify-token', authenticateToken, async (req, res) => {
  try {
    const user = await User.findById(req.user.userId)
      .select('-password')
      .populate('restaurant');

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.status(200).json({
      success: true,
      user: {
        _id: user._id.toString(),
        username: user.username,
        role: user.role,
        mobileNumber: user.mobileNumber,
        restaurant: user.restaurant?._id?.toString()
      }
    });
  } catch (error) {
    console.error('Token verification error:', error);
    res.status(500).json({
      success: false,
      message: 'Error verifying token'
    });
  }
});

router.post('/logout', authenticateToken, async (req, res) => {
  try {
    // You might want to add token to a blacklist here
    res.status(200).json({
      success: true,
      message: 'Logged out successfully'
    });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({
      success: false,
      message: 'Error during logout'
    });
  }
});

module.exports = router;