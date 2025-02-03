import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/cart_provider.dart';
import 'package:provider/provider.dart';

class CartButton extends StatelessWidget {
  final VoidCallback onTap;

  const CartButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Update the CartButton widget
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
        color: Colors.black,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.shopping_cart,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Consumer<CartProvider>(
                  builder: (context, cart, child) => Text(
                    'Cart (${cart.itemCount})',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}