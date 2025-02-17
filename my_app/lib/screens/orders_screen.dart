import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/custom_navbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'dart:async';
import '../widgets/loading_screen.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/order.dart';
import '../utils/logger.dart';

class OrdersScreen extends StatefulWidget {
  final String? initialOrderId;
  
  const OrdersScreen({Key? key, this.initialOrderId}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<Order> _orders = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  String? _userRole;
  bool _isLoggedIn = false;
  String? _selectedOrderId;

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _loadUserData();
    _setupAutoRefresh();
    if (widget.initialOrderId != null) {
      _selectedOrderId = widget.initialOrderId;
    }

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  void _setupAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _fetchOrders();
    });
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedRole = prefs.getString('role');
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      
      print('Loading user data in OrdersScreen:');
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
      setState(() => _isLoading = true);
      final orders = await _apiService.getOrders();
      setState(() {
        _orders = orders;
        _isLoading = false;
      });

      // If we have an initialOrderId, scroll to it
      if (_selectedOrderId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToOrder(_selectedOrderId!);
        });
      }
    } catch (e) {
      logger.error('Error fetching orders:', e);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading orders')),
        );
      }
    }
  }

  void _scrollToOrder(String orderId) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index != -1) {
      // Implement scrolling to the specific order
      // You'll need to add a ScrollController and ListView.builder
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.amber[50]!,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Enhanced App Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      'My Orders',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: isSmallScreen ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: AppTheme.primary,
                        size: isSmallScreen ? 24 : 28,
                      ),
                      onPressed: _fetchOrders,
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchOrders,
                  color: AppTheme.primary,
                  child: _isLoading
                      ? const LoadingScreen()
                      : _error != null
                          ? _buildErrorView()
                          : _orders.isEmpty
                              ? _buildEmptyState()
                              : _buildOrdersList(isSmallScreen),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomNavbar(
        isLoggedIn: _isLoggedIn,
        userRole: _userRole ?? '',
        onLogout: _handleLogout,
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Error loading orders',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchOrders,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              'Try Again',
              style: GoogleFonts.montserrat(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Orders Yet',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your order history will appear here',
            style: GoogleFonts.montserrat(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('Browse Restaurants'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              textStyle: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(bool isSmallScreen) {
    return FadeTransition(
      opacity: _animation,
      child: ListView.builder(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          final isSelected = order.id == _selectedOrderId;
          return AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final delay = index * 0.2;
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0.3, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(
                    delay.clamp(0.0, 1.0),
                    (delay + 0.6).clamp(0.0, 1.0),
                    curve: Curves.easeOutBack,
                  ),
                ),
              );

              return SlideTransition(
                position: slideAnimation,
                child: child,
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedOrderId = order.id);
                      // Implement order details view
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.restaurantName ?? 'Unknown Restaurant',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.bold,
                                        fontSize: isSmallScreen ? 16 : 18,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Order #${order.id.substring(0, 8)}',
                                      style: GoogleFonts.montserrat(
                                        color: Colors.grey[600],
                                        fontSize: isSmallScreen ? 12 : 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusChip(order.status),
                            ],
                          ),
                          if (order.status?.toLowerCase() == 'cancelled' && 
                              order.cancellationReason != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.red[900],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Cancelled: ${order.cancellationReason}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        color: Colors.red[900],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          ...List.generate(
                            order.items?.length ?? 0,
                            (index) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      order.items[index].itemName,
                                      style: GoogleFonts.montserrat(
                                        fontSize: isSmallScreen ? 13 : 14,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '×${order.items[index].quantity}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: isSmallScreen ? 12 : 13,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (order.address != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 18,
                                    color: Colors.grey[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      order.address.toString(),
                                      style: GoogleFonts.montserrat(
                                        fontSize: isSmallScreen ? 12 : 13,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Amount',
                                    style: GoogleFonts.montserrat(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${order.totalAmount?.toStringAsFixed(2)}',
                                    style: GoogleFonts.montserrat(
                                      fontSize: isSmallScreen ? 16 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _formatDate(order.createdAt),
                                style: GoogleFonts.montserrat(
                                  color: Colors.grey[600],
                                  fontSize: isSmallScreen ? 11 : 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color chipColor;
    Color textColor;
    IconData icon;
    
    switch (status?.toLowerCase()) {
      case 'placed':
        chipColor = Colors.blue[100]!;
        textColor = Colors.blue[900]!;
        icon = Icons.receipt_outlined;
        break;
      case 'accepted':
        chipColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        icon = Icons.thumb_up_outlined;
        break;
      case 'delivered':
        chipColor = Colors.purple[100]!;
        textColor = Colors.purple[900]!;
        icon = Icons.check_circle_outline;
        break;
      case 'cancelled':
        chipColor = Colors.red[100]!;
        textColor = Colors.red[900]!;
        icon = Icons.cancel_outlined;
        break;
      default:
        chipColor = Colors.grey[100]!;
        textColor = Colors.grey[900]!;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            status ?? 'Unknown',
            style: GoogleFonts.montserrat(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown date';
    try {
      final DateTime dateTime = DateTime.parse(date.toString());
      return DateFormat('MMM d, y • h:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }
}