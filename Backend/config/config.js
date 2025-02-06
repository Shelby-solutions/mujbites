// Create a new config file
const config = {
  baseUrl: process.env.BASE_URL || 'http://localhost:5000',
  port: process.env.PORT || 5000,
  mongoUri: process.env.MONGODB_URI,
  jwtSecret: process.env.JWT_SECRET,
  env: process.env.NODE_ENV || 'development',
  corsOrigins: process.env.CORS_ORIGINS ? 
    process.env.CORS_ORIGINS.split(',') : 
    ['http://localhost:3000']
};

module.exports = config; 