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
      
      print('\n=== Login Data ===');
      print('User: $user');
      print('Role from response: $role');

      // First monitor call
      print('\nBefore any changes:');
      await UserPreferences.monitorPreferences();

      // Clear all existing data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.commit();
      
      print('\nAfter clear:');
      await UserPreferences.monitorPreferences();

      // Set role first and verify
      print('\nSetting role to: $role');
      final success = await prefs.setString('role', role!);
      print('Set role success: $success');
      final storedRole = prefs.getString('role');
      print('Immediately after setting - stored role: $storedRole');
      
      // Save other data
      await prefs.setString('userId', user['_id'].toString());
      await prefs.setString('token', response['token'].toString());
      await prefs.setBool('isLoggedIn', true);

      if (user['restaurant'] != null) {
        final restaurant = user['restaurant'] as Map<String, dynamic>;
        await prefs.setString('restaurantId', restaurant['_id'].toString());
        await prefs.setString('restaurantName', restaurant['name'].toString());
        await prefs.setBool('restaurantIsActive', restaurant['isActive'] as bool);
      }

      // Force commit all changes
      await prefs.commit();

      print('\nFinal state:');
      await UserPreferences.monitorPreferences();

      // Verify one last time
      final finalRole = prefs.getString('role');
      if (finalRole != role) {
        throw Exception('Role verification failed - Expected: $role, Got: $finalRole');
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