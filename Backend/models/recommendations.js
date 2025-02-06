const mongoose = require('mongoose');

const userPreferenceSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  preferences: {
    cuisinePreferences: [String],
    dietaryRestrictions: [String],
    spiceLevel: Number,
    priceRange: {
      min: Number,
      max: Number
    },
    favoriteItems: [{
      type: mongoose.Schema.Types.ObjectId,
      ref: 'MenuItem'
    }],
    moodBasedChoices: Map,
  },
  orderHistory: [{
    itemId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'MenuItem'
    },
    rating: Number,
    timestamp: Date
  }],
  lastMood: {
    mood: String,
    timestamp: Date
  }
});

module.exports = mongoose.model('UserPreference', userPreferenceSchema);