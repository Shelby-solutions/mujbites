import 'package:flutter/material.dart';
import 'package:my_app/models/cart.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../services/order_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class CartWidget extends StatefulWidget {
  final VoidCallback onClose;

  const CartWidget({super.key, required this.onClose});

  @override
  State<CartWidget> createState() => _CartWidgetState();
}

class _CartWidgetState extends State<CartWidget> with SingleTickerProviderStateMixin {
  final TextEditingController _addressController = TextEditingController();
  bool _showAddressPopup = false;
  bool _isOrdering = false;
  final OrderService _orderService = OrderService();
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
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

      cartProvider.clearCart();
      
      // Close the address dialog first
      Navigator.pop(context);
      // Then close the cart widget
      widget.onClose();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order placed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
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
    final contentPadding = isSmallScreen ? 12.0 : 16.0;
    final iconSize = isSmallScreen ? 20.0 : 24.0;
    final titleSize = isSmallScreen ? 20.0 : 24.0;
    final subtitleSize = isSmallScreen ? 14.0 : 16.0;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary,
                    AppTheme.primary.withOpacity(0.8),
                  ],
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: contentPadding,
                vertical: contentPadding * 0.75,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Consumer<CartProvider>(
                    builder: (context, cart, _) => TextButton.icon(
                      onPressed: cart.items.isEmpty ? null : cart.clearCart,
                      icon: Icon(
                        Icons.remove_shopping_cart_outlined,
                        size: iconSize,
                        color: Colors.black87,
                      ),
                      label: Text(
                        'Clear',
                        style: GoogleFonts.montserrat(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                          fontSize: subtitleSize,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.black87,
                        size: iconSize,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Your Cart',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: titleSize,
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
                      size: iconSize,
                    ),
                  ),
                ],
              ),
            ),

            // Cart Items
            Expanded(
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
                              size: iconSize * 2,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Your cart is empty',
                            style: GoogleFonts.montserrat(
                              fontSize: titleSize * 0.8,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add some delicious items to get started!',
                            style: GoogleFonts.montserrat(
                              fontSize: subtitleSize,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(contentPadding),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildCartItem(item, cart, isSmallScreen),
                      );
                    },
                  );
                },
              ),
            ),

            // Footer
            Consumer<CartProvider>(
              builder: (context, cart, _) => Container(
                padding: EdgeInsets.all(contentPadding),
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
                        padding: EdgeInsets.all(contentPadding),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _buildSummaryRow(
                              'Subtotal',
                              '₹${cart.totalAmount.toStringAsFixed(2)}',
                              isSmallScreen,
                            ),
                            if (cart.totalAmount < 100)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Add ₹${(100 - cart.totalAmount).toStringAsFixed(2)} more to place order',
                                  style: GoogleFonts.montserrat(
                                    fontSize: subtitleSize * 0.9,
                                    color: Colors.red[400],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: contentPadding),
                    ],

                    // Place Order Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: cart.items.isEmpty ? null : () => _showAddressDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black87,
                          padding: EdgeInsets.symmetric(
                            vertical: contentPadding,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              size: iconSize,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Place Order',
                              style: GoogleFonts.montserrat(
                                fontSize: subtitleSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(CartItem item, CartProvider cart, bool isSmallScreen) {
    final itemSize = isSmallScreen ? 14.0 : 16.0;
    final priceSize = isSmallScreen ? 16.0 : 18.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
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

  void _showAddressDialog(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.montserrat(color: Colors.grey),
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
            child: Text(
              _isOrdering ? 'Placing Order...' : 'Confirm Order',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 