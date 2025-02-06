const express = require('express');
const router = express.Router();

// Import routes
const userRoutes = require('./userRoutes');
const restaurantRoutes = require('./restaurantRoutes');
const orderRoutes = require('./orders');
const recommendationRoutes = require('./recommendationRoutes');

// Mount routes
router.use('/users', userRoutes);
router.use('/restaurants', restaurantRoutes);
router.use('/orders', orderRoutes);
router.use('/recommendations', recommendationRoutes);

module.exports = router;