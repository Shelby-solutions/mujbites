const Restaurant = require("../models/restaurantModel");

/**
 * Create a new restaurant.
 * @param {Object} req - The request object.
 * @param {Object} res - The response object.
 * @returns {Object} - The created restaurant or an error message.
 */
const createRestaurant = async (req, res) => {
  try {
    const restaurant = new Restaurant(req.body);
    await restaurant.save();
    res.status(201).json(restaurant);
  } catch (error) {
    console.error('Error creating restaurant:', {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ message: error.message });
  }
};

/**
 * Get all restaurants.
 * @param {Object} req - The request object.
 * @param {Object} res - The response object.
 * @returns {Object} - A list of restaurants or an error message.
 */
const getAllRestaurants = async (req, res) => {
  try {
    const restaurants = await Restaurant.find();
    res.status(200).json(restaurants);
  } catch (error) {
    console.error('Error fetching all restaurants:', {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ message: error.message });
  }
};

/**
 * Get a single restaurant by ID.
 * @param {Object} req - The request object.
 * @param {Object} res - The response object.
 * @returns {Object} - The restaurant or an error message.
 */
const getRestaurantById = async (req, res) => {
  try {
    const restaurant = await Restaurant.findById(req.params.id)
      .populate("owner")
      .select('-menu.isAvailable -menu.createdAt -menu.updatedAt');

    if (!restaurant) {
      return res.status(404).json({ message: 'Restaurant not found' });
    }

    res.status(200).json(restaurant);
  } catch (error) {
    console.error('Error fetching restaurant by ID:', {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ message: error.message });
  }
};

/**
 * Get a restaurant by owner ID.
 * @param {Object} req - The request object.
 * @param {Object} res - The response object.
 * @returns {Object} - The restaurant or an error message.
 */
const getRestaurantByOwnerId = async (req, res) => {
  try {
    const restaurant = await Restaurant.findOne({ owner: req.params.userId });
    if (!restaurant) {
      return res.status(404).json({ message: 'Restaurant not found for this owner.' });
    }
    res.status(200).json(restaurant);
  } catch (error) {
    console.error('Error fetching restaurant by owner ID:', {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ message: 'Error fetching restaurant by owner', error: error.message });
  }
};

/**
 * Handle a new order received by a restaurant.
 * @param {Object} req - The request object.
 * @param {Object} res - The response object.
 * @returns {Object} - Success or error message.
 */
const handleNewOrderReceived = async (req, res) => {
  const { restaurantId, userAddress } = req.body;

  try {
    // Fetch the restaurant details, including the owner's user ID
    const restaurant = await Restaurant.findById(restaurantId).populate("owner");
    if (!restaurant) {
      return res.status(404).json({ message: 'Restaurant not found' });
    }

    res.status(200).json({
      success: true,
      message: 'Order processed successfully.',
    });
  } catch (error) {
    console.error('Error processing new order:', {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ success: false, error: error.message });
  }
};

module.exports = {
  createRestaurant,
  getAllRestaurants,
  getRestaurantById,
  getRestaurantByOwnerId,
  handleNewOrderReceived,
};