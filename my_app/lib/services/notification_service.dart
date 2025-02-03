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
import '../services/user_preferences.dart';
import 'dart:math' as math;  // Add this import

// Add this at the very top of the file, before the class definition
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  print('Handling background notification tap: ${notificationResponse.payload}');
  // Add any background handling logic here
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Add this field
  bool _isConnected = false;
  
  WebSocketChannel? _channel;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  Function(Map<String, dynamic>)? onNewOrder;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request permissions first
      await _requestBackgroundPermissions();  // Add this line
      
      if (Platform.isIOS) {
        await _notifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
              critical: true,
            );
      }

      // Initialize notifications
      await _notifications.initialize(
        InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        ),
        onDidReceiveNotificationResponse: _handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      // Connect to WebSocket for real-time notifications
      await connectToWebSocket();
      
      _isInitialized = true;
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  void _handleNotificationResponse(NotificationResponse details) {
    print('Handling notification response: ${details.payload}');
    if (details.payload != null) {
      try {
        final data = jsonDecode(details.payload!);
        if (data['orderData'] != null) {
          onNewOrder?.call(data['orderData']);
        }
      } catch (e) {
        print('Error processing notification payload: $e');
      }
    }
  }

  // Add this at the top level of the file, outside the class
  @pragma('vm:entry-point')
  void notificationTapBackground(NotificationResponse details) {
    print('Handling background notification tap: ${details.payload}');
    // Handle background notification tap
  }

  Future<void> _requestBackgroundPermissions() async {
    if (Platform.isAndroid) {
      await ph.Permission.notification.request();
      // Request background running permission
      await ph.Permission.ignoreBatteryOptimizations.request();
    }
  }

  // Update in _setupBackgroundHandler
  void _setupBackgroundHandler() {
    _channel?.stream.listen(
      (message) async {
        try {
          final data = jsonDecode(message);
          print('Received WebSocket message: $data');
          
          if (data['type'] == 'newOrder') {
            await _processNewOrder(data['order']);
          } else if (data['type'] == 'orderStatus') {
            // Handle order status updates if needed
            print('Received order status update: ${data['status']}');
          }
        } catch (e) {
          print('Error processing WebSocket message: $e');
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
        _isConnected = false;
        _handleConnectionError();
      },
      onDone: () {
        print('WebSocket connection closed');
        _isConnected = false;
        _handleConnectionError();
      },
    );
  }

  // Remove this duplicate implementation
  void _handleNewOrder(Map<String, dynamic> orderData) async {
    await showOrderNotification(
      'New Order Received!',
      'Order #${orderData['_id'].toString().substring(orderData['_id'].toString().length - 6)}',
      data: {'orderData': orderData}, // Changed 'payload' to 'data'
    );
    onNewOrder?.call(orderData);
  }

  Future<void> showOrderNotification(String title, String message, {Map<String, dynamic>? data}) async {
    const androidDetails = AndroidNotificationDetails(
      'restaurant_orders',
      'Restaurant Orders',
      channelDescription: 'Notifications for new restaurant orders',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.toInt(),
      title,
      message,
      details,
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  // Add connection state management
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;

  // Update the _wsUrl getter
  String get _wsUrl {
    const baseUrl = 'mujbites-app.onrender.com';
    return 'wss://$baseUrl/ws';  // Remove /api prefix as it's not in the backend route
  }

  Future<void> connectToWebSocket() async {
    if (_isConnecting || _reconnectAttempts >= maxReconnectAttempts) {
      print('Skipping connection attempt');
      return;
    }
    
    try {
      _isConnecting = true;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token')?.replaceAll('Bearer ', '');
      final userId = prefs.getString('userId');
      final restaurantId = prefs.getString('restaurantId');
      
      if (token == null || userId == null || restaurantId == null) {
        print('Missing credentials for WebSocket connection');
        return;
      }

      // Create WebSocket URL with query parameters
      final uri = Uri.parse(_wsUrl).replace(
        queryParameters: {
          'token': token,
          'userId': userId,
          'restaurantId': restaurantId,
          'type': 'restaurant',
        },
      );
      
      print('Attempting WebSocket connection to: $uri');
      
      await _channel?.sink.close();
      _channel = WebSocketChannel.connect(uri);
      
      // Add connection timeout
      bool connected = false;
      Timer? timeoutTimer;
      
      timeoutTimer = Timer(const Duration(seconds: 10), () {
        if (!connected) {
          print('WebSocket connection timeout');
          _handleConnectionError();
        }
      });

      try {
        await _channel!.ready;
        connected = true;
        timeoutTimer.cancel();
        
        _isConnected = true;
        _reconnectAttempts = 0;
        print('WebSocket connection established successfully');

        _setupBackgroundHandler();
        
        // Send initial connection message
        _channel?.sink.add(jsonEncode({
          'type': 'connect',
          'role': 'restaurant',
          'restaurantId': restaurantId,
        }));
      } catch (e) {
        print('Error during WebSocket connection setup: $e');
        throw e;
      }
      
    } catch (e) {
      print('WebSocket connection error: $e');
      _isConnected = false;
      _handleConnectionError();
    } finally {
      _isConnecting = false;
    }
  }

  // Update the _processNewOrder method
  Future<void> _processNewOrder(Map<String, dynamic> orderData) async {
    try {
      print('Processing new order notification: ${orderData['_id']}');
      final orderId = orderData['_id']?.toString() ?? '';
      final amount = orderData['totalAmount']?.toString() ?? '0';
      
      // Show notification immediately
      await _notifications.show(
        DateTime.now().millisecond,
        'New Order Received!',
        'Order #${orderId.substring(math.max(0, orderId.length - 6))} - ₹$amount',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'restaurant_orders',
            'Restaurant Orders',
            channelDescription: 'Notifications for new restaurant orders',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.message,
            fullScreenIntent: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'notification_sound.aiff',
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: jsonEncode(orderData),
      );
      
      print('Notification shown for order: ${orderId}');
      onNewOrder?.call(orderData);
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  void _handleConnectionError() {
    if (!_shouldReconnect || _isConnecting) return;
    
    _reconnectAttempts++;
    if (_reconnectAttempts < maxReconnectAttempts) {
      final delay = Duration(seconds: math.min(30, math.pow(2, _reconnectAttempts).toInt()));
      print('Scheduling reconnect attempt ${_reconnectAttempts} in ${delay.inSeconds} seconds');
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () => connectToWebSocket());
    } else {
      print('Max reconnection attempts reached');
      _shouldReconnect = false;
    }
  }

  // Add dispose method
  void dispose() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    if (!_isInitialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'mujbites_channel',
      'MujBites Notifications',
      channelDescription: 'Notifications from MujBites',
      importance: Importance.high,
      priority: Priority.high,
      enableLights: true,
      enableVibration: true,
      playSound: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id ?? math.Random().nextInt(2147483647),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Remove this duplicate _reconnect method
  // Future<void> _reconnect() async {
  //   await Future.delayed(const Duration(seconds: 5));
  //   connectToWebSocket();
  // }

  // Remove the second dispose method that only has _channel?.sink.close()
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
}