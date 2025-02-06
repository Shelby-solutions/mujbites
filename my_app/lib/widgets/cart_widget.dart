import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class CartWidget extends StatelessWidget {
  final VoidCallback onClose;

  const CartWidget({Key? key, required this.onClose}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: Consumer<CartProvider>(
              builder: (context, cart, child) {
                if (cart.items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, 
                          size: 64, 
                          color: Colors.grey[400]
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your cart is empty',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return _buildCartItems(context, cart);
              },
            ),
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            'Your Cart',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            color: Colors.black87,
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems(BuildContext context, CartProvider cart) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: cart.items.length,
      separatorBuilder: (context, index) => const Divider(height: 24),
      itemBuilder: (context, index) {
        final item = cart.items[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Size: ${item.size}',
                    style: GoogleFonts.montserrat(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '₹${item.price.toStringAsFixed(2)}',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: () => cart.removeItem(item.id, item.size),
                    color: Colors.black87,
                  ),
                  Text(
                    '${item.quantity}',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () => cart.addItem(item),
                    color: Colors.black87,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Consumer<CartProvider>(
        builder: (context, cart, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₹${cart.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: cart.items.isEmpty ? null : () {
                    // Handle checkout
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'PROCEED TO CHECKOUT',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
} 