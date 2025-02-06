const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { validationResult } = require('express-validator');
const axios = require('axios');
const Restaurant = require('../models/restaurantModel');
const User = require('../models/user');

// Function to verify reCAPTCHA
const verifyRecaptcha = async (token) => {
  try {
    const response = await axios.post(
      'https://www.google.com/recaptcha/api/siteverify',
      null,
      {
        params: {
          secret: process.env.RECAPTCHA_SECRET_KEY,
          response: token,
        },
      }
    );
    return response.data.success;
  } catch (error) {
    console.error('reCAPTCHA verification error:', {
      error: error.message,
      stack: error.stack,
    });
    return false;
  }
};

// Function to send OTP via WhatsApp
const sendOTP = async (req, res) => {
  const { mobileNumber } = req.body;

  try {
    const otp = Math.floor(100000 + Math.random() * 900000); // Generate 6-digit OTP

    // Send OTP via WhatsApp Business API
    const response = await axios.post(
      `https://graph.facebook.com/v18.0/${process.env.WHATSAPP_PHONE_NUMBER_ID}/messages`,
      {
        messaging_product: 'whatsapp',
        to: mobileNumber,
        type: 'template',
        template: {
          name: 'otp_template', // Create this template in WhatsApp Business Manager
          language: { code: 'en' },
          components: [
            {
              type: 'body',
              parameters: [{ type: 'text', text: otp }],
            },
          ],
        },
      },
      {
        headers: {
          Authorization: `Bearer ${process.env.WHATSAPP_ACCESS_TOKEN}`,
          'Content-Type': 'application/json',
        },
      }
    );

    // Save OTP in the user's session or database (optional)
    req.session.otp = otp;

    res.status(200).json({ message: 'OTP sent successfully', otp });
  } catch (error) {
    console.error('Failed to send OTP:', error.response?.data || error.message);
    res.status(500).json({ error: 'Failed to send OTP' });
  }
};

// Function to verify OTP
const verifyOTP = async (req, res) => {
  const { mobileNumber, otp } = req.body;

  try {
    // Verify OTP (compare with the OTP stored in the session or database)
    if (otp === req.session.otp) {
      // Create a new user
      const user = new User({ mobileNumber });
      await user.save();

      // Clear the OTP from the session
      req.session.otp = null;

      res.status(200).json({ message: 'OTP verified successfully', user });
    } else {
      res.status(400).json({ error: 'Invalid OTP' });
    }
  } catch (error) {
    console.error('Failed to verify OTP:', error);
    res.status(500).json({ error: 'Failed to verify OTP' });
  }
};

// Get user profile
const getProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user.userId)
      .select('-password')
      .populate('restaurant');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    res.json(user);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// Get all users
