const User = require('../models/user');
const Restaurant = require('../models/restaurantModel');

const isRestaurantOwner = async (req, res, next) => {
  try {
    // Check if the user is authenticated
    if (!req.user) {
      return res.status(401).json({ 
        success: false, 
        message: 'Unauthorized: User not authenticated' 
      });
    }

    // Fetch the user from the database
    const user = await User.findById(req.user.userId).populate('restaurant');

    // Check if the user exists and has the 'restaurant' role
    if (!user || user.role !== 'restaurant') {
      return res.status(403).json({ message: 'Not authorized as restaurant owner' });
    }

    const restaurant = await Restaurant.findOne({ owner: user._id });

    if (!restaurant) {
      return res.status(404).json({ 
        success: false, 
        message: 'Restaurant not found for this owner' 
      });
    }

    // Attach both user and restaurant to the request object
    req.user = user;
    req.restaurant = restaurant;

    // Proceed to the next middleware or route handler
    next();
  } catch (error) {
    console.error('Error in isRestaurantOwner middleware:', error);
    res.status(500).json({ message: 'Error checking restaurant owner status' });
  }
};

module.exports = isRestaurantOwner;