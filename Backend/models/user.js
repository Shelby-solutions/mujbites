const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

// FCM Token Schema
const fcmTokenSchema = new mongoose.Schema({
  token: {
    type: String,
    required: true
  },
  device: {
    type: String,
    required: true,
    default: 'web'
  },
  lastUsed: {
    type: Date,
    default: Date.now
  }
});

const userSchema = new mongoose.Schema({
  username: {
    type: String,
    required: true,
    trim: true
  },
  mobileNumber: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    minlength: 10,
    maxlength: 10
  },
  password: {
    type: String,
    required: true,
    select: false  // This ensures password isn't returned in queries by default
  },
  role: {
    type: String,
    enum: ['user', 'restaurant', 'admin'],
    default: 'user'
  },
  restaurant: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Restaurant',
    default: null
  },
  fcmTokens: [fcmTokenSchema],
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
  isActive: { type: Boolean, default: true },
  address: { type: String, default: '' },
}, {
  timestamps: true
});

userSchema.index({ 'fcmTokens.token': 1 });

userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  
  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    if (this.isModified('role') && this.role === 'restaurant') {
      const restaurant = await mongoose.model('Restaurant').findOne({ owner: this._id });
      if (restaurant && !this.restaurant) {
        this.restaurant = restaurant._id;
      }
    }
    next();
  } catch (error) {
    next(error);
  }
});

userSchema.methods.comparePassword = async function (candidatePassword) {
  try {
    return await bcrypt.compare(candidatePassword, this.password);
  } catch (error) {
    throw new Error('Password comparison failed');
  }
};

userSchema.methods.toJSON = function () {
  const obj = this.toObject();
  delete obj.password;
  return obj;
};

userSchema.methods.updateFCMToken = async function({ token, device }) {
  // Find existing token
  const existingTokenIndex = this.fcmTokens.findIndex(t => t.token === token);
  
  if (existingTokenIndex !== -1) {
    // Update existing token's lastUsed
    this.fcmTokens[existingTokenIndex].lastUsed = new Date();
  } else {
    // Add new token
    this.fcmTokens.push({
      token,
      device,
      lastUsed: new Date()
    });
    
    // Keep only the 5 most recently used tokens
    if (this.fcmTokens.length > 5) {
      this.fcmTokens.sort((a, b) => b.lastUsed - a.lastUsed);
      this.fcmTokens = this.fcmTokens.slice(0, 5);
    }
  }
  
  await this.save();
  return this;
};

userSchema.methods.getActiveFCMTokens = function() {
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  return this.fcmTokens.filter(token => token.lastUsed > thirtyDaysAgo);
};

userSchema.methods.cleanupOldTokens = async function() {
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const oldLength = this.fcmTokens.length;
  
  this.fcmTokens = this.fcmTokens.filter(token => token.lastUsed > thirtyDaysAgo);
  
  if (oldLength !== this.fcmTokens.length) {
    await this.save();
  }
  
  return {
    userId: this._id,
    removedCount: oldLength - this.fcmTokens.length,
    remainingCount: this.fcmTokens.length
  };
};

userSchema.methods.removeToken = async function(tokenToRemove) {
  this.fcmTokens = this.fcmTokens.filter(t => t.token !== tokenToRemove);
  return this.save();
};

// Static method to clean up old tokens across all users
userSchema.statics.cleanupOldTokens = async function() {
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  
  const users = await this.find({
    'fcmTokens.lastUsed': { $lt: thirtyDaysAgo }
  });
  
  const results = await Promise.all(
    users.map(user => user.cleanupOldTokens())
  );
  
  return {
    usersProcessed: users.length,
    results
  };
};

module.exports = mongoose.model('User', userSchema);