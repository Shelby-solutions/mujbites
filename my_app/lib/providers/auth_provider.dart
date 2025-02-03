import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';  // Fixed import

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  String? _token;
  String? _userId;
  String? _role;
  String? _restaurantId;

  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  String? get userId => _userId;
  String? get role => _role;
  String? get restaurantId => _restaurantId;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _userId = prefs.getString('userId');
    _role = prefs.getString('role');
    _restaurantId = prefs.getString('restaurantId');
    _isAuthenticated = _token != null;
    notifyListeners();
  }

  Future<void> setAuthData({
    required String token,
    required String userId,
    required String role,
    String? restaurantId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('userId', userId);
    await prefs.setString('role', role);
    if (restaurantId != null) {
      await prefs.setString('restaurantId', restaurantId);
    }

    _token = token;
    _userId = userId;
    _role = role;
    _restaurantId = restaurantId;
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('role');
    await prefs.remove('restaurantId');

    _token = null;
    _userId = null;
    _role = null;
    _restaurantId = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}