const mongoose = require('mongoose');

const connectDB = async () => {
    const maxRetries = 3;
    let retryCount = 0;

    while (retryCount < maxRetries) {
        try {
            await mongoose.connect(process.env.MONGO_URI, {
                useNewUrlParser: true,
                useUnifiedTopology: true,
                serverSelectionTimeoutMS: 15000,
                socketTimeoutMS: 45000,
                connectTimeoutMS: 15000,
                maxPoolSize: 50,
                minPoolSize: 10,
                retryWrites: true,
                retryReads: true,
                keepAlive: true,
                keepAliveInitialDelay: 300000
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
            // Wait before retrying
            await new Promise(resolve => setTimeout(resolve, 5000));
        }
    }
};

module.exports = connectDB;
