import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import '../services/api_service.dart';
import '../widgets/custom_navbar.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class YourOrdersScreen extends StatefulWidget {
  const YourOrdersScreen({super.key});

  @override
  State<YourOrdersScreen> createState() => _YourOrdersScreenState();
}

class _YourOrdersScreenState extends State<YourOrdersScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  String? _userRole;
  bool _isLoggedIn = false;

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _loadUserData();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _fetchOrders();
    });

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    _animationController.forward();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userRole = prefs.getString('role');
        _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      });
      print('User role in orders screen: $_userRole');
      print('Is logged in: $_isLoggedIn');
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _handleLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      print('Logout error: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    try {
      final orders = await _apiService.getUserOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text(
              'Your Orders',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchOrders,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Text(
                              'Error: $_error',
                              style: const TextStyle(color: Colors.red),
                            ),
                          )
                        : _orders.isEmpty
                            ? const Center(child: Text('No orders found.'))
                            : FadeTransition(
                                opacity: _animation,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _orders.length,
                                  itemBuilder: (context, index) {
                                    final order = _orders[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Restaurant: ${order['restaurantName'] ?? 'N/A'}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Color(0xFFD4AF37),
                                                    ),
                                                  ),
                                                ),
                                                _buildStatusChip(order['orderStatus'] ?? 'Unknown'),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Ordered At: ${_formatDate(order['createdAt'])}',
                                              style: const TextStyle(color: Colors.grey),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Total Amount: ₹${order['totalAmount']?.toString() ?? '0.00'}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Color(0xFFD4AF37),
                                              ),
                                            ),
                                            if (order['orderStatus'] == 'Cancelled' &&
                                                order['cancellationReason'] != null) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                'Cancellation Reason: ${order['cancellationReason']}',
                                                style: const TextStyle(color: Colors.red),
                                              ),
                                            ],
                                            const Divider(),
                                            const Text(
                                              'Items:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFD4AF37),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ..._buildOrderItems(order['items'] ?? []),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomNavbar(
        isLoggedIn: _isLoggedIn,
        userRole: _userRole ?? '',
        onLogout: _handleLogout,
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'placed':
        color = Colors.orange;
        break;
      case 'accepted':
        color = Colors.blue;
        break;
      case 'delivered':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        status,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  List<Widget> _buildOrderItems(List<dynamic> items) {
    return items.map<Widget>((item) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${item['itemName'] ?? 'Unknown Item'} x${item['quantity'] ?? 1}',
                style: const TextStyle(color: Color(0xFFD4AF37)),
              ),
            ),
            if (item['size'] != null)
              Text(
                '(${item['size']})',
                style: const TextStyle(color: Colors.grey),
              ),
          ],
        ),
      );
    }).toList();
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final DateTime dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}';
    } catch (e) {
      return 'N/A';
    }
  }
}