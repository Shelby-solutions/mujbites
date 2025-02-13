import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'user_preferences.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> login(String mobileNumber, String password) async {
    try {
      print('\n=== Starting Login Process ===');
      final response = await _apiService.login(mobileNumber, password);
      
      if (!response['success']) {
        throw Exception(response['message'] ?? 'Login failed');
      }

      final user = response['user'] as Map<String, dynamic>;
      final role = user['role']?.toString();
      final token = response['token'].toString();
      
      print('\n=== Login Data ===');
      print('User: $user');
      print('Role from response: $role');

      // First monitor call
      print('\nBefore saving new data:');
      await UserPreferences.monitorPreferences();

      // Save user data without clearing first
      await UserPreferences.saveUserData(
        userId: user['_id'].toString(),
        token: token,
        role: role!,
        restaurantData: user['restaurant'] as Map<String, dynamic>?,
      );
      
      print('\nAfter saving data:');
      await UserPreferences.monitorPreferences();

      // Verify data was saved correctly
      final prefs = await SharedPreferences.getInstance();
      final storedRole = prefs.getString('role');
      if (storedRole != role) {
        throw Exception('Role verification failed - Expected: $role, Got: $storedRole');
      }

      return response;
    } catch (e, stack) {
      print('Auth service login error: $e');
      print('Stack trace: $stack');
      await UserPreferences.clear();
      rethrow;
    }
  }

  Future<void> _clearCredentials() async {
    await UserPreferences.clear();
  }

  Future<void> logout() async {
    print('\n=== Logging Out ===');
    await UserPreferences.clear();
    print('=== Logout Complete ===\n');
  }
} 