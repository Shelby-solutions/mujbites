import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/notification_model.dart';
import '../utils/encryption_util.dart';
import '../utils/logger.dart';
import '../firebase_options.dart';
import '../utils/notification_rate_limiter.dart';
import '../services/user_preferences.dart';
import 'package:logger/logger.dart' as external_logger;
import '../services/api_service.dart';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:audioplayers/audioplayers.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await WakelockPlus.enable();
    
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    print('Background message received:');
    print('- Message ID: ${message.messageId}');
    print('- Data: ${message.data}');
    print('- Notification: ${message.notification?.title}, ${message.notification?.body}');
    
    if (message.notification != null || message.data.isNotEmpty) {
      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // Handle different notification types
      final notificationType = message.data['type']?.toString().toUpperCase();
      print('Processing background notification type: $notificationType');
      
      // Create platform-specific notification details
      final androidDetails = AndroidNotificationDetails(
        notificationType == 'ORDER_PLACED' ? 'new_orders' : 'order_updates',
        notificationType == 'ORDER_PLACED' ? 'New Orders' : 'Order Updates',
        channelDescription: 'Notifications for new orders and order updates.',
        importance: Importance.max,
        priority: Priority.max,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color.fromARGB(255, 255, 87, 34),
        ledOnMs: 1000,
        ledOffMs: 500,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
        fullScreenIntent: true,
        actions: [
          const AndroidNotificationAction(
            'view_order',
            'View Order',
            showsUserInterface: true,
            cancelNotification: false,
          ),
        ],
      );

      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      
      String title = message.notification?.title ?? 'New Notification';
      String body = message.notification?.body ?? message.data['body'] ?? '';
      
      // Add order amount if available
      if (message.data['totalAmount'] != null) {
        body += ' (₹${message.data['totalAmount']})';
      }
      
      await flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
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
        final player = AudioPlayer();
        await player.play(AssetSource('sounds/new_order.mp3'));
        await Future.delayed(const Duration(seconds: 2));
        player.dispose();
      }

      // Vibrate for high-priority notifications
      if (Platform.isAndroid) {
        HapticFeedback.vibrate();
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

class ReconnectionManager {
  final Logger _logger;
  final Function() onReconnect;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  ReconnectionManager(this._logger, this.onReconnect);

  Future<void> attemptReconnection() async {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logger.warning('Max reconnection attempts reached');
      return;
    }

    final backoffDuration = Duration(seconds: pow(2, _reconnectAttempts).toInt());
    _reconnectAttempts++;

    _logger.info('Attempting to reconnect in ${backoffDuration.inSeconds} seconds');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(backoffDuration, () async {
      try {
        await onReconnect();
        _reconnectAttempts = 0; // Reset attempts on successful connection
      } catch (e) {
        _logger.error('Reconnection attempt failed', e);
        if (_reconnectAttempts < _maxReconnectAttempts) {
          await attemptReconnection();
        }
      }
    });
  }

  void dispose() {
    _reconnectTimer?.cancel();
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final Logger _logger = Logger();
  final Connectivity _connectivity = Connectivity();
  final NotificationRateLimiter _rateLimiter = NotificationRateLimiter();
  late SharedPreferences _prefs;
  bool _initialized = false;
  StreamSubscription? _connectivitySubscription;
  static const int _tokenExpirationDuration = 12 * 60 * 60 * 1000; // 12 hours in milliseconds
  late final ReconnectionManager _reconnectionManager;
  final AudioPlayer _audioPlayer = AudioPlayer();
  static const String _newOrderSound = 'assets/sounds/notification_sound.mp3';
  static bool _initializationInProgress = false;
  static final Int64List _vibrationPatternConst = Int64List.fromList([0, 500, 200, 500]);
  final _apiService = ApiService();

  // Callback functions
  Function(Map<String, dynamic>)? onNewOrder;
  Function(Map<String, dynamic>)? onNewMessage;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal() {
    _reconnectionManager = ReconnectionManager(_logger, () async {
      await initialize();
    });
  }

  bool get isInitialized => _initialized;

  Future<void> ensureInitialized() async {
    if (!_initialized && !_initializationInProgress) {
      await initialize();
    }
  }

  Future<void> initialize() async {
    if (_initialized || _initializationInProgress) return;

    try {
      _initializationInProgress = true;
      _logger.info('Initializing NotificationService');

      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();

      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _logger.info('Firebase initialized');

      // Request notification permissions
      await _requestPermissions();
      
      // Get and update FCM token
      await _initializeFcmToken();

      // Set up notification channels
      await _setupNotificationChannels();

      // Set up message handlers
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Set foreground notification presentation options
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Setup connectivity monitoring
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);

      // Initialize audio player
      await _audioPlayer.setSource(AssetSource('sounds/notification_sound.mp3'));
      _logger.info('Audio player initialized');

      _initialized = true;
      _logger.info('NotificationService initialization completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Error during NotificationService initialization: $e\n$stackTrace');
      rethrow;
    } finally {
      _initializationInProgress = false;
    }
  }

  Future<void> _initializeFcmToken() async {
    try {
      // Get the FCM token
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        _logger.error('Failed to obtain FCM token');
        return;
      }

      _logger.info('FCM Token obtained: ${fcmToken.substring(0, min(10, fcmToken.length))}...');
      
      // Update the token on the server
      await _updateFcmToken(fcmToken);
      
      // Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _logger.info('FCM Token refreshed: ${newToken.substring(0, min(10, newToken.length))}...');
        _updateFcmToken(newToken);
      });
    } catch (e) {
      _logger.error('Error initializing FCM token: $e');
      // Don't rethrow as this is not critical for app functionality
    }
  }

  Future<void> _updateFcmToken(String token) async {
    const maxRetries = 3;
    var retryCount = 0;
    var delay = const Duration(seconds: 2);

    while (retryCount < maxRetries) {
      try {
        if (token.isEmpty) {
          _logger.error('Cannot update FCM token: Token is empty');
          return;
        }

        await _apiService.updateFcmToken(token);
        _logger.info('FCM token updated successfully');
        
        // Save token locally
        await _prefs.setString('fcm_token', token);
        await _prefs.setInt('fcm_token_timestamp', DateTime.now().millisecondsSinceEpoch);
        
        return;
      } catch (e) {
        retryCount++;
        if (retryCount == maxRetries) {
          _logger.error('Failed to update FCM token after $maxRetries attempts: $e');
          return;
        }
        
        _logger.warning('Error updating FCM token (attempt $retryCount): $e');
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }
  }

  Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    if (result == ConnectivityResult.none) {
      _logger.warning('Lost connectivity');
      return;
    }

    _logger.info('Connectivity restored, attempting to reconnect');
    await _reconnectionManager.attemptReconnection();
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _logger.info('Handling foreground message:');
    _logger.info('Message ID: ${message.messageId}');
    _logger.info('Data: ${message.data}');
    _logger.info('Notification: ${message.notification?.title}, ${message.notification?.body}');
    
    try {
      final notificationType = message.data['type']?.toString().toUpperCase();
      _logger.info('Processing notification type: $notificationType');
      
      switch (notificationType) {
        case 'ORDER_PLACED':
          _logger.info('Handling new order notification');
          await _handleNewOrderNotification(message);
          break;
        case 'ORDER_ACCEPTED':
        case 'ORDER_DELIVERED':
        case 'ORDER_CANCELLED':
          _logger.info('Handling order update notification');
          await _handleOrderUpdateNotification(message);
          break;
        default:
          _logger.info('Handling general notification');
          await _handleGeneralNotification(message);
      }

      _handleNotificationData(message.data);
    } catch (e, stackTrace) {
      _logger.error('Error handling foreground message', e, stackTrace);
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    _logger.info('Message opened app: ${message.messageId}');
    _handleNotificationData(message.data);
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    if (data.containsKey('type')) {
      switch (data['type']) {
        case 'order':
          onNewOrder?.call(data);
          break;
        case 'chat':
          onNewMessage?.call(data);
          break;
        default:
          _logger.warning('Unknown notification type: ${data['type']}');
      }
    }
  }

  Future<void> _checkAndRefreshToken() async {
    try {
      final tokenTimestamp = _prefs.getInt('fcm_token_timestamp');
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      if (tokenTimestamp == null || 
          currentTime - tokenTimestamp > _tokenExpirationDuration) {
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _saveToken(token);
          await _prefs.setInt('fcm_token_timestamp', currentTime);
          _logger.info('FCM Token refreshed and saved');
        }
      }
    } catch (e) {
      _logger.error('Error checking/refreshing token', e);
    }
  }

  Future<void> _saveToken(String token) async {
    await _prefs.setString('fcm_token', token);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _prefs.setInt('fcm_token_timestamp', timestamp);
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } else if (Platform.isAndroid) {
      final status = await ph.Permission.notification.request();
      _logger.info('Android notification permission status: $status');
    }
  }

  Future<void> dispose() async {
    _connectivitySubscription?.cancel();
    _reconnectionManager.dispose();
    _audioPlayer.dispose();
  }

  Future<void> subscribeToRestaurantOrders(String restaurantId) async {
    try {
      if (restaurantId.isEmpty) {
        _logger.error('Restaurant ID is empty');
        return;
      }

      // Format the topic name consistently
      final topic = 'restaurant_$restaurantId';
      _logger.info('Attempting to subscribe to topic: $topic');

      // Get current FCM token for debugging
      String? token = await FirebaseMessaging.instance.getToken();
      _logger.info('Current FCM Token: $token');

      // Unsubscribe first to ensure clean subscription
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      await Future.delayed(const Duration(seconds: 1)); // Wait for unsubscribe to complete
      
      // Subscribe to the topic
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      _logger.info('Successfully subscribed to topic: $topic');
      
      // Store subscribed topic
      final topics = await _getSubscribedTopics();
      if (!topics.contains(topic)) {
        topics.add(topic);
        await _prefs.setStringList('subscribed_topics', topics.toList());
      }
      
      // Verify subscription
      final storedTopics = await _getSubscribedTopics();
      _logger.info('Currently subscribed topics: $storedTopics');
      
      if (!storedTopics.contains(topic)) {
        _logger.error('Topic subscription verification failed');
        // Retry subscription
        await FirebaseMessaging.instance.subscribeToTopic(topic);
      }

      // Print debug information
      _logger.info('Subscription details:');
      _logger.info('- Restaurant ID: $restaurantId');
      _logger.info('- Topic: $topic');
      _logger.info('- FCM Token: $token');
      _logger.info('- All Topics: $storedTopics');
    } catch (e, stackTrace) {
      _logger.error('Error subscribing to restaurant notifications', e, stackTrace);
      rethrow;
    }
  }

  Future<Set<String>> _getSubscribedTopics() async {
    final topics = _prefs.getStringList('subscribed_topics') ?? [];
    return topics.toSet();
  }

  Future<String?> getDeviceToken() async {
    return await FirebaseMessaging.instance.getToken();
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
    const maxRetries = 5;
    const initialDelay = Duration(seconds: 1);
    var retryCount = 0;

    Future<void> connect() async {
      try {
        final channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
        
        channel.stream.listen(
          (message) {
            final data = jsonDecode(message);
            if (data['type'] == 'newOrder') {
              _handleNewOrder(data['order']);
            }
          },
          onError: (error) {
            _logger.error('WebSocket error', error);
            _reconnectionManager.attemptReconnection();
          },
          onDone: () {
            _logger.info('WebSocket connection closed');
            _reconnectionManager.attemptReconnection();
          },
        );
      } catch (e) {
        _logger.error('WebSocket connection error', e);
        _reconnectionManager.attemptReconnection();
      }
    }

    Future<void> _attemptReconnection() async {
      if (retryCount < maxRetries) {
        final delay = initialDelay * pow(2, retryCount);
        retryCount++;
        await Future.delayed(delay);
        await connect();
      }
    }

    await connect();
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

  Future<void> _handleNotificationResponse(NotificationResponse response) async {
    if (response.payload != null) {
      try {
        final Map<String, dynamic> data = json.decode(response.payload!);
        _handleNotificationData(data);
      } catch (e, stackTrace) {
        _logger.error('Error handling notification response', e, stackTrace);
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

  Future<bool> checkNotificationPermissions() async {
    if (Platform.isIOS) {
      final settings = await FirebaseMessaging.instance.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } else if (Platform.isAndroid) {
      final status = await ph.Permission.notification.status;
      return status.isGranted;
    }
    return false;
  }

  Future<void> showPermissionDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Notifications'),
        content: const Text(
          'To receive order updates and important information, please enable notifications for this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (Platform.isIOS) {
                await FirebaseMessaging.instance.requestPermission();
              } else if (Platform.isAndroid) {
                await ph.Permission.notification.request();
              }
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBackgroundNotification(
    RemoteMessage message,
  ) async {
    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      await flutterLocalNotificationsPlugin.show(
        notificationId,
        message.notification?.title ?? 'New Notification',
        message.notification?.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: json.encode(message.data),
      );
    } catch (e, stackTrace) {
      _logger.error('Error showing background notification', e, stackTrace);
    }
  }

  Future<void> _showNotification(String title, String body, {Map<String, dynamic>? payload}) async {
    try {
      final androidDetails = _getCachedAndroidDetails('high_importance_channel');
      
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
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
        payload: payload != null ? json.encode(payload) : null,
      );

      if (Platform.isAndroid) {
        unawaited(HapticFeedback.vibrate());
      }
    } catch (e) {
      _logger.error('Error showing notification', e);
    }
  }

  Future<void> _onNotificationTapped(NotificationResponse response) async {
    if (response.payload != null) {
      try {
        final Map<String, dynamic> data = json.decode(response.payload!);
        _handleNotificationData(data);
      } catch (e, stackTrace) {
        _logger.error('Error handling notification response', e, stackTrace);
      }
    }
  }

  Future<void> _setupNotificationChannels() async {
    if (!Platform.isAndroid) return;
    
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
    if (androidPlugin == null) return;

    // Channel for new orders (high priority)
    const newOrdersChannel = AndroidNotificationChannel(
      'new_orders',
      'New Orders',
      description: 'High priority notifications for new incoming orders.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 255, 87, 34),
    );
    
    // Channel for order updates (default priority)
    const orderUpdatesChannel = AndroidNotificationChannel(
      'order_updates',
      'Order Updates',
      description: 'Notifications for order status updates.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    // Create channels one by one
    await androidPlugin.createNotificationChannel(newOrdersChannel);
    await androidPlugin.createNotificationChannel(orderUpdatesChannel);
  }

  // Cache notification settings
  final Map<String, AndroidNotificationDetails> _notificationDetailsCache = {};

  AndroidNotificationDetails _getCachedAndroidDetails(String channelId) {
    return _notificationDetailsCache.putIfAbsent(channelId, () {
      return AndroidNotificationDetails(
        channelId,
        channelId == 'restaurant_orders' ? 'Restaurant Orders' : 'High Importance Notifications',
        channelDescription: channelId == 'restaurant_orders'
          ? 'Notifications for new orders and order updates.'
          : 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        vibrationPattern: _vibrationPatternConst,
        enableLights: true,
        ledColor: const Color.fromARGB(255, 255, 87, 34),
        ledOnMs: 1000,
        ledOffMs: 500,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
        fullScreenIntent: true,
      );
    });
  }

  // Optimize notification display
  Future<void> _showOptimizedNotification({
    required String title,
    required String body,
    required String channelId,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final androidDetails = _getCachedAndroidDetails(channelId);
      
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
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
        payload: payload != null ? json.encode(payload) : null,
      );

      // Optimize vibration for Android
      if (Platform.isAndroid) {
        unawaited(HapticFeedback.vibrate());
      }
    } catch (e, stackTrace) {
      _logger.error('Error showing notification', e, stackTrace);
    }
  }

  // Optimize notification sending with batching
  final Queue<Map<String, dynamic>> _notificationQueue = Queue();
  Timer? _batchTimer;

  void _enqueueBatchNotification(Map<String, dynamic> notification) {
    _notificationQueue.add(notification);
    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 100), _processBatchNotifications);
  }

  Future<void> _processBatchNotifications() async {
    if (_notificationQueue.isEmpty) return;

    final notifications = List<Map<String, dynamic>>.from(_notificationQueue);
    _notificationQueue.clear();

    // Group notifications by type
    final groupedNotifications = groupBy(notifications, (notification) => notification['type']);

    // Process each group
    for (final entry in groupedNotifications.entries) {
      if (entry.value.length == 1) {
        // Single notification
        final notification = entry.value.first;
        await _showOptimizedNotification(
          title: notification['title'],
          body: notification['body'],
          channelId: notification['channelId'],
          payload: notification['payload'],
        );
      } else {
        // Batch notifications
        await _showOptimizedNotification(
          title: 'Multiple ${entry.key} Updates',
          body: 'You have ${entry.value.length} new updates',
          channelId: entry.value.first['channelId'],
          payload: {'type': entry.key, 'count': entry.value.length},
        );
      }
    }
  }

  Future<void> showLocalOrderPlacedNotification(
    String restaurantName,
    double totalAmount,
  ) async {
    try {
      await ensureInitialized();
      
      if (!_initialized) {
        _logger.warning('NotificationService not initialized');
        return;
      }

      final androidDetails = AndroidNotificationDetails(
        'order_placed',
        'Order Placed',
        channelDescription: 'Notifications for placed orders',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        vibrationPattern: _vibrationPatternConst,
        enableLights: true,
        ledColor: const Color.fromARGB(255, 76, 175, 80),
        ledOnMs: 1000,
        ledOffMs: 500,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        category: AndroidNotificationCategory.message,
        fullScreenIntent: true,
      );

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Order Placed Successfully',
        'Your order from $restaurantName for ₹${totalAmount.toStringAsFixed(2)} has been placed.',
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
      );

      // Play sound
      try {
        await playNewOrderSound();
      } catch (soundError) {
        _logger.error('Error playing notification sound', soundError);
      }

      // Vibrate for Android
      if (Platform.isAndroid) {
        try {
          await HapticFeedback.vibrate();
        } catch (vibrationError) {
          _logger.error('Error during vibration', vibrationError);
        }
      }
    } catch (e, stackTrace) {
      _logger.error('Error showing order placed notification', e, stackTrace);
      // Don't rethrow to prevent app crashes
    }
  }

  Future<void> playNewOrderSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification_sound.mp3'));
      if (Platform.isAndroid) {
        await HapticFeedback.vibrate();
      }
    } catch (e) {
      _logger.error('Error playing notification sound', e);
    }
  }

  Future<void> unsubscribeFromRestaurantOrders(String restaurantId) async {
    try {
      if (restaurantId.isEmpty) {
        print('Error: Restaurant ID is empty');
        return;
      }
      
      // Unsubscribe from the restaurant's topic
      await FirebaseMessaging.instance.unsubscribeFromTopic('restaurant_$restaurantId');
      print('Unsubscribed from restaurant orders: $restaurantId');
    } catch (e) {
      print('Error unsubscribing from restaurant orders: $e');
    }
  }

  Future<void> _handleNewOrderNotification(RemoteMessage message) async {
    try {
      final amount = message.data['totalAmount'] ?? '';
      final restaurantName = message.data['restaurantName'] ?? 'Restaurant';
      
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        message.notification?.title ?? 'New Order',
        message.notification?.body ?? 'New order worth ₹$amount received!',
        NotificationDetails(
          android: AndroidNotificationDetails(
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
          ),
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

      // Play sound and vibrate
      await playNewOrderSound();
    } catch (e) {
      _logger.error('Error handling new order notification', e);
    }
  }

  Future<void> _handleOrderUpdateNotification(RemoteMessage message) async {
    try {
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        message.notification?.title ?? 'Order Update',
        message.notification?.body ?? 'Your order status has been updated.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'order_updates',
            'Order Updates',
            channelDescription: 'Notifications for order status updates.',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            vibrationPattern: _vibrationPatternConst,
            enableLights: true,
            ledColor: const Color.fromARGB(255, 76, 175, 80),
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('notification_sound'),
            category: AndroidNotificationCategory.message,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'notification_sound.aiff',
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        payload: json.encode(message.data),
      );
    } catch (e) {
      _logger.error('Error handling order update notification', e);
    }
  }

  Future<void> _handleGeneralNotification(RemoteMessage message) async {
    try {
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        message.notification?.title ?? 'Notification',
        message.notification?.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'general',
            'General Notifications',
            channelDescription: 'General app notifications and updates.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            enableVibration: false,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: false,
            interruptionLevel: InterruptionLevel.passive,
          ),
        ),
        payload: json.encode(message.data),
      );
    } catch (e) {
      _logger.error('Error handling general notification', e);
    }
  }
} 