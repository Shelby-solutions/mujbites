import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
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
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:io' show Platform;

class RestaurantPanelScreen extends StatefulWidget {
  const RestaurantPanelScreen({super.key});

  @override
  State<RestaurantPanelScreen> createState() => _RestaurantPanelScreenState();
}

class _RestaurantPanelScreenState extends State<RestaurantPanelScreen> with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _error;
  String? _restaurantId;
  bool _isOpen = false;
  String _activeTab = 'Placed';
  bool _showSettings = false;
  Timer? _refreshTimer;
  String? _userRole;
  bool _isLoggedIn = false;
  Map<String, dynamic>? _restaurantData;
  DateTime? _openingTime;
  bool _showOrders = false;
  bool _hasMoreOrders = true;
  
  // Optimized state management
  final Map<String, bool> _orderLoadingStates = {};
  Map<String, int> _orderCounts = {
    'Placed': 0,
    'Accepted': 0,
    'Delivered': 0,
    'Cancelled': 0,
  };

  // Cache computed values
  final Map<String, List<Map<String, dynamic>>> _orderCache = {};
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<String?> _errorNotifier = ValueNotifier<String?>(null);
  
  // Debounce timer for refresh
  Timer? _debounceTimer;
  
  // Scroll controller for optimized list
  final ScrollController _scrollController = ScrollController();

  // Add this at the top with other class variables
  final Map<String, Completer<void>> _fetchCompleters = {};
  final Map<String, DateTime> _lastFetchTime = {};
  static const _cacheValidityDuration = Duration(seconds: 10);

  static const Map<String, String> STATUS_DISPLAY = {
    'Placed': 'New Order',
    'Accepted': 'Accepted',
    'Delivered': 'Completed',
    'Cancelled': 'Cancelled'
  };

  // Add month names as a class variable
  final monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  WebSocketChannel? _webSocket;
  StreamSubscription? _webSocketSubscription;
  bool _isDisposed = false;

  final List<String> _cancelReasons = [
    'Out of ingredients',
    'Kitchen closed',
    'Too busy to fulfill',
    'Customer requested cancellation',
    'Other',
  ];

  // Add new variables for tracking order updates
  DateTime? _lastKnownOrderTime;
  int _reconnectAttempts = 0;
  static const int MAX_RECONNECT_ATTEMPTS = 5;
  static const Duration RECONNECT_DELAY = Duration(seconds: 5);

  // Add these methods after other instance variables
  Timer? _orderCleanupTimer;
  static const Duration ORDER_EXPIRY_DURATION = Duration(minutes: 10);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    print('RestaurantPanelScreen - initState called');
    _activeTab = 'Placed';
    _orders = [];
    _loadUserData();
    _fetchRestaurantData().then((_) {
      print('Restaurant data fetched, setting up orders refresh');
      _setupOrdersRefresh();
      _prefetchOtherTabs();
    });
    _setupNotificationHandlers();
    _scrollController.addListener(_onScroll);
    _initializeWebSocket();
    _fetchOrders(forceRefresh: true);
    _updateOrderCounts();
    
    // Set up timer to check for old orders
    _orderCleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkAndCancelOldOrders();
    });
  }

  @override
  void dispose() {
    _orderCleanupTimer?.cancel();
    _isDisposed = true;
    _refreshTimer?.cancel();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _isLoadingNotifier.dispose();
    _errorNotifier.dispose();
    if (_restaurantData != null) {
      _notificationService.unsubscribeFromRestaurantOrders(_restaurantData!['_id']);
    }
    _notificationService.dispose();
    _webSocketSubscription?.cancel();
    _webSocket?.sink.close();
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
      final userId = await UserPreferences.getString('userId');
      print('Fetching restaurant data for user: $userId');
      
      final data = await _apiService.getRestaurantByOwnerId();
      print('Received restaurant data: $data');
      
      if (mounted) {
        setState(() {
          _restaurantData = data;
          _isLoadingNotifier.value = false;  // Reset loading state here
          _isOpen = data['isActive'] ?? false;
          _error = null;
        });
        
        // Subscribe to notifications for this restaurant
        await _notificationService.subscribeToRestaurantOrders(data['_id']);
        
        // Fetch initial orders after restaurant data is loaded
        await _fetchOrders();
      }
    } catch (e) {
      print('Error fetching restaurant data: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load restaurant data: $e';
          _isLoadingNotifier.value = false;  // Reset loading state on error too
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
    _notificationService.onNewOrder = (orderData) {
      _fetchOrders(); // Refresh orders when new order notification received
    };
  }

  Future<void> _setupOrdersRefresh() async {
    print('Setting up orders refresh timer');
    _refreshTimer?.cancel();
    
    // More frequent updates for 'Placed' orders
    _refreshTimer = Timer.periodic(
      _activeTab == 'Placed' ? 
        const Duration(seconds: 15) : 
        const Duration(seconds: 30), 
      (_) {
        if (mounted && !_isDisposed) {
          print('Timer triggered - fetching orders for $_activeTab status');
          _fetchOrders(forceRefresh: _activeTab == 'Placed');
        }
      }
    );
    
    // Initial fetch
    print('Performing initial order fetch');
    await _fetchOrders(forceRefresh: true);
  }

  Future<void> _setupNotificationHandlers() async {
    await _notificationService.initialize();
    _notificationService.onNewOrder = (orderData) {
      _fetchOrders(); // Refresh orders when new order notification received
    };
  }

  Future<void> _fetchOrders({bool forceRefresh = false}) async {
    if (!mounted || _restaurantData == null) return;

    final currentStatus = _activeTab;
    print('Fetching orders for status: $currentStatus, forceRefresh: $forceRefresh');
    
    // Always fetch for 'Placed' orders or when force refreshing
    final shouldBypassCache = currentStatus == 'Placed' || forceRefresh;
    
    // Check cache validity
    if (!shouldBypassCache && 
        _lastFetchTime.containsKey(currentStatus) &&
        DateTime.now().difference(_lastFetchTime[currentStatus]!) < const Duration(seconds: 30)) {
      print('Using cached orders for status: $currentStatus');
      setState(() {
        _orders = List<Map<String, dynamic>>.from(_orderCache[currentStatus] ?? []);
      });
      return;
    }

    await _fetchOrdersForStatus(currentStatus);
  }

  Future<void> _fetchOrdersForStatus(String status) async {
    if (!mounted || _restaurantData == null) return;

    print('Fetching orders for status: $status');
    setState(() {
      if (status == _activeTab) {
        _isLoading = true;
      }
      _error = null;
    });

    try {
      final orders = await _apiService.getRestaurantOrders(
        _restaurantData!['_id'],
        status: status,
      );

      if (!mounted) return;

      print('Received ${orders.length} orders for status: $status');
      
      // Filter orders for today only
      final todayOrders = orders.where(_isOrderFromToday).toList();
      print('Filtered ${todayOrders.length} orders for today');
      
      // Create deep copies of the orders to prevent reference issues
      final ordersCopy = todayOrders.map((order) {
        final copy = Map<String, dynamic>.from(order);
        if (order['customer'] != null) {
          copy['customer'] = Map<String, dynamic>.from(order['customer']);
        }
        if (order['items'] != null) {
          copy['items'] = List<Map<String, dynamic>>.from(
            order['items'].map((item) => Map<String, dynamic>.from(item))
          );
        }
        return copy;
      }).toList();
      
      setState(() {
        if (status == _activeTab) {
          _orders = ordersCopy;
          _isLoading = false;
        }
        _orderCache[status] = ordersCopy;
        _lastFetchTime[status] = DateTime.now();
      });

      _updateOrderCounts();

    } catch (e) {
      print('Error fetching orders for $status: $e');
      if (!mounted) return;
      setState(() {
        if (status == _activeTab) {
          _error = 'Failed to load orders';
          _isLoading = false;
        }
      });
    }
  }

  Future<void> _prefetchOtherTabs() async {
    if (!mounted || _restaurantData == null) return;
    
    final allStatuses = ['Placed', 'Accepted', 'Delivered', 'Cancelled'];
    final currentStatus = _activeTab;
    
    for (final status in allStatuses) {
      if (status == currentStatus) continue;
      
      try {
        print('Prefetching orders for status: $status');
        final orders = await _apiService.getRestaurantOrders(
          _restaurantData!['_id'],
          status: status,
        );
        
        if (!mounted) return;
        
        _orderCache[status] = List<Map<String, dynamic>>.from(orders);
        print('Prefetched ${orders.length} orders for status: $status');
        
        _updateOrderCounts();
      } catch (e) {
        print('Error prefetching orders for $status: $e');
      }
    }
  }

  void _onScroll() {
    if (!_hasMoreOrders || _isLoadingNotifier.value) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    if (currentScroll >= maxScroll - 200) {
      _fetchOrders();
    }
  }

  Future<void> _handleOrderStatusUpdate(
    String orderId,
    String action, {
    String? reason,
    bool isAutoCancel = false
  }) async {
    if (_orderLoadingStates[orderId] == true) {
      print('Order $orderId is already being processed');
      return;
    }

    setState(() {
      _orderLoadingStates[orderId] = true;
    });

    try {
      print('Updating order $orderId with action: $action');
      final updatedOrder = await _apiService.updateOrderStatus(orderId, action, reason);
      
      if (!mounted) return;

      final newStatus = updatedOrder['orderStatus'];
      print('Order updated successfully. New status: $newStatus');

      // Show success message only for manual actions
      if (mounted && !isAutoCancel) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${_getActionMessage(action)}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Clear all caches to force fresh data
      _orderCache.clear();
      _lastFetchTime.clear();

      // Handle tab switching and data refresh based on action
      if (action.toLowerCase() == 'confirm') {
        setState(() {
          _activeTab = 'Accepted';
          _orderLoadingStates[orderId] = false;
        });
        
        await Future.wait([
          _fetchOrdersForStatus('Placed'),
          _fetchOrdersForStatus('Accepted'),
        ]);
      } else {
        setState(() {
          _orderLoadingStates[orderId] = false;
        });
        await _fetchOrdersForStatus(_activeTab);
      }

      _updateAllTabs();
      _updateOrderCounts();

    } catch (e) {
      print('Error updating order status: $e');
      if (mounted && !isAutoCancel) {
        setState(() {
          _orderLoadingStates[orderId] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateAllTabs() async {
    final allStatuses = ['Placed', 'Accepted', 'Delivered', 'Cancelled'];
    
    for (final status in allStatuses) {
      if (status == _activeTab) continue; // Skip active tab as it's already updated
      await _fetchOrdersForStatus(status);
    }
  }

  String _getActionMessage(String action) {
    switch (action.toLowerCase()) {
      case 'confirm':
        return 'accepted successfully';
      case 'deliver':
        return 'marked as delivered';
      case 'cancel':
        return 'cancelled';
      default:
        return 'updated';
    }
  }

  void _updateOrderCounts() {
    final counts = {
      'Placed': _orderCache['Placed']?.length ?? 0,
      'Accepted': _orderCache['Accepted']?.length ?? 0,
      'Delivered': _orderCache['Delivered']?.length ?? 0,
      'Cancelled': _orderCache['Cancelled']?.length ?? 0,
    };
    
    print('Updated order counts: $counts');
    
    if (mounted) {
      setState(() {
        _orderCounts = counts;
      });
    }
  }

  String _calculateTotalRevenue() {
    try {
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);
      
      final deliveredOrders = _orderCache['Delivered'] ?? [];
      print('Total delivered orders in cache: ${deliveredOrders.length}');
      
      double totalRevenue = 0.0;
      int monthlyDeliveredCount = 0;
      
      for (var order in deliveredOrders) {
        try {
          // Try to get the delivery date from either updatedAt or createdAt
          String? dateStr = order['updatedAt']?.toString() ?? order['createdAt']?.toString();
          
          if (dateStr == null) {
            print('Order ${order['_id']} missing both updatedAt and createdAt');
            continue;
          }
          
          // Parse delivery date
          final orderDate = DateTime.parse(dateStr);
          final orderMonth = DateTime(orderDate.year, orderDate.month);
          
          // Check if order was delivered in current month
          if (orderMonth.isAtSameMomentAs(currentMonth)) {
            monthlyDeliveredCount++;
            
            // Get and validate amount
            final amount = order['totalAmount'];
            if (amount == null) {
              print('Order has null amount: ${order['_id']}');
              continue;
            }
            
            // Convert amount to double
            double orderAmount = 0.0;
            if (amount is num) {
              orderAmount = amount.toDouble();
            } else if (amount is String) {
              orderAmount = double.tryParse(amount) ?? 0.0;
            }
            
            if (orderAmount <= 0) {
              print('Order has invalid amount: ${order['_id']}, amount: $amount');
              continue;
            }
            
            totalRevenue += orderAmount;
            print('Added order ${order['_id']} to revenue: ₹$orderAmount (Total: ₹$totalRevenue)');
          }
        } catch (e) {
          print('Error processing order ${order['_id']}: $e');
        }
      }
      
      print('Monthly delivered orders: $monthlyDeliveredCount');
      print('Final total revenue for ${monthNames[now.month - 1]}: ₹${totalRevenue.toStringAsFixed(2)}');
      return totalRevenue.toStringAsFixed(2);
    } catch (e) {
      print('Error calculating total revenue: $e');
      return '0.00';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
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
              child: ValueListenableBuilder<String?>(
                valueListenable: _errorNotifier,
                builder: (context, error, _) {
                  if (error != null) {
                    return Center(child: Text(error));
                  }
                  
                  final orders = _orderCache[_activeTab] ?? [];
                  
                  if (orders.isEmpty) {
                    return Center(
                      child: Text('No ${_activeTab} orders found'),
                    );
                  }
                  
                  return RefreshIndicator(
                    onRefresh: _fetchOrders,
                    color: AppTheme.primary,
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: orders.length + 1, // +1 for loading indicator
                      itemBuilder: (context, index) {
                        if (index == orders.length) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: _isLoadingNotifier,
                            builder: (context, isLoading, _) {
                              return isLoading
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : const SizedBox.shrink();
                            },
                          );
                        }
                        return _buildOrderCard(orders[index]);
                      },
                    ),
                  );
                },
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

    // Optimized main restaurant panel
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchRestaurantData,
        color: AppTheme.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildRestaurantCard(),
                  const SizedBox(height: 16),
                  _buildStatisticsCard(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                ]),
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

  Widget _buildRestaurantCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_restaurantData?['imageUrl'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: _restaurantData!['imageUrl'],
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                  fit: BoxFit.cover,
                  height: 200,
                  width: double.infinity,
                ),
              ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 8),
            if (_restaurantData?['owner']?['mobileNumber'] != null)
              Row(
                children: [
                  const Icon(Icons.phone, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    _restaurantData!['owner']['mobileNumber'],
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
          ],
        ),
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
        _buildTabButton('Placed', 'New\nOrders'),
        _buildTabButton('Accepted', 'Accepted\nOrders'),
        _buildTabButton('Delivered', 'Completed\nOrders'),
        _buildTabButton('Cancelled', 'Cancelled\nOrders'),
      ],
    );
  }

  Widget _buildTabButton(String tab, String label) {
    final isActive = _activeTab == tab;
    return TextButton(
      onPressed: () => _onTabChanged(tab),
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
    final orderId = order['_id'].toString();
    final isLoading = _orderLoadingStates[orderId] ?? false;
    
    final status = order['orderStatus']?.toString() ?? 'Placed';
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
    final customer = order['customer'] as Map<String, dynamic>?;
    final totalAmount = order['totalAmount']?.toString() ?? '0';
    final createdAt = DateTime.parse(order['createdAt'].toString());
    final deliveryAddress = order['address']?.toString() ?? customer?['address']?.toString() ?? 'N/A';
    
    // Convert to Indian time (UTC+5:30)
    final indianTime = createdAt.add(const Duration(hours: 5, minutes: 30));
    final formattedTime = '${indianTime.day}/${indianTime.month}/${indianTime.year} '
        '${indianTime.hour.toString().padLeft(2, '0')}:'
        '${indianTime.minute.toString().padLeft(2, '0')}';

    // Determine if we should show customer details
    final shouldShowCustomerDetails = ['Accepted', 'Delivered'].contains(status);

    return Opacity(
      opacity: isLoading ? 0.6 : 1.0,
      child: IgnorePointer(
        ignoring: isLoading,
        child: Card(
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
                // Show customer details only for accepted and delivered orders
                if (customer != null) ...[
                  if (shouldShowCustomerDetails) ...[
                    Text(
                      'Customer: ${customer['username'] ?? 'Anonymous'}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          customer['mobileNumber'] ?? 'N/A',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                  Text(
                    'Delivery Address:',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    deliveryAddress,
                    style: TextStyle(
                      color: Colors.grey[800],
                      height: 1.3,
                    ),
                  ),
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
                        onPressed: () => _handleOrderStatusUpdate(orderId, 'confirm'),
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
                      onPressed: () => _handleOrderStatusUpdate(orderId, 'deliver'),
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
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String displayStatus = STATUS_DISPLAY[status] ?? status;
    
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
      label: Text(displayStatus),
      backgroundColor: color.withOpacity(0.8),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
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

  Widget _buildStatisticsCard() {
    // Count orders by status for current month
    final placedOrders = _orderCounts['Placed'] ?? 0;
    final acceptedOrders = _orderCounts['Accepted'] ?? 0;
    final deliveredOrders = _orderCounts['Delivered'] ?? 0;
    final cancelledOrders = _orderCounts['Cancelled'] ?? 0;
    
    // Get current month name
    final now = DateTime.now();
    final currentMonthName = monthNames[now.month - 1];
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$currentMonthName Statistics',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatsCard(
                  'Active Orders',
                  (placedOrders + acceptedOrders).toString(),
                  Icons.shopping_bag,
                ),
                const SizedBox(width: 16),
                _buildStatsCard(
                  'Revenue',
                  '₹${_calculateTotalRevenue()}',
                  Icons.payments,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatsCard(
                  'Completed',
                  deliveredOrders.toString(),
                  Icons.check_circle,
                ),
                const SizedBox(width: 16),
                _buildStatsCard(
                  'Cancelled',
                  cancelledOrders.toString(),
                  Icons.cancel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildActionButton(
          icon: Icons.restaurant_menu,
          label: 'Edit Menu',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditMenuScreen(
                restaurantId: _restaurantData?['_id'],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          icon: Icons.list_alt,
          label: 'View Orders',
          onTap: () => setState(() => _showOrders = true),
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          icon: _isOpen ? Icons.store : Icons.store_outlined,
          label: _isOpen ? 'Close Restaurant' : 'Open Restaurant',
          onTap: _toggleRestaurantStatus,
        ),
      ],
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
              if (selectedReason != null && orderId != null) {
                Navigator.pop(context);
                _handleOrderStatusUpdate(orderId!, 'cancel');
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _initializeWebSocket() {
    if (_restaurantData == null) {
      print('Restaurant data not available for WebSocket initialization');
      return;
    }

    try {
      final wsUrl = ApiService.useProductionUrl
          ? 'wss://mujbites-app.onrender.com'
          : Platform.isAndroid
              ? 'ws://10.0.2.2:5000'
              : 'ws://localhost:5000';

      print('Initializing WebSocket connection to: $wsUrl/orders/${_restaurantData!['_id']}');
      
      // Close existing connections
      _webSocket?.sink.close();
      _webSocketSubscription?.cancel();
      
      _webSocket = WebSocketChannel.connect(
        Uri.parse('$wsUrl/orders/${_restaurantData!['_id']}'),
      );

      _webSocketSubscription = _webSocket?.stream.listen(
        (message) {
          print('WebSocket message received: $message');
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'orderUpdate' || data['type'] == 'newOrder') {
              print('Order update received for order: ${data['orderId']}');
              
              // Reset reconnect attempts on successful message
              _reconnectAttempts = 0;
              
              // Force refresh current tab immediately
              _fetchOrders(forceRefresh: true);
              
              // Play notification sound for new orders
              if (data['type'] == 'newOrder' && mounted) {
                _notificationService.playNewOrderSound();
                
                // Show in-app notification
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('New order received!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            }
          } catch (e) {
            print('Error processing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _handleWebSocketReconnection();
        },
        onDone: () {
          print('WebSocket connection closed');
          _handleWebSocketReconnection();
        },
      );

      print('WebSocket connected successfully');
    } catch (e) {
      print('Error initializing WebSocket: $e');
      _handleWebSocketReconnection();
    }
  }

  void _handleWebSocketReconnection() {
    if (_isDisposed) return;
    
    _webSocketSubscription?.cancel();
    _webSocket?.sink.close();
    
    // Implement exponential backoff
    if (_reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
      final delay = Duration(seconds: RECONNECT_DELAY.inSeconds * (_reconnectAttempts + 1));
      _reconnectAttempts++;
      
      print('Attempting to reconnect WebSocket (Attempt $_reconnectAttempts) after ${delay.inSeconds} seconds');
      
      Future.delayed(delay, () {
        if (!_isDisposed) {
          print('Executing reconnection attempt $_reconnectAttempts');
          _initializeWebSocket();
          _fetchOrders(forceRefresh: true);
        }
      });
    } else {
      print('Max reconnection attempts reached. Manual refresh required.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection lost. Pull to refresh.'),
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                _reconnectAttempts = 0;
                _initializeWebSocket();
                _fetchOrders(forceRefresh: true);
              },
            ),
          ),
        );
      }
    }
  }

  void _onTabChanged(String newTab) {
    if (_activeTab != newTab) {
      setState(() {
        _activeTab = newTab;
        // Reset error state on tab change
        _error = null;
      });
      // Fetch orders for the new tab
      _fetchOrders(forceRefresh: newTab == 'Placed');
    }
  }

  bool _isOrderFromToday(Map<String, dynamic> order) {
    try {
      final orderDate = DateTime.parse(order['createdAt'].toString()).add(const Duration(hours: 5, minutes: 30));
      final now = DateTime.now();
      return orderDate.year == now.year && 
             orderDate.month == now.month && 
             orderDate.day == now.day;
    } catch (e) {
      print('Error checking order date: $e');
      return false;
    }
  }

  Future<void> _checkAndCancelOldOrders() async {
    if (!mounted || _restaurantData == null) return;

    try {
      final placedOrders = _orderCache['Placed'] ?? [];
      final now = DateTime.now();
      
      for (var order in placedOrders) {
        try {
          final orderDate = DateTime.parse(order['createdAt'].toString()).add(const Duration(hours: 5, minutes: 30));
          final orderAge = now.difference(orderDate);
          
          if (orderAge > ORDER_EXPIRY_DURATION) {
            print('Auto-cancelling old order: ${order['_id']}');
            await _handleOrderStatusUpdate(
              order['_id'].toString(),
              'cancel',
              reason: 'Order expired - No response from restaurant',
              isAutoCancel: true
            );
          }
        } catch (e) {
          print('Error processing order for auto-cancel: $e');
        }
      }
    } catch (e) {
      print('Error in auto-cancel check: $e');
    }
  }
} 