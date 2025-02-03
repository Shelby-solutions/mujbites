const mongoose = require('mongoose');

const menuItemSchema = new mongoose.Schema({
  itemName: String,
  description: String,
  imageUrl: String,
  category: String,
  isAvailable: { type: Boolean, default: true },
  sizes: {
    type: Map,
    of: Number,
    default: {}
  }
});

const restaurantSchema = new mongoose.Schema({
  name: { type: String, required: true },
  address: { type: String, required: true },
  imageUrl: String,
  isActive: { type: Boolean, default: true },
  menu: [menuItemSchema],
  owner: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  }
}, {
  timestamps: true
});

// Add this pre-save middleware
restaurantSchema.pre('save', async function(next) {
  if (this.isModified('owner')) {
    const user = await mongoose.model('User').findById(this.owner);
    if (user) {
      user.role = 'restaurant';
      user.restaurant = this._id;
      await user.save();
    }
  }
  next();
});

module.exports = mongoose.model('Restaurant', restaurantSchema);