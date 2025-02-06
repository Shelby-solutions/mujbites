const Restaurant = require('../models/restaurantModel');
const User = require('../models/user');
const Order = require('../models/orders');

// Helper function to get proper image URL
const getProperImageUrl = (imageUrl) => {
  if (!imageUrl || typeof imageUrl !== 'string') return null;
  if (imageUrl.trim() === '') return null;
  if (imageUrl.startsWith('http')) return imageUrl;
  if (imageUrl.startsWith('assets/')) return null;
  return `${process.env.BASE_URL || 'http://localhost:5000'}/static/images/${imageUrl.replace(/^\/+/, '')}`;
};

// Helper function to calculate time-based score
const getTimeBasedScore = () => {
  const hour = new Date().getHours();
  // Breakfast (6-10), Lunch (11-14), Dinner (18-22)
  if ((hour >= 6 && hour <= 10) || (hour >= 11 && hour <= 14) || (hour >= 18 && hour <= 22)) {
    return 20;
  }
  return 5;
};

// Helper function to calculate mood-based score
const getMoodBasedScore = (mood, category) => {
  const moodCategories = {
    happy: ['desserts', 'pizza', 'burgers', 'party platters'],
    stressed: ['comfort food', 'pasta', 'ice cream', 'chocolate'],
    tired: ['coffee', 'energy drinks', 'healthy bowls', 'smoothies'],
    healthy: ['salads', 'protein bowls', 'grilled', 'vegan'],
    adventurous: ['spicy', 'fusion', 'exotic', 'chef specials'],
    indecisive: ['popular', 'trending', 'staff picks']
  };

  if (!mood || !category) return 0;
  return (moodCategories[mood.toLowerCase()] || []).includes(category.toLowerCase()) ? 35 : 0;
};

exports.getRecommendations = async (req, res) => {
  console.log('Recommendations controller executing', {
    user: req.user,
    query: req.query
  });

  try {
    // Get all active restaurants with their menus
    const restaurants = await Restaurant.aggregate([
      { $match: { isActive: true } },
      { $unwind: '$menu' },
      { $match: { 
        'menu.isAvailable': true,
        'menu.itemName': { $exists: true, $ne: '' }
      }},
      {
        $project: {
          menuItem: {
            _id: '$menu._id',
            name: '$menu.itemName',
            description: '$menu.description',
            imageUrl: '$menu.imageUrl',
            category: '$menu.category',
            sizes: '$menu.sizes',
            isAvailable: '$menu.isAvailable'
          },
          restaurant: {
            _id: '$_id',
            name: '$name',
            address: '$address',
            imageUrl: '$imageUrl',
            isActive: '$isActive',
            rating: '$rating'
          }
        }
      }
    ]);

    console.log(`Found ${restaurants.length} menu items from active restaurants`);

    if (!restaurants || restaurants.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'No menu items found'
      });
    }

    // Get user's order history with timestamps
    const userOrders = await Order.find({
      customer: req.user.userId,
      orderStatus: { $in: ['Delivered', 'Completed'] }
    })
    .sort({ createdAt: -1 })
    .limit(20)
    .lean();

    console.log(`Found ${userOrders.length} previous orders for user`);

    // Get collaborative filtering data
    const similarUsers = await Order.aggregate([
      {
        $match: {
          customer: { $ne: req.user.userId },
          orderStatus: { $in: ['Delivered', 'Completed'] }
        }
      },
      {
        $group: {
          _id: '$customer',
          items: { $push: '$items' }
        }
      }
    ]);

    // Create recommendations with enhanced personalized scores
    const recommendations = restaurants.map(({ menuItem, restaurant }) => {
      let score = 0;

      // Base score components (55% total)
      const timeScore = getTimeBasedScore(); // 20%
      const moodScore = getMoodBasedScore(req.query.mood, menuItem.category); // 35%
      score += timeScore + moodScore;

      // Order history analysis (25%)
      const orderHistory = userOrders.filter(order => 
        order.items.some(item => 
          item.itemName === menuItem.name && 
          order.restaurant.toString() === restaurant._id.toString()
        )
      );

      if (orderHistory.length > 0) {
        // Recency boost
        const mostRecent = new Date(orderHistory[0].createdAt);
        const daysSinceOrder = (Date.now() - mostRecent) / (1000 * 60 * 60 * 24);
        score += Math.max(0, 25 - daysSinceOrder); // Decay over time
      }

      // Collaborative filtering (20%)
      const similarUserOrders = similarUsers.filter(u => 
        u.items.flat().some(item => item.itemName === menuItem.name)
      );
      score += (similarUserOrders.length / similarUsers.length) * 20;

      // Process image URLs
      const itemImageUrl = getProperImageUrl(menuItem.imageUrl);
      const restaurantImageUrl = getProperImageUrl(restaurant.imageUrl);

      // Generate personalized recommendation reason
      let reason = '';
      if (moodScore > 0) {
        reason = `Perfect for your ${req.query.mood} mood`;
      } else if (orderHistory.length > 0) {
        reason = "Based on your order history";
      } else if (similarUserOrders.length > 0) {
        reason = "Popular among similar food lovers";
      } else if (timeScore > 15) {
        reason = "Perfect for this time of day";
      } else {
        reason = "You might want to try this";
      }

      return {
        item: {
          _id: menuItem._id,
          name: menuItem.name,
          description: menuItem.description,
          imageUrl: itemImageUrl,
          category: menuItem.category,
          sizes: menuItem.sizes || {},
          isAvailable: menuItem.isAvailable,
          restaurant: {
            _id: restaurant._id,
            name: restaurant.name,
            address: restaurant.address,
            imageUrl: restaurantImageUrl,
            rating: restaurant.rating
          }
        },
        score,
        reason
      };
    });

    // Sort by score and take top recommendations
    const sortedRecommendations = recommendations
      .sort((a, b) => b.score - a.score)
      .slice(0, 10);

    console.log(`Sending ${sortedRecommendations.length} recommendations`);
    
    return res.json({
      success: true,
      recommendations: sortedRecommendations,
      debug: {
        totalItems: restaurants.length,
        userOrdersCount: userOrders.length,
        timeScore: getTimeBasedScore()
      }
    });

  } catch (error) {
    console.error('Error in recommendations controller:', error);
    return res.status(500).json({
      success: false,
      message: 'Error generating recommendations',
      error: error.message
    });
  }
};
