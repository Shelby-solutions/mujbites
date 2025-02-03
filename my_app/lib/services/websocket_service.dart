import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';  // Add this import
import 'notification_service.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final NotificationService _notificationService = NotificationService();
  bool _isConnected = false;

  static final WebSocketService _instance = WebSocketService._internal();
  
  factory WebSocketService() {
    return _instance;
  }
  
  WebSocketService._internal();

  Future<void> connect() async {
    if (_isConnected) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final restaurantId = prefs.getString('restaurantId');
      final isRestaurant = prefs.getString('role') == 'restaurant';

      if (!isRestaurant || userId == null || restaurantId == null) {
        print('Not a restaurant user or missing credentials');
        return;
      }

      final wsUrl = Uri.parse(
        'wss://mujbites-app.onrender.com/api/ws'  // Changed back to wss:// and added /api prefix
      ).replace(
        queryParameters: {
          'userId': userId,
          'restaurantId': restaurantId,
          'token': prefs.getString('token')?.replaceAll('Bearer ', ''), // Add token for authentication
        },
      );

      print('Attempting to connect to WebSocket: $wsUrl');
      
      await _channel?.sink.close();
      _channel = WebSocketChannel.connect(wsUrl);
      
      bool connected = false;
      Timer(const Duration(seconds: 30), () {
        if (!connected) {
          print('WebSocket connection timeout');
          _reconnect();
        }
      });

      await _channel!.ready;  // Wait for connection to be established
      connected = true;
      _isConnected = true;
      print('WebSocket connection established successfully');

      _channel!.stream.listen(
        (message) async {
          final data = jsonDecode(message);
          if (data['type'] == 'newOrder') {
            final orderData = data['order'] as Map<String, dynamic>;
            await _notificationService.showOrderNotification(
              'New Order!',
              'You have received a new order. Tap to view details.',
              data: orderData,
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
    } catch (e) {
      print('WebSocket connection error: $e');
      _isConnected = false;
      Future.delayed(const Duration(seconds: 5), _reconnect);
    }
  }

  void _reconnect() {
    if (!_isConnected) return;
    _isConnected = false;
    Future.delayed(const Duration(seconds: 5), connect);
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
  }
}