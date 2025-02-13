import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/logger.dart';

class NotificationRateLimiter {
  static final NotificationRateLimiter _instance = NotificationRateLimiter._internal();
  final Logger _logger = Logger();
  final Map<String, int> _rateLimits = {};
  
  static const int _maxNotificationsPerMinute = 60;
  static const String _rateLimitKey = 'notification_rate_limits';
  
  factory NotificationRateLimiter() => _instance;
  NotificationRateLimiter._internal();

  Future<bool> canSendNotification(String userId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final prefs = await SharedPreferences.getInstance();
      
      // Load rate limits from persistent storage
      final storedLimits = prefs.getString(_rateLimitKey);
      if (storedLimits != null) {
        _rateLimits.clear();
        _rateLimits.addAll(Map<String, int>.from(
          Map<String, dynamic>.from(const JsonDecoder().convert(storedLimits))
              .map((key, value) => MapEntry(key, value as int))
        ));
      }

      final userLastNotification = _rateLimits[userId] ?? 0;
      
      if (now - userLastNotification > 60000) { // 1 minute
        _rateLimits[userId] = now;
        
        // Save updated rate limits
        await prefs.setString(_rateLimitKey, 
          const JsonEncoder().convert(_rateLimits));
        
        return true;
      }

      _logger.warning('Rate limit exceeded for user: $userId');
      return false;
    } catch (e) {
      _logger.error('Error in rate limiter', e);
      return true; // Fail open to ensure notifications are delivered
    }
  }

  Future<void> clearRateLimits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_rateLimitKey);
      _rateLimits.clear();
    } catch (e) {
      _logger.error('Error clearing rate limits', e);
    }
  }

  Future<Map<String, int>> getRateLimits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedLimits = prefs.getString(_rateLimitKey);
      if (storedLimits != null) {
        return Map<String, int>.from(
          Map<String, dynamic>.from(const JsonDecoder().convert(storedLimits))
              .map((key, value) => MapEntry(key, value as int))
        );
      }
    } catch (e) {
      _logger.error('Error getting rate limits', e);
    }
    return {};
  }
} 