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

  WebSocketChannel? _channel;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  Function(Map<String, dynamic>)? onNewOrder;
  bool _isInitialized = false;
  FirebaseMessaging? _firebaseMessaging;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await Firebase.initializeApp();
    _firebaseMessaging = FirebaseMessaging.instance;

    // Request permissions with proper handling for both platforms
    await _requestNotificationPermissions();
    await _configureNotificationChannels();

    // Get FCM token and print it for debugging
    final token = await _firebaseMessaging?.getToken();
    print('FCM Token: $token');

    // Configure message handling
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle initial message when app is launched from terminated state
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    _isInitialized = true;
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

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    } else if (Platform.isIOS) {
      // Configure iOS notification categories
      final DarwinNotificationDetails iOSPlatformChannelSpecifics = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: 1,
        categoryIdentifier: 'restaurant_orders',
        threadIdentifier: 'restaurant_orders',
      );
      
      // Register the iOS category
      await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true,
          );
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

  void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground message: ${message.data}');
    
    final type = message.data['type'];
    switch(type) {
      case 'new_order':
        _showNotification(
          message.notification?.title ?? 'New Order',
          message.notification?.body ?? 'You have received a new order',
          payload: message.data
        );
        break;
      case 'order_status_update':
        _showNotification(
          message.notification?.title ?? 'Order Update',
          message.notification?.body ?? 'Your order status has been updated',
          payload: message.data
        );
        break;
    }
    
    // Call the callback if set
    onNewOrder?.call(message.data);
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

  Future<void> _showNotification(String title, String body, {Map<String, dynamic>? payload}) async {
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
        fullScreenIntent: true,
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
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      // Generate unique notification ID
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _notifications.show(
        id,
        title,
        body,
        details,
        payload: payload != null ? jsonEncode(payload) : null,
      );

      print('Notification shown successfully: $title');
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  Future<void> _reconnect() async {
    await Future.delayed(const Duration(seconds: 5));
    connectToWebSocket();
  }

  void dispose() {
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

// Add this top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling background message: ${message.data}');
  
  // Show notification even when app is in background
  final notificationService = NotificationService();
  await notificationService.initialize();
  notificationService._showNotification(
    message.notification?.title ?? 'New Order',
    message.notification?.body ?? 'You have received a new order',
      payload: message.data
  );
} 