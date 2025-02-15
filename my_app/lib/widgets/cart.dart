import 'package:flutter/material.dart';
import 'package:my_app/models/cart.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../services/order_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/notification_service.dart';
import '../utils/logger.dart';

class CartWidget extends StatefulWidget {
  final VoidCallback onClose;

  const CartWidget({super.key, required this.onClose});

  @override
  State<CartWidget> createState() => _CartWidgetState();
}

class _CartWidgetState extends State<CartWidget> with SingleTickerProviderStateMixin {
  final TextEditingController _addressController = TextEditingController();
  final OrderService _orderService = OrderService();
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  bool _showAddressPopup = false;
  bool _isOrdering = false;
  final _logger = Logger();

  // Cache styles and decorations
  static final _headerGradient = LinearGradient(
    colors: [
      AppTheme.primary,
      AppTheme.primary.withOpacity(0.8),
    ],
  );

  static final _containerDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 20,
        offset: const Offset(0, -5),
      ),
    ],
  );

  static final _dragHandleDecoration = BoxDecoration(
    color: Colors.grey[300],
    borderRadius: BorderRadius.circular(2),
  );

  static final _itemContainerDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static final _quantityContainerDecoration = BoxDecoration(
    color: Colors.grey[50],
    borderRadius: BorderRadius.circular(12),
  );

  static final _summaryContainerDecoration = BoxDecoration(
    color: Colors.grey[50],
    borderRadius: BorderRadius.circular(16),
  );

  static final _orderButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppTheme.primary,
    foregroundColor: Colors.black87,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    elevation: 0,
  );

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _handlePlaceOrder(CartProvider cartProvider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      
      if (token == null || !isLoggedIn) {
        // Close cart before navigation
        widget.onClose();
        
        if (!mounted) return;
        
        // Show message and navigate to login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to place an order'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // Fetch existing address
      final savedAddress = await _orderService.getAddress(token);
      if (savedAddress != null) {
        _addressController.text = savedAddress;
      }

      setState(() {
        _showAddressPopup = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmOrder(BuildContext context, CartProvider cartProvider) async {
    if (_isOrdering) {
      _logger.info('Order placement already in progress, preventing duplicate submission');
      return;
    }

    // Add minimum order check
    if (cartProvider.totalAmount < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum order amount is ₹100'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a delivery address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() => _isOrdering = true);
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Update address in backend
      await _orderService.updateAddress(_addressController.text, token);

      final firstItem = cartProvider.items.first;
      final orderData = {
        'restaurant': firstItem.restaurantId,
        'restaurantName': firstItem.restaurantName,
        'items': cartProvider.items.map((item) => item.toJson()).toList(),
        'totalAmount': cartProvider.totalAmount,
        'address': _addressController.text,
      };

      await _orderService.placeOrder(
        items: cartProvider.items,
        restaurantId: firstItem.restaurantId,
        restaurantName: firstItem.restaurantName,
        totalAmount: cartProvider.totalAmount,
        address: _addressController.text,
        token: token,
      );

      // Show local notification for order placed
      await NotificationService().showLocalOrderPlacedNotification(
        firstItem.restaurantName,
        cartProvider.totalAmount,
      );

      cartProvider.clearCart();
      
      // Close the address dialog first
      if (mounted) {
        Navigator.pop(context);
        // Then close the cart widget
        widget.onClose();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOrdering = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final metrics = _UIMetrics(isSmallScreen);

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: _containerDecoration,
        child: Column(
          children: [
            _buildDragHandle(),
            _buildHeader(metrics),
            _buildCartItems(metrics),
            _buildFooter(metrics),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 40,
        height: 4,
        decoration: _dragHandleDecoration,
      ),
    );
  }

  Widget _buildHeader(_UIMetrics metrics) {
    return Container(
      decoration: BoxDecoration(
        gradient: _headerGradient,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: metrics.contentPadding,
        vertical: metrics.contentPadding * 0.75,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Consumer<CartProvider>(
            builder: (context, cart, _) => TextButton.icon(
              onPressed: cart.items.isEmpty ? null : cart.clearCart,
              icon: Icon(
                Icons.remove_shopping_cart_outlined,
                size: metrics.iconSize,
                color: Colors.black87,
              ),
              label: Text(
                'Clear',
                style: GoogleFonts.montserrat(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: metrics.subtitleSize,
                ),
              ),
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                color: Colors.black87,
                size: metrics.iconSize,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Cart',
                style: GoogleFonts.playfairDisplay(
                  fontSize: metrics.titleSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              _slideController.reverse().then((_) => widget.onClose());
            },
            icon: Icon(
              Icons.close,
              color: Colors.black87,
              size: metrics.iconSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems(_UIMetrics metrics) {
    return Expanded(
      child: Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      size: metrics.iconSize * 2,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: GoogleFonts.montserrat(
                      fontSize: metrics.titleSize * 0.8,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add some delicious items to get started!',
                    style: GoogleFonts.montserrat(
                      fontSize: metrics.subtitleSize,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(metrics.contentPadding),
            itemCount: cart.items.length,
            itemBuilder: (context, index) {
              final item = cart.items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildCartItem(item, cart, metrics.isSmallScreen),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCartItem(CartItem item, CartProvider cart, bool isSmallScreen) {
    final itemSize = isSmallScreen ? 14.0 : 16.0;
    final priceSize = isSmallScreen ? 16.0 : 18.0;

    return Container(
      decoration: _itemContainerDecoration,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.montserrat(
                      fontSize: itemSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Size: ${item.size}',
                    style: GoogleFonts.montserrat(
                      fontSize: itemSize * 0.9,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                    style: GoogleFonts.montserrat(
                      fontSize: priceSize,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: _quantityContainerDecoration,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => cart.removeItem(item.id, item.size),
                    icon: const Icon(Icons.remove),
                    color: AppTheme.primary,
                    iconSize: isSmallScreen ? 18 : 20,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      item.quantity.toString(),
                      style: GoogleFonts.montserrat(
                        fontSize: itemSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => cart.addItem(item),
                    icon: const Icon(Icons.add),
                    color: AppTheme.primary,
                    iconSize: isSmallScreen ? 18 : 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(_UIMetrics metrics) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) => Container(
        padding: EdgeInsets.all(metrics.contentPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Order Summary
            if (cart.items.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.all(metrics.contentPadding),
                decoration: _summaryContainerDecoration,
                child: Column(
                  children: [
                    _buildSummaryRow(
                      'Subtotal',
                      '₹${cart.totalAmount.toStringAsFixed(2)}',
                      metrics.isSmallScreen,
                    ),
                    if (cart.totalAmount < 100)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Add ₹${(100 - cart.totalAmount).toStringAsFixed(2)} more to place order',
                          style: GoogleFonts.montserrat(
                            fontSize: metrics.subtitleSize * 0.9,
                            color: Colors.red[400],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: metrics.contentPadding),
            ],

            // Place Order Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cart.items.isEmpty || _isOrdering ? null : () => _showAddressDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOrdering ? Colors.grey[300] : AppTheme.primary,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.black54,
                ).copyWith(
                  overlayColor: _isOrdering 
                    ? MaterialStateProperty.all(Colors.transparent)
                    : MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.pressed)) {
                          return Colors.black12;
                        }
                        return null;
                      }),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isOrdering) ...[
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Processing Order...',
                        style: GoogleFonts.montserrat(
                          fontSize: metrics.subtitleSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.local_shipping_outlined,
                        size: metrics.iconSize,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Place Order',
                        style: GoogleFonts.montserrat(
                          fontSize: metrics.subtitleSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddressDialog(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: !_isOrdering, // Prevent dismissing during order placement
      builder: (context) => WillPopScope(
        onWillPop: () async => !_isOrdering, // Prevent back button during order placement
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Delivery Address',
            style: GoogleFonts.playfairDisplay(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: _addressController,
            maxLines: 3,
            enabled: !_isOrdering, // Disable text field during order placement
            decoration: InputDecoration(
              hintText: 'Enter your delivery address...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primary, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isOrdering ? null : () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.montserrat(
                  color: _isOrdering ? Colors.grey.withOpacity(0.5) : Colors.grey
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _isOrdering ? null : () => _confirmOrder(context, cartProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isOrdering 
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Placing Order...',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Confirm Order',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isSmallScreen) {
    final textSize = isSmallScreen ? 14.0 : 16.0;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: textSize,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: textSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// Helper class to manage UI metrics
class _UIMetrics {
  final bool isSmallScreen;
  
  final double contentPadding;
  final double iconSize;
  final double titleSize;
  final double subtitleSize;
  final double itemSize;
  final double priceSize;

  _UIMetrics(this.isSmallScreen)
    : contentPadding = isSmallScreen ? 12.0 : 16.0,
      iconSize = isSmallScreen ? 20.0 : 24.0,
      titleSize = isSmallScreen ? 20.0 : 24.0,
      subtitleSize = isSmallScreen ? 14.0 : 16.0,
      itemSize = isSmallScreen ? 14.0 : 16.0,
      priceSize = isSmallScreen ? 16.0 : 18.0;
} 