const getAllUsers = async (req, res) => {
  try {
    const users = await User.find({}).populate('restaurant');
    res.status(200).json(users);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// Get user by ID
const getUserById = async (req, res) => {
  try {
    const user = await User.findById(req.params.id).populate('restaurant');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    res.status(200).json(user);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// Update user profile
const updateProfile = async (req, res) => {
  try {
    const { username, mobileNumber, address, oldPassword, newPassword } = req.body;
    const userId = req.user.userId;

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found.' });
    }

    if (username) user.username = username;
    if (mobileNumber) user.mobileNumber = mobileNumber;
    if (address) user.address = address;

    if (oldPassword && newPassword) {
      const isMatch = await bcrypt.compare(oldPassword, user.password);
      if (!isMatch) {
        return res.status(400).json({ message: 'Old password is incorrect.' });
      }
      const salt = await bcrypt.genSalt(10);
      user.password = await bcrypt.hash(newPassword, salt);
    }

    await user.save();
    res.status(200).json({ message: 'Profile updated successfully.' });
  } catch (error) {
    console.error('Error updating profile:', error);
    res.status(500).json({ message: 'Server error.', error: error.message });
  }
};

// Update user (admin)
const updateUser = async (req, res) => {
  try {
    const { password, ...updateData } = req.body;

    if (password) {
      const salt = await bcrypt.genSalt(10);
      updateData.password = await bcrypt.hash(password, salt);
    }

    const updatedUser = await User.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true }
    ).populate('restaurant');

    if (!updatedUser) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.status(200).json({
      message: 'User updated successfully',
      user: updatedUser,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// Delete user
const deleteUser = async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    if (user.role === 'restaurant' && user.restaurant) {
      const restaurant = await Restaurant.findById(user.restaurant);
      if (restaurant) {
        restaurant.owner = null;
        await restaurant.save();
      }
    }

    await User.findByIdAndDelete(req.params.id);
    res.status(200).json({ message: 'User deleted successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

// Login
const login = async (req, res) => {
  try {
    const { mobileNumber, password } = req.body;
    
    console.log('Login attempt for:', mobileNumber);
    
    const user = await User.findOne({ mobileNumber })
      .select('+password')
      .populate('restaurant');
    
    console.log('Found user:', {
      id: user?._id,
      role: user?.role,
      restaurantId: user?.restaurant
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid mobile number or password'
      });
    }

    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      return res.status(401).json({
        success: false,
        message: 'Invalid mobile number or password'
      });
    }

    // Get restaurant data if user is a restaurant owner
    let restaurantData = null;
    if (user.role === 'restaurant') {
      restaurantData = await Restaurant.findOne({ owner: user._id });
      console.log('Found restaurant:', restaurantData?._id);
      
      if (restaurantData && !user.restaurant) {
        user.restaurant = restaurantData._id;
        await user.save();
        console.log('Updated user with restaurant:', user.restaurant);
      }
    }

    const token = jwt.sign(
      { 
        userId: user._id, 
        role: user.role,
        restaurantId: restaurantData?._id
      },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    const response = {
      success: true,
      token,
      user: {
        _id: user._id,
        username: user.username,
        mobileNumber: user.mobileNumber,
        role: user.role,
        address: user.address,
        restaurant: restaurantData ? {
          _id: restaurantData._id,
          name: restaurantData.name,
          address: restaurantData.address,
          isActive: restaurantData.isActive
        } : null
      }
    };

    console.log('Sending response:', {
      role: response.user.role,
      hasRestaurant: !!response.user.restaurant
    });

    res.json(response);
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Error during login',
      error: error.message
    });
  }
};

// Signup
const signup = async (req, res) => {
  try {
    const { username, mobileNumber, password } = req.body;

    const existingUser = await User.findOne({ mobileNumber });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'User already exists with this mobile number'
      });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const user = new User({
      username,
      mobileNumber,
      password: hashedPassword,
      role: 'user'
    });

    await user.save();

    const token = jwt.sign(
      { userId: user._id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '72h' }
    );

    res.status(201).json({
      success: true,
      message: 'User created successfully',
      token,
      user: {
        _id: user._id,
        username: user.username,
        role: user.role,
        mobileNumber: user.mobileNumber
      }
    });
  } catch (error) {
    console.error('Signup error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during registration',
      error: error.message
    });
  }
};

// Existing logout function
const logout = (req, res) => {
  res.status(200).json({ message: 'User logged out' });
};

// Existing assignRole function
const assignRole = async (req, res) => {
  const { userId } = req.params;
  const { role, restaurantId, newRestaurantData } = req.body;

  try {
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    user.role = role;

    if (role === 'restaurant') {
      if (restaurantId) {
        const restaurant = await Restaurant.findById(restaurantId);
        if (!restaurant) {
          return res.status(404).json({ message: 'Restaurant not found' });
        }
        restaurant.owner = user._id;
        await restaurant.save();
        user.restaurant = restaurant._id;
      } else if (newRestaurantData) {
        const restaurant = new Restaurant({
          name: newRestaurantData.name,
          address: newRestaurantData.address,
          owner: user._id,
        });
        await restaurant.save();
        user.restaurant = restaurant._id;
      } else {
        return res.status(400).json({ message: 'Restaurant data is required for restaurant role' });
      }
    }

    await user.save();
    res.status(200).json({ message: 'Role assigned successfully', user });
  } catch (error) {
    console.error('Error assigning role:', {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ message: 'Server error', error });
  }
};

// Existing assignRestaurant function
const assignRestaurant = async (req, res) => {
  const { userId, restaurantId } = req.params;

  try {
    const user = await User.findById(userId);
    const restaurant = await Restaurant.findById(restaurantId);

    if (!user || !restaurant) {
      return res.status(404).json({ message: 'User or Restaurant not found' });
    }

    user.role = 'restaurant';
    restaurant.owner = user._id;
    await user.save();
    await restaurant.save();

    res.status(200).json({ message: 'Restaurant assigned to user successfully', user, restaurant });
  } catch (error) {
    console.error('Error assigning restaurant:', {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ message: 'Server error', error });
  }
};

// Existing getAllRestaurantsByUser function
const getAllRestaurantsByUser = async (req, res) => {
  try {
    const user = await User.findById(req.params.id).populate('restaurants');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.status(200).json(user.restaurants);
  } catch (error) {
    console.error('Error fetching restaurants by user:', {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ message: 'Server error', error });
  }
};

// Existing updateAddress function
const updateAddress = async (req, res) => {
  try {
    const { userId } = req.params;
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
    console.error('Error updating address:', {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

module.exports = {
  getProfile,
  getAllUsers,
  getUserById,
  updateProfile,
  updateUser,
  deleteUser,
  login,
  signup,
  logout,
  assignRole,
  assignRestaurant,
  getAllRestaurantsByUser,
  updateAddress,
  sendOTP,
  verifyOTP
};