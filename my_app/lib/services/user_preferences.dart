import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const String _roleKey = 'role';
  static const String _tokenKey = 'token';
  static const String _userIdKey = 'userId';
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _restaurantIdKey = 'restaurantId';
  static const String _restaurantNameKey = 'restaurantName';
  static const String _restaurantActiveKey = 'restaurantIsActive';

  static Future<void> clear() async {
    print('\n=== UserPreferences.clear ===');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    // Verify clear
    final role = prefs.getString(_roleKey);
    final isLoggedIn = prefs.getBool(_isLoggedInKey);
    print('After clear - role: $role, isLoggedIn: $isLoggedIn');
    print('=== Clear Complete ===\n');
  }

  static Future<void> saveUserData({
    required String userId,
    required String token,
    required String role,
    Map<String, dynamic>? restaurantData,
  }) async {
    print('\n=== UserPreferences.saveUserData ===');
    print('Role to save: $role');
    print('UserId to save: $userId');
    print('Has restaurant data: ${restaurantData != null}');
    
    final prefs = await SharedPreferences.getInstance();
    
    // Clear existing data first
    await prefs.clear();
    await prefs.commit();
    
    // Save and verify each field individually
    await prefs.setString(_roleKey, role);
    final verifyRole = prefs.getString(_roleKey);
    print('Role - Expected: $role, Actual: $verifyRole');
    
    await prefs.setString(_userIdKey, userId);
    final verifyUserId = prefs.getString(_userIdKey);
    print('UserId - Expected: $userId, Actual: $verifyUserId');
    
    await prefs.setString(_tokenKey, token);
    await prefs.setBool(_isLoggedInKey, true);
    
    if (restaurantData != null) {
      await prefs.setString(_restaurantIdKey, restaurantData['_id'].toString());
      await prefs.setString(_restaurantNameKey, restaurantData['name'].toString());
      await prefs.setBool(_restaurantActiveKey, restaurantData['isActive'] as bool);
    }
    
    await prefs.commit();
    
    // Final verification
    final finalRole = prefs.getString(_roleKey);
    if (finalRole != role) {
      throw Exception('Role verification failed - Expected: $role, Got: $finalRole');
    }
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(_roleKey);
    print('\n=== UserPreferences.getRole ===');
    print('Raw stored role: $role');
    
    // Get all keys and values for debugging
    final keys = prefs.getKeys();
    print('All stored preferences:');
    for (var key in keys) {
      print('$key: ${prefs.get(key)}');
    }
    
    print('=== End getRole ===\n');
    return role;
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    print('UserPreferences.isLoggedIn() returning: $isLoggedIn');
    return isLoggedIn;
  }

  // Add a debug method
  static Future<void> debugPrintAll() async {
    final prefs = await SharedPreferences.getInstance();
    print('\nCurrent SharedPreferences state:');
    print('Role: ${prefs.getString(_roleKey)}');
    print('UserId: ${prefs.getString(_userIdKey)}');
    print('Token: ${prefs.getString(_tokenKey)}');
    print('IsLoggedIn: ${prefs.getBool(_isLoggedInKey)}');
    print('RestaurantId: ${prefs.getString(_restaurantIdKey)}');
    print('RestaurantName: ${prefs.getString(_restaurantNameKey)}\n');
  }

  static Future<void> init() async {
    print('\n=== Initializing UserPreferences ===');
    final prefs = await SharedPreferences.getInstance();
    
    // Debug current state before clear
    final beforeClear = prefs.getKeys();
    print('Before clear - stored keys:');
    for (var key in beforeClear) {
      print('$key: ${prefs.get(key)}');
    }
    
    await prefs.clear();
    await prefs.commit();
    
    // Verify clear worked
    final afterClear = prefs.getKeys();
    print('After clear - stored keys: ${afterClear.length}');
    print('=== UserPreferences Initialized ===\n');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> monitorPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(_roleKey);
    final userId = prefs.getString(_userIdKey);
    final isLoggedIn = prefs.getBool(_isLoggedInKey);
    
    print('\n=== SharedPreferences Monitor ===');
    print('Stack trace:');
    try { throw Exception(); } catch (e, stack) { print(stack); }
    print('Current values:');
    print('Role: $role');
    print('UserId: $userId');
    print('IsLoggedIn: $isLoggedIn');
    print('=== End Monitor ===\n');
  }

  static Future<void> _logAccess(String operation, String key, dynamic value) async {
    print('\n=== SharedPreferences Access ===');
    print('Operation: $operation');
    print('Key: $key');
    print('Value: $value');
    try { throw Exception(); } catch (e, stack) { 
      print('Stack trace:');
      print(stack); 
    }
    print('=== End Access ===\n');
  }

  static Future<bool> setString(String key, String value) async {
    await _logAccess('setString', key, value);
    final prefs = await SharedPreferences.getInstance();
    final result = await prefs.setString(key, value);
    return result;
  }

  static Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key);
    await _logAccess('getString', key, value);
    return value;
  }
} 