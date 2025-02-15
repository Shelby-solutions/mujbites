import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class Logger {
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;

  Logger._internal();

  void info(String message, [Object? data]) {
    _log('INFO', message, data);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log('ERROR', message, error, stackTrace);
  }

  void warning(String message, [Object? data]) {
    _log('WARNING', message, data);
  }

  void debug(String message, [Object? data]) {
    if (kDebugMode) {
      _log('DEBUG', message, data);
    }
  }

  void _log(String level, String message, [Object? data, StackTrace? stackTrace]) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '$timestamp [$level] $message${data != null ? ' - $data' : ''}';

    if (kDebugMode) {
      print(logMessage);
      if (stackTrace != null) {
        print(stackTrace);
      }
    }

    developer.log(
      message,
      time: DateTime.now(),
      level: _getLevelNumber(level),
      error: data,
      stackTrace: stackTrace,
      name: 'MujBites',
    );
  }

  int _getLevelNumber(String level) {
    switch (level) {
      case 'ERROR':
        return 1000;
      case 'WARNING':
        return 900;
      case 'INFO':
        return 800;
      case 'DEBUG':
        return 500;
      default:
        return 0;
    }
  }
}

final logger = Logger(); 