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

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  WebSocketChannel? _channel;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  Function(Map<String, dynamic>)? onNewOrder;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request background permissions
    await _requestBackgroundPermissions();

    await _notifications.initialize(
      InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          requestCriticalPermission: true, // For critical notifications
          notificationCategories: [
            DarwinNotificationCategory(
              'order_category',
              actions: [
                DarwinNotificationAction.plain('accept', 'Accept'),
                DarwinNotificationAction.plain('reject', 'Reject'),
              ],
              options: {
                DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
                DarwinNotificationCategoryOption.allowAnnouncement,
              },
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _handleBackgroundNotificationResponse,
    );

    // Set up background message handling
    _setupBackgroundHandler();
    _isInitialized = true;
  }

  Future<void> _requestBackgroundPermissions() async {
    if (Platform.isAndroid) {
      await ph.Permission.notification.request();
      // Request background running permission
      await ph.Permission.ignoreBatteryOptimizations.request();
    }
  }

  void _setupBackgroundHandler() {
    _channel?.stream.listen(
      (message) async {
        final data = jsonDecode(message);
        if (data['type'] == 'newOrder') {
          await showOrderNotification(
            'New Order!',
            'Order #${data['order']['_id'].toString().substring(0, 6)}',
            payload: {'orderData': data['order']},
          );
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
  }

  void _handleNewOrder(Map<String, dynamic> orderData) async {
    await showOrderNotification(
      'New Order Received!',
      'Order #${orderData['_id'].toString().substring(orderData['_id'].toString().length - 6)}',
      payload: {'orderData': orderData},
    );
    onNewOrder?.call(orderData);
  }

  Future<void> showOrderNotification(
    String title,
    String body, {
    Map<String, dynamic>? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'restaurant_orders',
      'Restaurant Orders',
      channelDescription: 'Notifications for new restaurant orders',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      actions: [
        AndroidNotificationAction('accept', 'Accept'),
        AndroidNotificationAction('reject', 'Reject'),
      ],
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_sound.aiff',
      categoryIdentifier: 'order_category',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload != null ? jsonEncode(payload) : null,
    );
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
    final androidDetails = AndroidNotificationDetails(
      'restaurant_orders',
      'Restaurant Orders',
      channelDescription: 'Notifications for new restaurant orders',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_sound.aiff',
      categoryIdentifier: 'order_category',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload != null ? jsonEncode(payload) : null,
    );
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
}