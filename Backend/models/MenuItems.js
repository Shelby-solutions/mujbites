const mongoose = require("mongoose");

const menuItemSchema = new mongoose.Schema({
  name: { type: String, required: true },
  sizes: {
    Small: { type: Number },
    Medium: { type: Number },
    Large: { type: Number }
  },
  description: { type: String },
  restaurant: { type: mongoose.Schema.Types.ObjectId, ref: "Restaurant", required: true },
  category: {
    type: String,
    required: true
  },
  cuisine: {
    type: String,
    required: true
  },
  imageUrl: {
    type: String,
    default: 'assets/images/placeholder.png'
  }
});

const MenuItem = mongoose.model("MenuItem", menuItemSchema);

module.exports = MenuItem;