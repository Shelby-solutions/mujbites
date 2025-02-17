import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/restaurant_screen.dart';
import 'screens/restaurant_panel_screen.dart';
import 'screens/recommendations_screen.dart';
import 'theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'providers/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/custom_navbar.dart';
import 'services/user_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'services/firebase_service.dart';
import 'utils/logger.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Keep device awake while processing notification
    await WakelockPlus.enable();
    
    // Initialize Firebase
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    logger.info('Background message received:', {
      'messageId': message.messageId,
      'data': message.data,
      'notification': '${message.notification?.title}, ${message.notification?.body}'
    });

    // Process the notification using NotificationService
    final notificationService = NotificationService();
    await notificationService.initialize();
    await notificationService.showBackgroundNotification(message);

  } catch (e, stackTrace) {
    logger.error('Error in background message handler:', e, stackTrace);
  } finally {
    await WakelockPlus.disable();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('Starting app initialization...');
    
    // Initialize Firebase
    print('Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');

    // Set up notification channels before initializing the service
    if (Platform.isAndroid) {
      print('Setting up Android notification channels...');
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      
      const androidChannel = AndroidNotificationChannel(
          'new_orders',
          'New Orders',
          description: 'High priority notifications for new incoming orders.',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: Color.fromARGB(255, 255, 87, 34),
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
          
      print('Android notification channel created successfully');
    }

    // Initialize notification service
    print('Initializing notification service...');
    final notificationService = NotificationService();
    await notificationService.initialize();
    print('Notification service initialized successfully');

    // Set up foreground message handler
    print('Setting up foreground message handler...');
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('Foreground message received:');
      print('- Message ID: ${message.messageId}');
      print('- Data: ${message.data}');
      print('- Notification: ${message.notification?.title}, ${message.notification?.body}');

      await notificationService.handleForegroundMessage(message);
    });

    // Set up background message handler
    print('Setting up background message handler...');
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification open events
    print('Setting up notification open handler...');
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from notification:');
      print('- Message ID: ${message.messageId}');
      print('- Data: ${message.data}');

      // Handle navigation based on notification type
      if (message.data['type'] == 'ORDER_PLACED' || message.data['type'] == 'NEW_ORDER') {
        final orderId = message.data['orderId'];
        if (orderId != null) {
          print('Navigating to order details for order: $orderId');
          // Navigator.pushNamed(context, '/orders/$orderId');
        }
      }
    });

    // Request notification permissions
    if (!kIsWeb) {
      print('Requesting notification permissions...');
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true,
      );
      
      print('Notification permission status:');
      print('- Authorization Status: ${settings.authorizationStatus}');
      print('- Alert: ${settings.alert}');
      print('- Sound: ${settings.sound}');
      print('- Badge: ${settings.badge}');
    }

    print('App initialization completed successfully');
  } catch (e, stackTrace) {
    print('Error initializing app:');
    print('Error: $e');
    print('Stack trace: $stackTrace');
  }

  print('Loading user preferences...');
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final token = prefs.getString('token');
  print('User logged in: $isLoggedIn');
  
  // Initialize other services
  print('Initializing user preferences...');
  await UserPreferences.init();
  print('User preferences initialized');
  
  // Initialize sqflite database
  print('Initializing local database...');
  final databasesPath = await getDatabasesPath();
  final path = join(databasesPath, 'cache.db');
  await openDatabase(path, version: 1);
  print('Local database initialized');

  print('Starting app with initial route: ${isLoggedIn && token != null ? '/home' : '/login'}');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        Provider<NotificationService>.value(
          value: NotificationService(),
        ),
      ],
      child: MyApp(initialRoute: isLoggedIn && token != null ? '/home' : '/login'),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MujBites',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primary),
        useMaterial3: true,
        textTheme: TextTheme(
          displayLarge: AppTheme.textTheme.displayLarge,
          displayMedium: AppTheme.textTheme.displayMedium,
          bodyLarge: AppTheme.textTheme.bodyLarge,
          titleLarge: AppTheme.textTheme.titleLarge,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: AppTheme.primaryButton,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            borderSide: const BorderSide(color: AppTheme.textPrimary, width: 2),
          ),
        ),
      ),
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const HomeScreen(),
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/orders': (context) => const OrdersScreen(),
        '/restaurant-panel': (context) => const RestaurantPanelScreen(),
        '/recommendations': (context) => const RecommendationsScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle dynamic routes
        final uri = Uri.parse(settings.name ?? '');
        
        if (uri.pathSegments.first == 'restaurant') {
          final restaurantId = uri.pathSegments.last;
          return MaterialPageRoute(
            builder: (context) => RestaurantScreen(restaurantId: restaurantId),
          );
        } else if (uri.pathSegments.first == 'orders' && uri.pathSegments.length > 1) {
          final orderId = uri.pathSegments.last;
          return MaterialPageRoute(
            builder: (context) => OrdersScreen(initialOrderId: orderId),
          );
        }
        return null;
      },
      navigatorKey: GlobalKey<NavigatorState>(),
    );
  }
}
