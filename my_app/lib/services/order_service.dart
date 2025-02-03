import 'dart:async';
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
    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    while (retryCount < maxRetries) {
      try {
        print('Attempt ${retryCount + 1} of $maxRetries to place order');
        final orderItems = items.map((item) => {
          'menuItem': item.id,
          'itemName': item.name,
          'quantity': item.quantity,
          'size': item.size,
        }).toList();

        final body = jsonEncode({
          'restaurant': restaurantId,
          'restaurantName': restaurantName,
          'items': orderItems,
          'totalAmount': totalAmount,
          'address': address,
        });

        final response = await http.post(
          Uri.parse('$baseUrl/orders'),
          headers: await ApiService().getHeaders(token),
          body: body,
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Request timed out. Please try again.');
          },
        );

        if (response.statusCode == 201) {
          print('Order placed successfully');
          return;
        } else {
          final errorMessage = response.body.isNotEmpty
              ? jsonDecode(response.body)['message']
              : 'Failed to place order';
          throw Exception(errorMessage);
        }
      } catch (e) {
        print('Error placing order (Attempt ${retryCount + 1}): $e');
        if (e is TimeoutException || e.toString().contains('Connection reset')) {
          if (retryCount < maxRetries - 1) {
            retryCount++;
            await Future.delayed(retryDelay);
            continue;
          }
        }
        throw Exception(e is TimeoutException
            ? 'Request timed out. Please check your internet connection and try again.'
            : 'Failed to place order: ${e.toString().replaceAll('Exception:', '')}');
      }
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