const cron = require('node-cron');
const Restaurant = require('./models/restaurantModel');

// Function to update isActive status based on openingTime
const updateRestaurantStatus = async () => {
  try {
    const now = new Date(); // Get the current date and time

    // Find restaurants where openingTime is less than or equal to the current time
    const restaurants = await Restaurant.find({
      openingTime: { $lte: now }, // Check if openingTime has passed
      isActive: false, // Only update restaurants that are currently closed
    });

    // Update isActive to true for these restaurants
    for (const restaurant of restaurants) {
      restaurant.isActive = true;
      await restaurant.save();
      console.log(`Restaurant ${restaurant.name} is now open.`);
    }
  } catch (error) {
    console.error('Error updating restaurant status:', error);
  }
};

// Schedule the cron job to run every minute
cron.schedule('* * * * *', () => {
  console.log('Running cron job to update restaurant status...');
  updateRestaurantStatus();
});

module.exports = updateRestaurantStatus;