import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CartButton extends StatelessWidget {
  final int itemCount;
  final VoidCallback onPressed;

  const CartButton({
    Key? key,
    required this.itemCount,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              '$itemCount items',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.black87,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 