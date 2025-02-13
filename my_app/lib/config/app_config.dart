class AppConfig {
  static const String apiBaseUrl = 'http://192.168.1.7:3000';
  static const String wsBaseUrl = 'ws://192.168.1.7:3000';
  
  // WebSocket endpoints
  static const String wsOrdersEndpoint = '/ws/orders';
  
  // Timeouts
  static const Duration wsReconnectDelay = Duration(seconds: 5);
  static const Duration wsConnectionTimeout = Duration(seconds: 10);
  
  // Cache durations
  static const Duration orderCacheValidity = Duration(seconds: 30);
} 