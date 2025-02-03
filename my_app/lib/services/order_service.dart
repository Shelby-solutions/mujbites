import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cart.dart';
import 'api_service.dart';  // Import ApiService

class OrderService {
  final String baseUrl = ApiService.baseUrl;  // Use the same baseUrl as ApiService

  Future<void> placeOrder({
    required List<CartItem> items,
    required String restaurantId,
    required String restaurantName,
    required double totalAmount,
    required String address,
    required String token,
  }) async {
    try {
      print('Sending order request with data:');
      final orderItems = items.map((item) => {
        'menuItem': item.id,
        'itemName': item.name,
        'quantity': item.quantity,
        'size': item.size,
      }).toList();
      
      print('Order Items: $orderItems');

      final body = jsonEncode({
        'restaurant': restaurantId,
        'restaurantName': restaurantName,
        'items': orderItems,
        'totalAmount': totalAmount,
        'address': address,
      });

      print('Request body: $body');

      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: await ApiService().getHeaders(token),
        body: body,
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode != 201) {
        final errorMessage = response.body.isNotEmpty 
            ? jsonDecode(response.body)['message'] 
            : 'Failed to place order';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error placing order: $e');
      throw Exception('Failed to place order: $e');
    }
  }

  Future<String?> getAddress(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: await ApiService().getHeaders(token),  // Add await here
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['address'];
      }
      return null;
    } catch (e) {
      print('Error fetching address: $e');
      return null;
    }
  }

  Future<void> updateAddress(String address, String token) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/users/profile/address'),
        headers: await ApiService().getHeaders(token),  // Add await here
        body: jsonEncode({
          'address': address,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update address');
      }
    } catch (e) {
      throw Exception('Failed to update address: $e');
    }
  }
} 