import 'dart:convert';
import 'dart:io';
import 'dart:async';  // Add this import for TimeoutException
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:my_app/services/user_preferences.dart';

class ApiService {
  static const bool useProductionUrl = true; // Toggle this for development/production

  static String get baseUrl {
    if (useProductionUrl) {
      return 'https://mujbites-app.onrender.com/api';
    }
    
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    return Platform.isAndroid 
        ? 'http://10.0.2.2:5000/api'  // Android emulator uses 10.0.2.2 to access localhost
        : 'http://localhost:5000/api'; // iOS simulator or web
  }
  
  // For debugging
  static Uri getUri(String path) {
    final uri = Uri.parse('$baseUrl$path');
    print('Making request to: $uri');
    return uri;
  }

  Future<Map<String, String>> getHeaders([String? token]) async {
    if (token == null) {
      token = await UserPreferences.getToken();
    }
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> _authenticatedRequest(String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    try {
      final headers = await getHeaders();
      final uri = getUri(path);
      
      http.Response response;
      
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'POST':
          response = await http.post(uri, headers: headers, body: jsonEncode(body));
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers, body: jsonEncode(body));
          break;
        default:
          throw Exception('Unsupported method: $method');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('API request error: $e');
      rethrow;
    }
  }

  // Authentication Methods
  Future<Map<String, dynamic>> register(String username, String mobileNumber, String password) async {
    try {
      final headers = await getHeaders();
      final body = {
        'username': username,
        'mobileNumber': mobileNumber,
        'password': password,
      };

      print('Making registration request...');
      print('Headers: $headers');
      print('Body: $body');

      final response = await http.post(
        getUri('/users/register'),
        headers: headers,
        body: jsonEncode(body),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login(String mobileNumber, String password) async {
    try {
      print('\n=== API Login Request ===');
      print('Mobile: $mobileNumber');
      
      final response = await http.post(
        getUri('/users/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mobileNumber': mobileNumber,
          'password': password,
        }),
      );

      print('Response status: ${response.statusCode}');
      final responseData = jsonDecode(response.body);
      print('Response data: $responseData');

      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception('Login failed');
      }
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  // Restaurant Methods
  Future<List<Map<String, dynamic>>> getAllRestaurants() async {
    try {
      final response = await http.get(
        getUri('/restaurants'),
        headers: await getHeaders(),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load restaurants: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getRestaurantById(String id) async {
    try {
      final response = await http.get(
        getUri('/restaurants/$id'),
        headers: await getHeaders(),
      );

      print('API Response Status: ${response.statusCode}'); // Debug print
      print('API Response Body: ${response.body}'); // Debug print

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['menu'] == null) {
          // Ensure menu is at least an empty list if null
          data['menu'] = [];
        } else if (data['menu'] is Map) {
          // If menu is a single item (Map), convert to List
          data['menu'] = [data['menu']];
        }
        return data;
      } else {
        throw Exception('Failed to load restaurant details');
      }
    } catch (e) {
      print('API Error: $e'); // Debug print
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getRestaurantMenu(String restaurantId) async {
    try {
      final response = await http.get(
        getUri('/restaurants/$restaurantId/menu'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load menu');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Order Methods
  // Update the createOrder method
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    try {
      print('Creating order with data: $orderData');
      final response = await http.post(
        getUri('/orders'), // Changed from /api/orders to /orders
        headers: await getHeaders(),
        body: jsonEncode(orderData),
      );
  
      print('Order creation response: ${response.statusCode}');
      print('Response body: ${response.body}');
  
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create order: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserOrders() async {
    final response = await _authenticatedRequest('/orders');
    return List<Map<String, dynamic>>.from(response['orders'] ?? []);
  }

  // Profile Methods
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await _authenticatedRequest('/users/profile');
      print('Profile Response: $response'); // Debug log
      
      if (response == null) {
        throw Exception('No profile data received');
      }
      
      // The backend returns the user object directly with populated restaurant field
      return response;
    } catch (e) {
      print('Error fetching profile: $e');
      rethrow;
    }
  }

  Future<void> updateProfile({
    required String address,
    String? oldPassword,
    String? newPassword,
  }) async {
    try {
      final Map<String, dynamic> body = {
        if (address.isNotEmpty) 'address': address,
        if (oldPassword != null) 'oldPassword': oldPassword,
        if (newPassword != null) 'newPassword': newPassword,
      };

      await _authenticatedRequest(
        '/users/profile/update',
        method: 'PUT',
        body: body,
      );
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  // Cart Methods
  Future<void> addToCart(String restaurantId, String itemId, int quantity, {String? size}) async {
    try {
      final response = await http.post(
        getUri('/cart/add'),
        headers: await getHeaders(),
        body: jsonEncode({
          'restaurantId': restaurantId,
          'itemId': itemId,
          'quantity': quantity,
          if (size != null) 'size': size,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to add item to cart');
      }
    } catch (e) {
      print('Error adding to cart: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCart() async {
    try {
      final response = await http.get(
        getUri('/cart'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load cart');
      }
    } catch (e) {
      print('Error fetching cart: $e');
      rethrow;
    }
  }

  // Restaurant owner specific methods
  Future<Map<String, dynamic>> getRestaurantByOwnerId() async {
    try {
      print('Fetching restaurant data for owner');
      final userId = await UserPreferences.getString('userId');
      
      final response = await http.get(
        getUri('/restaurants/byOwner/$userId'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch restaurant data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching restaurant data: $e');
      rethrow;
    }
  }

  Future<String?> _getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final token = prefs.getString('token');
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      
      print('Getting user ID:');
      print('- Retrieved user ID: $userId');
      print('- Has token: ${token != null}');
      print('- Is logged in: $isLoggedIn');
      
      if (!isLoggedIn || userId == null || userId.isEmpty || token == null) {
        print('Invalid credentials found - clearing preferences');
        await prefs.clear();
        throw Exception('Invalid credentials - please login again');
      }
      return userId;
    } catch (e) {
      print('Error getting user ID: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getRestaurantOrders(String restaurantId) async {
    try {
      final response = await http.get(
        getUri('/restaurants/$restaurantId/orders'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch orders: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching restaurant orders: $e');
      rethrow;
    }
  }

  Future<void> updateOrderStatus(String orderId, String status, [String? reason]) async {
    try {
      final body = {
        'status': status,
        if (reason != null) 'cancellationReason': reason,
      };
      
      final response = await http.put(
        getUri('/restaurants/orders/$orderId'),
        headers: await getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update order status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating order status: $e');
      rethrow;
    }
  }

  Future<bool> isRestaurantOwner() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role');
      return role == 'restaurant';
    } catch (e) {
      print('Error checking restaurant owner status: $e');
      return false;
    }
  }

  Future<bool> verifyStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final token = prefs.getString('token');
      final role = prefs.getString('role');
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      print('Verifying stored credentials:');
      print('- userId: "${userId ?? ''}"');
      print('- token exists: ${token != null}');
      print('- token length: ${token?.length ?? 0}');
      print('- role: "${role ?? ''}"');
      print('- isLoggedIn: $isLoggedIn');

      // Check each credential individually
      if (!isLoggedIn) {
        print('Not logged in');
        return false;
      }
      if (userId == null || userId.isEmpty) {
        print('Missing or empty userId');
        return false;
      }
      if (token == null || token.isEmpty) {
        print('Missing or empty token');
        return false;
      }
      if (role == null || role.isEmpty) {
        print('Missing or empty role');
        return false;
      }

      // Validate userId format (MongoDB ObjectId format)
      if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(userId)) {
        print('Invalid userId format: $userId');
        return false;
      }

      print('All credentials verified successfully');
      return true;
    } catch (e) {
      print('Error verifying credentials: $e');
      return false;
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final token = prefs.getString('token');
      final role = prefs.getString('role');
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      print('Checking login status:');
      print('- isLoggedIn flag: $isLoggedIn');
      print('- userId: "${userId ?? ''}"');
      print('- token length: ${token?.length ?? 0}');
      print('- role: "${role ?? ''}"');

      if (!isLoggedIn) {
        print('Not logged in according to flag');
        return false;
      }

      if (userId?.isEmpty ?? true) {
        print('Empty or null userId');
        await prefs.clear();
        return false;
      }

      if (token?.isEmpty ?? true) {
        print('Empty or null token');
        await prefs.clear();
        return false;
      }

      if (role?.isEmpty ?? true) {
        print('Empty or null role');
        await prefs.clear();
        return false;
      }

      // Validate userId format
      if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(userId!)) {
        print('Invalid userId format');
        await prefs.clear();
        return false;
      }

      print('All login checks passed');
      return true;
    } catch (e) {
      print('Error checking login status: $e');
      return false;
    }
  }

  Future<bool> hasValidCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get all credentials at once
      final userId = prefs.getString('userId');
      final token = prefs.getString('token');
      final role = prefs.getString('role');
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      print('Checking stored credentials:');
      print('userId: "$userId"');
      print('token exists: ${token != null}');
      print('role: "$role"');
      print('isLoggedIn: $isLoggedIn');

      // Check all required fields
      if (!isLoggedIn ||
          userId == null || 
          userId.isEmpty ||
          token == null || 
          token.isEmpty ||
          role == null || 
          role.isEmpty) {
        print('Missing required credentials');
        await prefs.clear();
        return false;
      }

      // Validate userId format (MongoDB ObjectId)
      if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(userId)) {
        print('Invalid userId format: $userId');
        await prefs.clear();
        return false;
      }

      print('All credentials validated successfully');
      return true;
    } catch (e) {
      print('Error checking credentials: $e');
      return false;
    }
  }

  Future<void> toggleRestaurantStatus(String restaurantId) async {
    try {
      final response = await http.put(
        getUri('/restaurants/$restaurantId/toggle-status'),
        headers: await getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to toggle restaurant status');
      }
    } catch (e) {
      print('Error toggling restaurant status: $e');
      rethrow;
    }
  }

  Future<void> updateMenu(String restaurantId, List<Map<String, dynamic>> menu) async {
    try {
      final response = await http.put(
        getUri('/restaurants/$restaurantId/menu'),
        headers: await getHeaders(),
        body: jsonEncode({'menu': menu}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update menu');
      }
    } catch (e) {
      print('Error updating menu: $e');
      rethrow;
    }
  }
}