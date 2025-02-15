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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Enable wakelock to ensure processing completes
    await WakelockPlus.enable();
    
    // Initialize Firebase first
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    // Initialize notifications plugin with settings
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // Initialize platform specific settings
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
        const AndroidNotificationChannel(
          'new_orders',
          'New Orders',
          description: 'High priority notifications for new incoming orders.',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: Color.fromARGB(255, 255, 87, 34),
        ),
      );
    }
    
    // Debug logs
    print('Background message received:');
    print('Message ID: ${message.messageId}');
    print('Data: ${message.data}');
    print('Notification: ${message.notification?.title}, ${message.notification?.body}');
    
    if (message.notification != null || message.data.isNotEmpty) {
      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final notificationType = message.data['type']?.toString().toUpperCase();
      
      // Create notification details
      final androidDetails = AndroidNotificationDetails(
        'new_orders',
        'New Orders',
        channelDescription: 'High priority notifications for new incoming orders.',
        importance: Importance.max,
        priority: Priority.max,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
        enableLights: true,
        ledColor: const Color.fromARGB(255, 255, 87, 34),
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        category: AndroidNotificationCategory.message,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
      );

      // Show notification
      await flutterLocalNotificationsPlugin.show(
        notificationId,
        message.notification?.title ?? 'New Order',
        message.notification?.body ?? 'New order received!',
        NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'notification_sound.aiff',
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: json.encode(message.data),
      );

      // Play sound for new orders
      if (notificationType == 'ORDER_PLACED') {
        try {
          final player = AudioPlayer();
          await player.play(AssetSource('sounds/notification_sound.mp3'));
          await Future.delayed(const Duration(seconds: 2));
          await player.dispose();
        } catch (e) {
          print('Error playing notification sound: $e');
        }
      }

      // Vibrate for Android
      if (Platform.isAndroid) {
        try {
          await HapticFeedback.vibrate();
        } catch (e) {
          print('Error during vibration: $e');
        }
      }
    }
  } catch (e, stackTrace) {
    print('Error in background message handler:');
    print('Error: $e');
    print('Stack trace: $stackTrace');
  } finally {
    await WakelockPlus.disable();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final token = prefs.getString('token');
  
  // Load environment variables
  await DefaultFirebaseOptions.loadEnv();
  
  // Initialize Firebase
  final firebaseService = FirebaseService();
  await firebaseService.initialize();
  
  await UserPreferences.init();
  
  // Initialize sqflite database
  final databasesPath = await getDatabasesPath();
  final path = join(databasesPath, 'cache.db');
  await openDatabase(path, version: 1);
  
  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permissions
  if (!kIsWeb) {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Set foreground notification presentation options
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // Initialize NotificationService
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
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
        if (settings.name?.startsWith('/restaurant/') ?? false) {
          final restaurantId = settings.name!.split('/').last;
          return MaterialPageRoute(
            builder: (context) => RestaurantScreen(restaurantId: restaurantId),
          );
        }
        return null;
      },
    );
  }
}
