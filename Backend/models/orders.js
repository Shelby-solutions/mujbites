const mongoose = require("mongoose");
const MenuItem = require("./MenuItems"); // Import the MenuItem model

const orderSchema = new mongoose.Schema({
  restaurant: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: "Restaurant", 
    required: true 
  },
  restaurantName: { 
    type: String, 
    required: true 
  },
  customer: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: "User", 
    required: true 
  },
  items: [{
    menuItem: { 
      type: mongoose.Schema.Types.ObjectId, 
      ref: "MenuItem", 
      required: true 
    },
    itemName: { 
      type: String, 
      required: true 
    },
    quantity: { 
      type: Number, 
      required: true,
      min: 1 
    },
    size: { 
      type: String, 
      required: true 
    }
  }],
  totalAmount: { 
    type: Number, 
    required: true,
    min: 0 
  },
  address: { 
    type: String, 
    required: true 
  },
  orderStatus: {
    type: String,
    enum: ["Placed", "Accepted", "Preparing", "Ready", "Delivered", "Cancelled"],
    default: "Placed"
  },
  cancellationReason: { 
    type: String,
    default: ''
  },
  createdAt: { 
    type: Date, 
    default: Date.now 
  },
});

// Method to get the restaurant owner's ID
orderSchema.methods.getRestaurantOwnerId = async function () {
  try {
    const restaurant = await mongoose.model("Restaurant")
      .findById(this.restaurant)
      .populate("owner"); // Populate owner
    if (!restaurant) {
      throw new Error("Restaurant not found"); // Handle case where restaurant is not found
    }
    return restaurant.owner._id; // Return the owner's ID
  } catch (error) {
    console.error("Error fetching restaurant owner:", error);
    throw error;
  }
};

// Pre-save middleware for auto-cancellation after 8 minutes
orderSchema.pre('save', async function (next) {
  if (this.isNew) {
    // Set up auto-cancellation after 8 minutes
    setTimeout(async () => {
      try {
        const order = await mongoose.model('Order').findById(this._id);
        if (order && order.orderStatus === 'Placed') {
          order.orderStatus = 'Cancelled';
          order.cancellationReason = "Your chosen restaurant couldn't take your order this time, but don't worry—we have plenty of other amazing restaurants waiting to serve you. Explore your next favorite meal now!";
          await order.save();
        }
      } catch (error) {
        console.error('Error in auto-cancellation:', error);
      }
    }, 8 * 60 * 1000); // 8 minutes
  }
  next();
});

// Define the model only if it hasn't been defined already
const Order = mongoose.models.Order || mongoose.model("Order", orderSchema);

module.exports = Order;