import 'package:flutter/material.dart';
import '../widgets/custom_navbar.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/user_preferences.dart';
import '../screens/edit_menu_screen.dart';
import '../widgets/loading_screen.dart';

class RestaurantPanelScreen extends StatefulWidget {
  const RestaurantPanelScreen({super.key});

  @override
  State<RestaurantPanelScreen> createState() => _RestaurantPanelScreenState();
}

class _RestaurantPanelScreenState extends State<RestaurantPanelScreen> {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _error;
  String? _restaurantId;
  bool _isOpen = false;
  String _activeTab = 'pending';  // 'pending', 'completed', 'cancelled'
  bool _showSettings = false;
  Timer? _refreshTimer;
  String? _userRole;
  bool _isLoggedIn = false;
  Map<String, dynamic>? _restaurantData;
  DateTime? _openingTime;
  bool _showOrders = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchRestaurantData();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _notificationService.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedRole = prefs.getString('role');
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      
      print('Loading user data in RestaurantPanelScreen:');
      print('Stored role: $storedRole');
      print('Is logged in: $isLoggedIn');
      
      if (mounted) {
        setState(() {
          _userRole = storedRole;
          _isLoggedIn = isLoggedIn;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _fetchRestaurantData() async {
    try {
      setState(() => _isLoading = true);
      
      final userId = await UserPreferences.getString('userId');
      print('Fetching restaurant data for user: $userId');
      
      final data = await _apiService.getRestaurantByOwnerId();
      print('Received restaurant data: $data');
      
      if (mounted) {
        setState(() {
          _restaurantData = data;
          _isOpen = data['isActive'] ?? false;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      print('Error fetching restaurant data: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load restaurant data';
          _isLoading = false;
        });
      }
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

  Future<void> _toggleRestaurantStatus() async {
    try {
      if (_restaurantData != null) {
        await _apiService.toggleRestaurantStatus(_restaurantData!['_id']);
        await _fetchRestaurantData(); // Refresh data after toggle
      }
    } catch (e) {
      print('Error toggling restaurant status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating restaurant status: $e')),
      );
    }
  }

  Future<void> _checkLoginAndInitialize() async {
    if (!mounted) return;

    try {
      print('Checking credentials before initialization...');
      
      // Get stored credentials
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      print('Current stored userId: "$userId"');
      
      final hasCredentials = await _apiService.hasValidCredentials();
      print('Credentials validation result: $hasCredentials');
      
      if (!hasCredentials) {
        if (mounted) {
          print('Invalid credentials - redirecting to login');
          await prefs.clear();
          await Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      print('Valid credentials found - proceeding with initialization');
      await _initialize();
    } catch (e) {
      print('Error during initialization check: $e');
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        await Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _initialize() async {
    try {
      print('Starting restaurant panel initialization');
      
      // Verify credentials again before proceeding
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      print('UserId before initialization: "$userId"');
      
      if (userId == null || userId.isEmpty) {
        throw Exception('Missing userId during initialization');
      }
      
      await _checkAccess();
      await _initializeNotifications();
      await _fetchRestaurantData();
      
      // Set up periodic refresh
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _fetchOrders();
      });
    } catch (e) {
      print('Initialization error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize: $e';
          _isLoading = false;
        });
        
        // Redirect to login if credentials are invalid
        if (e.toString().contains('Missing userId')) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    }
  }

  Future<void> _checkAccess() async {
    try {
      final isOwner = await _apiService.isRestaurantOwner();
      print('Is restaurant owner: $isOwner');
      
      if (!isOwner && mounted) {
        // Also verify stored role
        final prefs = await SharedPreferences.getInstance();
        final role = prefs.getString('role');
        print('Stored role: $role');

        Navigator.pushReplacementNamed(context, '/home');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not authorized as restaurant owner')),
        );
      }
    } catch (e) {
      print('Access check error: $e');
      if (mounted) {
        setState(() {
          _error = 'Access check failed: $e';
          _isLoading = false;
        });
        
        // Navigate to login if access check fails
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
    
    // Check notification permissions
    final hasPermission = await _notificationService.checkNotificationPermissions();
    if (!hasPermission && mounted) {
      // Show custom permission dialog
      await _notificationService.showPermissionDialog(context);
    }
    
    await _notificationService.connectToWebSocket();
    
    _notificationService.onNewOrder = (orderData) {
      _fetchOrders();
      
      if (mounted) {
        final orderId = orderData['_id'].toString();
        final shortOrderId = orderId.substring(orderId.length - 6);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New order #$shortOrderId received!'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                setState(() {
                  _showOrders = true;
                  _activeTab = 'pending';
                });
              },
            ),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    };
  }

  Future<void> _fetchOrders() async {
    if (_restaurantData == null) return;

    try {
      final orders = await _apiService.getRestaurantOrders(_restaurantData!['_id']);
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      print('Error fetching orders: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load orders: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleOrderStatusUpdate(String orderId, String status, [String? reason]) async {
    try {
      print('Updating order: ID=$orderId, status=$status, reason=$reason');
      setState(() => _isLoading = true);
      
      await _apiService.updateOrderStatus(orderId, status, reason);
      await _fetchOrders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order $status successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating order status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    return _orders.where((order) {
      final orderStatus = order['orderStatus']?.toString() ?? 'Placed';
      switch (_activeTab) {
        case 'pending':
          return orderStatus == 'Placed' || orderStatus == 'Accepted';
        case 'completed':
          return orderStatus == 'Delivered';
        case 'cancelled':
          return orderStatus == 'Cancelled';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingScreen());
    }

    // Show orders panel if orders are being viewed
    if (_showOrders) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Orders'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _showOrders = false),
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 16),
            _buildTabButtons(),
            const SizedBox(height: 16),
            Expanded(
              child: _error != null
                  ? Center(child: Text('Error: $_error'))
                  : _filteredOrders.isEmpty
                      ? Center(child: Text('No ${_activeTab} orders found'))
                      : ListView.builder(
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, index) => _buildOrderCard(_filteredOrders[index]),
                        ),
            ),
          ],
        ),
        bottomNavigationBar: CustomNavbar(
          isLoggedIn: _isLoggedIn,
          userRole: _userRole ?? '',
          onLogout: _handleLogout,
        ),
      );
    }

    // Show main restaurant panel
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _restaurantData?['name'] ?? 'Restaurant Name',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _restaurantData?['address'] ?? 'Address',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Status: ${_restaurantData?['isActive'] ?? false ? 'Open' : 'Closed'}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        Switch(
                          value: _restaurantData?['isActive'] ?? false,
                          onChanged: (value) => _toggleRestaurantStatus(),
                          activeColor: const Color(0xFFFAC744),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              icon: Icons.restaurant_menu,
              label: 'Menu Management',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditMenuScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              icon: Icons.receipt_long,
              label: 'Orders',
              onTap: () {
                setState(() {
                  _showOrders = true;
                  _fetchOrders(); // Fetch orders when showing orders panel
                });
              },
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFFAC744)),
        title: Text(label),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStatsCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTabButton('pending', 'Pending\nOrders'),
        _buildTabButton('completed', 'Completed\nOrders'),
        _buildTabButton('cancelled', 'Cancelled\nOrders'),
      ],
    );
  }

  Widget _buildTabButton(String tab, String label) {
    final isActive = _activeTab == tab;
    return TextButton(
      onPressed: () => setState(() => _activeTab = tab),
      style: TextButton.styleFrom(
        backgroundColor: isActive ? AppTheme.primary : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.grey[600],
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['orderStatus']?.toString() ?? 'Placed';
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
    final customer = order['customer'] as Map<String, dynamic>?;
    final orderId = order['_id'].toString();
    final totalAmount = order['totalAmount']?.toString() ?? '0';
    final createdAt = DateTime.parse(order['createdAt'].toString());
    
    // Convert to Indian time (UTC+5:30)
    final indianTime = createdAt.add(const Duration(hours: 5, minutes: 30));
    final formattedTime = '${indianTime.day}/${indianTime.month}/${indianTime.year} '
        '${indianTime.hour.toString().padLeft(2, '0')}:'
        '${indianTime.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order #${orderId.substring(orderId.length - 6)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                _buildStatusChip(status),
              ],
            ),
            const Divider(),
            // Show time for all orders
            Text(
              'Received at: $formattedTime',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            // Show customer details based on order status
            if (customer != null) ...[
              if (status == 'Placed') ...[
                // Only show delivery address for pending orders
                Text(
                  'Delivery Address:',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  customer['address'] ?? 'N/A',
                  style: TextStyle(
                    color: Colors.grey[800],
                    height: 1.3,
                  ),
                ),
              ] else if (!['Cancelled'].contains(status)) ...[
                // Show all customer details for accepted/delivered orders
                Text(
                  'Customer: ${customer['username'] ?? 'Anonymous'}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text('Phone: ${customer['mobileNumber'] ?? 'N/A'}'),
                Text(
                  'Delivery Address:',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  customer['address'] ?? 'N/A',
                  style: TextStyle(
                    color: Colors.grey[800],
                    height: 1.3,
                  ),
                ),
              ],
              const Divider(),
            ],
            // Order items
            ...items.map((item) => ListTile(
              title: Text(
                item['itemName'] ?? 'Unknown Item',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text('Size: ${item['size']}'),
              trailing: Text(
                'x${item['quantity']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹$totalAmount',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            if (status == 'Placed') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Accept'),
                    onPressed: () => _handleOrderStatusUpdate(orderId, 'Accepted'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cancel),
                    label: const Text('Decline'),
                    onPressed: () => _showDeclineDialog(orderId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
            if (status == 'Accepted') ...[
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.local_shipping),
                  label: const Text('Mark as Delivered'),
                  onPressed: () => _handleOrderStatusUpdate(orderId, 'Delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
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
      label: Text(status),
      backgroundColor: color,
      labelStyle: const TextStyle(color: Colors.white),
    );
  }

  Future<void> _showDeclineDialog(String orderId) async {
    String? selectedReason;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Order'),
        content: DropdownButtonFormField<String>(
          value: selectedReason,
          items: const [
            DropdownMenuItem(value: 'Items not available', child: Text('Items not available')),
            DropdownMenuItem(value: 'Shop Closed', child: Text('Shop Closed')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (value) {
            selectedReason = value;
          },
          decoration: const InputDecoration(
            labelText: 'Select reason',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (selectedReason != null) {
                Navigator.pop(context);
                _handleOrderStatusUpdate(orderId, 'Cancelled', selectedReason);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  String _calculateItemTotal(Map<String, dynamic> item) {
    final quantity = item['quantity'] ?? 1;
    final size = item['size'] ?? 'Regular';
    num price = 0;
    
    // Debug print to see the item structure
    print('Item data: $item');
    
    // Check if menuItem exists and has price information
    if (item['menuItem'] != null && item['menuItem'] is Map) {
      final menuItem = item['menuItem'] as Map<String, dynamic>;
      
      // Check for size-specific pricing
      if (menuItem['sizes'] != null && menuItem['sizes'] is Map) {
        price = menuItem['sizes'][size]?.toDouble() ?? menuItem['price']?.toDouble() ?? 0;
      } else {
        price = menuItem['price']?.toDouble() ?? 0;
      }
    }
    
    final total = price * quantity;
    return total.toStringAsFixed(2); // Format to 2 decimal places
  }

  String _calculateTotalRevenue() {
    return _orders
        .where((o) => o['orderStatus'] == 'Delivered')
        .fold(0.0, (sum, order) => sum + (order['totalAmount'] ?? 0))
        .toStringAsFixed(2);
  }
} 