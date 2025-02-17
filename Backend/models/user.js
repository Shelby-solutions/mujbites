const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

const deviceSchema = new mongoose.Schema({
  fcmToken: {
    type: String,
    required: true
  },
  deviceType: {
    type: String,
    enum: ['android', 'ios', 'web', 'unknown'],
    default: 'unknown'
  },
  deviceInfo: {
    type: Map,
    of: String,
    default: new Map()
  },
  lastActive: {
    type: Date,
    default: Date.now
  },
  expiresAt: {
    type: Date,
    default: () => new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days from now
  }
}, { _id: false });

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
  devices: {
    type: [deviceSchema],
    default: []
  },
  fcmToken: {
    type: String,
    default: null,
    sparse: true,
    deprecated: true
  },
  deviceType: {
    type: String,
    enum: ['android', 'ios', 'web', 'unknown'],
    default: 'unknown',
    deprecated: true
  },
  appVersion: {
    type: String,
    default: '1.0.0'
  },
  lastTokenUpdate: {
    type: Date,
    default: null,
    deprecated: true
  },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
  isActive: { type: Boolean, default: true },
  address: { type: String, default: '' },
}, {
  timestamps: true
});

userSchema.index({ 'devices.fcmToken': 1 });

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
    if (this.fcmToken && !this.devices.some(d => d.fcmToken === this.fcmToken)) {
      this.devices.push({
        fcmToken: this.fcmToken,
        deviceType: this.deviceType || 'unknown',
        deviceInfo: new Map([['migrated', 'true']]),
        lastActive: this.lastTokenUpdate || new Date()
      });
      this.fcmToken = null;
      this.deviceType = 'unknown';
      this.lastTokenUpdate = null;
    }
    if (this.isModified('devices')) {
      const now = new Date();
      this.devices = this.devices.filter(device => device.expiresAt > now);
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
  if (obj.devices) {
    obj.devices = obj.devices.map(device => ({
      ...device,
      deviceInfo: Object.fromEntries(device.deviceInfo)
    }));
  }
  return obj;
};

userSchema.methods.updateDevice = async function(deviceData) {
  const { fcmToken, deviceType, deviceInfo } = deviceData;
  
  // Remove expired tokens first
  this.devices = this.devices.filter(device => {
    return device.expiresAt > new Date() || !device.expiresAt;
  });
  
  const existingDeviceIndex = this.devices.findIndex(d => d.fcmToken === fcmToken);
  
  if (existingDeviceIndex >= 0) {
    // Update existing device
    this.devices[existingDeviceIndex] = {
      ...this.devices[existingDeviceIndex],
      deviceType: deviceType || this.devices[existingDeviceIndex].deviceType,
      deviceInfo: new Map([
        ...this.devices[existingDeviceIndex].deviceInfo,
        ...(deviceInfo || {})
      ]),
      lastActive: new Date(),
      expiresAt: deviceInfo?.expiresAt ? new Date(deviceInfo.expiresAt) : 
                 new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days from now
    };
  } else {
    // Add new device
    this.devices.push({
      fcmToken,
      deviceType: deviceType || 'unknown',
      deviceInfo: new Map(Object.entries(deviceInfo || {})),
      lastActive: new Date(),
      expiresAt: deviceInfo?.expiresAt ? new Date(deviceInfo.expiresAt) : 
                 new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days from now
    });
  }

  // Keep only the 5 most recently active devices
  if (this.devices.length > 5) {
    this.devices.sort((a, b) => b.lastActive - a.lastActive);
    this.devices = this.devices.slice(0, 5);
  }

  return this.save();
};

userSchema.methods.getActiveFCMTokens = function() {
  const now = new Date();
  return this.devices
    .filter(device => device.expiresAt > now)
    .map(device => device.fcmToken);
};

userSchema.methods.removeExpiredTokens = async function() {
  const now = new Date();
  const originalCount = this.devices.length;
  
  this.devices = this.devices.filter(device => device.expiresAt > now);
  
  if (this.devices.length < originalCount) {
    return this.save();
  }
  return this;
};

// Add a static method to clean up expired tokens across all users
userSchema.statics.cleanupExpiredTokens = async function() {
  const now = new Date();
  const result = await this.updateMany(
    { 'devices.expiresAt': { $lt: now } },
    { $pull: { devices: { expiresAt: { $lt: now } } } }
  );
  return result;
};

userSchema.methods.removeToken = async function(token) {
  this.devices = this.devices.filter(device => device.fcmToken !== token);
  return this.save();
};

module.exports = mongoose.model('User', userSchema);