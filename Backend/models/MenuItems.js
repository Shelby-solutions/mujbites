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
});

const MenuItem = mongoose.model("MenuItem", menuItemSchema);

module.exports = MenuItem;