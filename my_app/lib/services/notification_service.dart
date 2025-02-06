import 'dart:convert';
import 'dart:io' show Platform;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  WebSocketChannel? _channel;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  Function(Map<String, dynamic>)? onNewOrder;
  bool _isInitialized = false;
  FirebaseMessaging? _firebaseMessaging;

  // Add error tracking
  final List<String> _failedNotifications = [];
  Timer? _retryTimer;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize local notifications first
      await _initializeLocalNotifications();

      // Configure notification channels for Android
      if (Platform.isAndroid) {
        await _configureNotificationChannels();
      }

      // Initialize Firebase with error handling
      await _initializeFirebase();

      // Request permissions with proper handling for both platforms
      await _requestNotificationPermissions();

      _isInitialized = true;
    } catch (e) {
      print('Error initializing notification service: $e');
      // Set initialized to false so we can retry
      _isInitialized = false;
      // Don't rethrow, allow app to continue without notifications
    }
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: _handleBackgroundNotificationResponse,
      );
    } catch (e) {
      print('Error initializing local notifications: $e');
      // Continue without local notifications
    }
  }

  Future<void> _initializeFirebase() async {
    try {
      // Check if Firebase is already initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseMessaging = FirebaseMessaging.instance;

      if (_firebaseMessaging != null) {
        // Configure foreground notification presentation options
        await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // Get FCM token and print it for debugging
        try {
          final token = await _firebaseMessaging?.getToken();
          print('FCM Token: $token');
        } catch (e) {
          print('Error getting FCM token: $e');
        }

        // Configure message handling with error handling
        FirebaseMessaging.onMessage.listen(
          _handleForegroundMessage,
          onError: (error) {
            print('Error handling foreground message: $error');
            _scheduleRetry();
          },
        );

        FirebaseMessaging.onMessageOpenedApp.listen(
          _handleNotificationTap,
          onError: (error) {
            print('Error handling notification tap: $error');
          },
        );

        // Handle initial message when app is launched from terminated state
        try {
          final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
          if (initialMessage != null) {
            _handleNotificationTap(initialMessage);
          }
        } catch (e) {
          print('Error handling initial message: $e');
        }
      }
    } catch (e) {
      print('Error initializing Firebase: $e');
      // Continue without Firebase
    }
  }

  Future<void> _requestNotificationPermissions() async {
    if (!kIsWeb) {
      if (Platform.isIOS) {
        // iOS-specific settings
        await _firebaseMessaging?.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
          criticalAlert: true,
          announcement: true,
          carPlay: true,
        );

        // Enable foreground notifications for iOS
        await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } else if (Platform.isAndroid) {
        // Android-specific settings
        final status = await ph.Permission.notification.request();
        if (status.isGranted) {
          print('Android notification permission granted');
        } else {
          print('Android notification permission denied');
        }
      }
    }
  }

  Future<void> _configureNotificationChannels() async {
    try {
      const androidChannel = AndroidNotificationChannel(
        'restaurant_orders',
        'Restaurant Orders',
        description: 'Notifications for new restaurant orders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    } catch (e) {
      print('Error configuring notification channels: $e');
    }
  }

  Future<void> subscribeToRestaurantOrders(String restaurantId) async {
    await _firebaseMessaging?.subscribeToTopic('restaurant_$restaurantId');
    print('Subscribed to notifications for restaurant: $restaurantId');
  }

  Future<void> unsubscribeFromRestaurantOrders(String restaurantId) async {
    await _firebaseMessaging?.unsubscribeFromTopic('restaurant_$restaurantId');
    print('Unsubscribed from notifications for restaurant: $restaurantId');
  }

  Future<String?> getDeviceToken() async {
    return await _firebaseMessaging?.getToken();
  }

  Future<void> _showNotification(String title, String body, {Map<String, dynamic>? payload}) async {
    int retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        final androidDetails = AndroidNotificationDetails(
          'restaurant_orders',
          'Restaurant Orders',
          channelDescription: 'Notifications for new restaurant orders',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('notification_sound'),
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.public,
        );

        final iOSDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
          badgeNumber: 1,
          categoryIdentifier: 'restaurant_orders',
          threadIdentifier: 'restaurant_orders',
        );

        final details = NotificationDetails(
          android: androidDetails,
          iOS: iOSDetails,
        );

        final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        
        await _notifications.show(
          notificationId,
          title,
          body,
          details,
          payload: payload != null ? jsonEncode(payload) : null,
        );

        print('Notification shown successfully: $title');
        return;
      } catch (e) {
        print('Error showing notification (attempt ${retryCount + 1}): $e');
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(retryDelay * retryCount);
        } else {
          _failedNotifications.add('$title - $body');
          _scheduleRetry();
          rethrow;
        }
      }
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(minutes: 5), _retryFailedNotifications);
  }

  Future<void> _retryFailedNotifications() async {
    if (_failedNotifications.isEmpty) return;

    final notifications = List<String>.from(_failedNotifications);
    _failedNotifications.clear();

    for (final notification in notifications) {
      try {
        final parts = notification.split(' - ');
        await _showNotification(parts[0], parts[1]);
      } catch (e) {
        print('Error retrying notification: $e');
        _failedNotifications.add(notification);
      }
    }
  }

  Future<bool> validateNotificationPayload(Map<String, dynamic> payload) async {
    try {
      final requiredFields = ['type', 'orderId', 'restaurantId'];
      final missingFields = requiredFields.where((field) => !payload.containsKey(field));
      
      if (missingFields.isNotEmpty) {
        print('Missing required fields in payload: $missingFields');
        return false;
      }

      // Validate restaurantId format
      final restaurantId = payload['restaurantId'];
      if (restaurantId == null || restaurantId.toString().isEmpty) {
        print('Invalid restaurantId in payload');
        return false;
      }

      return true;
    } catch (e) {
      print('Error validating notification payload: $e');
      return false;
    }
  }

  void _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.data}');
    
    if (!await validateNotificationPayload(message.data)) {
      print('Invalid notification payload received');
      return;
    }

    final type = message.data['type'];
    try {
      switch(type) {
        case 'new_order':
          await _showNotification(
            message.notification?.title ?? 'New Order',
            message.notification?.body ?? 'You have received a new order',
            payload: message.data
          );
          break;
        case 'order_status_update':
          await _showNotification(
            message.notification?.title ?? 'Order Update',
            message.notification?.body ?? 'Your order status has been updated',
            payload: message.data
          );
          break;
        default:
          print('Unknown notification type: $type');
          break;
      }
      
      onNewOrder?.call(message.data);
    } catch (e) {
      print('Error handling foreground message: $e');
      _scheduleRetry();
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');
    
    final type = message.data['type'];
    final orderId = message.data['orderId'];
    final restaurantId = message.data['restaurantId'];
    
    // Handle navigation based on notification type
    if (type == 'new_order' || type == 'order_status_update') {
      onNewOrder?.call(message.data);
    }
  }

  String get _wsUrl {
    if (kIsWeb) {
      return 'ws://localhost:5000/ws';
    }
    return Platform.isAndroid 
        ? 'ws://10.0.2.2:5000/ws'  // Android emulator
        : 'ws://localhost:5000/ws'; // iOS simulator or web
  }

  Future<void> connectToWebSocket() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      
      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          if (data['type'] == 'newOrder') {
            _handleNewOrder(data['order']);
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _reconnect();
        },
        onDone: () {
          print('WebSocket connection closed');
          _reconnect();
        },
      );
    } catch (e) {
      print('WebSocket connection error: $e');
      _reconnect();
    }
  }

  void _handleNewOrder(Map<String, dynamic> orderData) async {
    // Show local notification
    await _showNotification(
      'New Order Received!',
      'Order #${orderData['_id'].toString().substring(orderData['_id'].toString().length - 6)}',
    );

    // Call the callback if set
    onNewOrder?.call(orderData);
  }

  static void _handleBackgroundNotificationResponse(NotificationResponse details) {
    print('Handling background notification: ${details.payload}');
    // Handle the background notification
  }

  void _handleNotificationResponse(NotificationResponse details) async {
    print('Handling foreground notification: ${details.payload}');
    if (details.payload != null) {
      try {
        final data = jsonDecode(details.payload!);
        onNewOrder?.call(data);
      } catch (e) {
        print('Error parsing notification payload: $e');
      }
    }
  }

  Future<void> _reconnect() async {
    await Future.delayed(const Duration(seconds: 5));
    connectToWebSocket();
  }

  void dispose() {
    _retryTimer?.cancel();
    _channel?.sink.close();
  }

  // Add method to check notification permission status
  Future<bool> checkNotificationPermissions() async {
    if (kIsWeb) return true;

    if (Platform.isAndroid) {
      final status = await ph.Permission.notification.status;
      return status.isGranted;
    } else if (Platform.isIOS) {
      final settings = await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings ?? false;
    }
    return false;
  }

  // Add method to show permission dialog with custom UI
  Future<void> showPermissionDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Enable Notifications',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Would you like to receive notifications for new orders and updates?',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Not Now',
              style: GoogleFonts.montserrat(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context, true);
              if (Platform.isAndroid) {
                await ph.Permission.notification.request();
              } else if (Platform.isIOS) {
                await _notifications
                    .resolvePlatformSpecificImplementation<
                        IOSFlutterLocalNotificationsPlugin>()
                    ?.requestPermissions(
                  alert: true,
                  badge: true,
                  sound: true,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
            ),
            child: Text(
              'Enable',
              style: GoogleFonts.montserrat(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Add debug method
  Future<void> testNotification() async {
    try {
      await _showNotification(
        'Test Notification',
        'This is a test notification',
        payload: {'type': 'test', 'data': 'test_data'},
      );
      print('Test notification sent successfully');
    } catch (e) {
      print('Error sending test notification: $e');
    }
  }
}

// Update the background message handler at the bottom of the file
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Ensure Firebase is initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    print('Handling background message: ${message.data}');

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'restaurant_orders',
        'Restaurant Orders',
        description: 'Notifications for new restaurant orders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }

    // Initialize the notification plugin with platform-specific settings
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    // Show the notification
    await _showBackgroundNotification(flutterLocalNotificationsPlugin, message);
  } catch (e) {
    print('Error in background message handler: $e');
  }
}

Future<void> _showBackgroundNotification(
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
  RemoteMessage message,
) async {
  try {
    final androidDetails = AndroidNotificationDetails(
      'restaurant_orders',
      'Restaurant Orders',
      channelDescription: 'Notifications for new restaurant orders',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('notification_sound'),
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
    );

    final iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
      categoryIdentifier: 'restaurant_orders',
      threadIdentifier: 'restaurant_orders',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    String title;
    String body;

    switch (message.data['type']) {
      case 'new_order':
        title = message.notification?.title ?? 'New Order';
        body = message.notification?.body ?? 'You have received a new order';
        break;
      case 'order_status_update':
        title = message.notification?.title ?? 'Order Update';
        body = message.notification?.body ?? 'Your order status has been updated';
        break;
      default:
        title = message.notification?.title ?? 'New Notification';
        body = message.notification?.body ?? 'You have a new notification';
    }

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      details,
      payload: message.data != null ? jsonEncode(message.data) : null,
    );

    print('Background notification shown successfully');
  } catch (e) {
    print('Error showing background notification: $e');
  }
} 