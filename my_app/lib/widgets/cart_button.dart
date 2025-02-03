import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CartButton extends StatelessWidget {
  final VoidCallback onTap;

  const CartButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.shopping_cart),
      onPressed: onTap,
      color: AppTheme.primary,
    );
  }
} 