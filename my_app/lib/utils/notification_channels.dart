import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'dart:typed_data';
import 'logger.dart';

class NotificationChannels {
  static const String newOrdersChannelId = 'new_orders';
  static const String orderUpdatesChannelId = 'order_updates';
  static const String generalChannelId = 'general_notifications';

  static final List<AndroidNotificationChannel> channels = [
    const AndroidNotificationChannel(
      newOrdersChannelId,
      'New Orders',
      description: 'High priority notifications for new incoming orders.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 255, 87, 34),
    ),
    const AndroidNotificationChannel(
      orderUpdatesChannelId,
      'Order Updates',
      description: 'Notifications for order status updates.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 76, 175, 80),
    ),
    const AndroidNotificationChannel(
      generalChannelId,
      'General Notifications',
      description: 'General app notifications.',
      importance: Importance.defaultImportance,
      playSound: false,
    ),
  ];

  static Future<void> createNotificationChannels() async {
    try {
      if (!Platform.isAndroid) return;

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
          FlutterLocalNotificationsPlugin();
      
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          
      if (androidPlugin == null) {
        logger.error('Failed to get Android notification plugin');
        return;
      }

      for (final channel in channels) {
        await androidPlugin.createNotificationChannel(channel);
        logger.info('Created notification channel: ${channel.id}');
      }
    } catch (e, stackTrace) {
      logger.error('Error creating notification channels:', e, stackTrace);
    }
  }

  static AndroidNotificationDetails getAndroidChannelDetails(String type) {
    final channelId = _getChannelIdForType(type);
    return AndroidNotificationDetails(
      channelId,
      _getChannelNameForType(channelId),
      channelDescription: _getChannelDescriptionForType(channelId),
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      enableLights: true,
      ledColor: _getLedColorForType(type),
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('notification_sound'),
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      category: AndroidNotificationCategory.message,
      fullScreenIntent: _shouldShowFullScreenIntent(type),
    );
  }

  static String _getChannelIdForType(String type) {
    switch (type.toUpperCase()) {
      case 'ORDER_PLACED':
      case 'NEW_ORDER':
        return newOrdersChannelId;
      case 'ORDER_CONFIRMED':
      case 'ORDER_READY':
      case 'ORDER_DELIVERED':
      case 'ORDER_CANCELLED':
        return orderUpdatesChannelId;
      default:
        return generalChannelId;
    }
  }

  static String _getChannelNameForType(String channelId) {
    switch (channelId) {
      case newOrdersChannelId:
        return 'New Orders';
      case orderUpdatesChannelId:
        return 'Order Updates';
      default:
        return 'General Notifications';
    }
  }

  static String _getChannelDescriptionForType(String channelId) {
    switch (channelId) {
      case newOrdersChannelId:
        return 'High priority notifications for new incoming orders.';
      case orderUpdatesChannelId:
        return 'Notifications for order status updates.';
      default:
        return 'General app notifications.';
    }
  }

  static Color _getLedColorForType(String type) {
    switch (type.toUpperCase()) {
      case 'ORDER_PLACED':
      case 'NEW_ORDER':
        return const Color.fromARGB(255, 255, 87, 34); // Deep Orange
      case 'ORDER_CONFIRMED':
      case 'ORDER_READY':
        return const Color.fromARGB(255, 76, 175, 80); // Green
      case 'ORDER_DELIVERED':
        return const Color.fromARGB(255, 33, 150, 243); // Blue
      case 'ORDER_CANCELLED':
        return const Color.fromARGB(255, 244, 67, 54); // Red
      default:
        return const Color.fromARGB(255, 158, 158, 158); // Grey
    }
  }

  static bool _shouldShowFullScreenIntent(String type) {
    switch (type.toUpperCase()) {
      case 'ORDER_PLACED':
      case 'NEW_ORDER':
        return true;
      default:
        return false;
    }
  }
} 