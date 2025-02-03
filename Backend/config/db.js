const mongoose = require('mongoose');

const connectDB = async () => {
    const maxRetries = 5;  // Increased max retries
    let retryCount = 0;

    while (retryCount < maxRetries) {
        try {
            await mongoose.connect(process.env.MONGO_URI, {
                useNewUrlParser: true,
                useUnifiedTopology: true,
                serverSelectionTimeoutMS: 30000,  // Increased to 30 seconds
                socketTimeoutMS: 60000,  // Increased to 60 seconds
                connectTimeoutMS: 30000,  // Increased to 30 seconds
                maxPoolSize: 100,  // Increased pool size
                minPoolSize: 20,   // Increased minimum pool
                retryWrites: true,
                retryReads: true,
                keepAlive: true,
                keepAliveInitialDelay: 300000,
                autoIndex: true,
                heartbeatFrequencyMS: 10000
            });
            console.log('MongoDB Connected...');
            break;
        } catch (error) {
            retryCount++;
            console.error(`MongoDB connection attempt ${retryCount} failed:`, error.message);
            if (retryCount === maxRetries) {
                console.error('All connection attempts failed');
                process.exit(1);
            }
            // Exponential backoff for retries
            const waitTime = Math.min(1000 * Math.pow(2, retryCount), 10000);
            await new Promise(resolve => setTimeout(resolve, waitTime));
        }
    }
};

module.exports = connectDB;
