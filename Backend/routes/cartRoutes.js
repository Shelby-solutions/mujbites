const express = require('express');
const router = express.Router();
const auth = require('../middleware/authMiddleware');
const Cart = require('../models/Cart');

router.post('/add', auth, async (req, res) => {
  try {
    const { restaurantId, itemId, quantity, size } = req.body;
    const userId = req.user.id;

    let cart = await Cart.findOne({ user: userId });
    if (!cart) {
      cart = new Cart({ user: userId, items: [] });
    }

    const itemIndex = cart.items.findIndex(item => 
      item.item.toString() === itemId && 
      (!size || item.size === size)
    );

    if (itemIndex > -1) {
      cart.items[itemIndex].quantity += quantity;
    } else {
      cart.items.push({
        item: itemId,
        quantity,
        size,
        restaurant: restaurantId
      });
    }

    await cart.save();
    res.json(cart);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.get('/', auth, async (req, res) => {
  try {
    const cart = await Cart.findOne({ user: req.user.id })
      .populate('items.item')
      .populate('items.restaurant');
    res.json(cart || { items: [] });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;