import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class CartButton extends StatelessWidget {
  final int itemCount;
  final VoidCallback onPressed;

  // Cache decorations and styles
  static final _buttonDecoration = BoxDecoration(
    color: Colors.black87,
    borderRadius: BorderRadius.circular(30),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static final _arrowContainerDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
  );

  static final _textStyle = GoogleFonts.montserrat(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const _iconSize = 24.0;
  static const _arrowIconSize = 16.0;
  static const _contentPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const _iconSpacing = SizedBox(width: 8);

  const CartButton({
    super.key,
    required this.itemCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: _contentPadding,
          decoration: _buttonDecoration,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shopping_cart_outlined,
                color: Colors.white,
                size: _iconSize,
              ),
              _iconSpacing,
              Text(
                '$itemCount items',
                style: _textStyle,
              ),
              _iconSpacing,
              Container(
                padding: const EdgeInsets.all(6),
                decoration: _arrowContainerDecoration,
                child: const Icon(
                  Icons.arrow_forward,
                  color: Colors.black87,
                  size: _arrowIconSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 