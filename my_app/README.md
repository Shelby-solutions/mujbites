# MujBites App

MujBites is a comprehensive food delivery application designed specifically for the university community. The app provides a seamless experience for ordering food from campus restaurants and managing deliveries. Powered by advanced AI technology, it offers unique features like mood-based food recommendations to enhance the user experience and make dining choices more personalized.

## Features

### User Features
- User authentication with Firebase
- Real-time order tracking
- Push notifications for order updates
- Menu browsing and searching
- Cart management
- Order history
- Multiple payment options
- Restaurant ratings and reviews
- AI-powered mood-based food recommendations
- Smart food suggestions based on past orders
- Contextual menu recommendations
- Dietary preference learning

### Restaurant Features
- Restaurant owner dashboard
- Menu management
- Order management
- Real-time order notifications
- Analytics and reporting

### AI and Machine Learning Features
- Mood-based recommendation engine using Gemini AI
- Personalized learning algorithms
- Smart order pattern analysis
- Contextual awareness for recommendations
- Real-time preference adaptation

### Technical Features
- Cross-platform support (iOS and Android)
- Offline data persistence
- Real-time updates using WebSocket
- Firebase integration for authentication and messaging
- Local notifications
- Secure payment processing
- Location services
- Audio feedback for actions

## Technology Stack

### Mobile App
- Flutter SDK
- Dart programming language
- Firebase services (Auth, Cloud Messaging)
- Local storage with SQLite
- State management with Provider

### Backend
- Node.js
- Express.js
- MongoDB database
- WebSocket for real-time communication
- JWT authentication
- RESTful API architecture
- Gemini AI integration for smart recommendations
- Machine learning pipeline for user preference analysis

## Dependencies

### AI and ML Dependencies
- google_generative_ai: Latest version
- tensorflow_lite: Latest version
- ml_kit: Latest version

### Major Flutter Packages
- firebase_core
- firebase_auth
- firebase_messaging
- provider
- http
- sqflite
- shared_preferences
- path_provider
- url_launcher
- audioplayers
- flutter_local_notifications

### Android Configuration
- Minimum SDK: 23
- Target SDK: 33
- Compile SDK: 35
- Kotlin version: 1.8.10
- Gradle version: 8.1.0

## Setup Instructions

1. Clone the repository
2. Install Flutter SDK
3. Set up Firebase project and add configuration files
4. Install dependencies:
   ```
   flutter pub get
   ```
5. Run the app:
   ```
   flutter run
   ```

## Backend Setup

1. Navigate to Backend directory
2. Install dependencies:
   ```
   npm install
   ```
3. Set up environment variables
4. Start the server:
   ```
   npm start
   ```

## License

All rights reserved. This software is proprietary and confidential. See the LICENSE file for details.

## Contact

For any inquiries or support, please contact the development team.