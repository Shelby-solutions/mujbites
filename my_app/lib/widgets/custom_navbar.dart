import 'package:flutter/material.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class CustomNavbar extends StatelessWidget {
  final bool isLoggedIn;
  final String userRole;
  final VoidCallback onLogout;

  // Cache styles and decorations
  static final _defaultTextStyle = GoogleFonts.montserrat(
    fontSize: 12,
    color: Colors.grey[600],
  );

  static final _activeTextStyle = GoogleFonts.montserrat(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: AppTheme.primary,
  );

  static final _containerDecoration = BoxDecoration(
    color: Colors.white,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, -5),
      ),
    ],
  );

  static const _itemPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static final _itemBorderRadius = BorderRadius.circular(12);

  const CustomNavbar({
    super.key,
    required this.isLoggedIn,
    required this.userRole,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _containerDecoration,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                route: '/home',
                onTap: () => _handleNavigation(context, '/home'),
              ),
              if (isLoggedIn && userRole != 'restaurant')
                _NavItem(
                  icon: Icons.recommend_outlined,
                  label: 'For You',
                  route: '/recommendations',
                  onTap: () => _handleNavigation(context, '/recommendations'),
                ),
              if (isLoggedIn) ...[
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Orders',
                  route: '/orders',
                  onTap: () => _handleNavigation(context, '/orders'),
                ),
                if (userRole == 'restaurant')
                  _NavItem(
                    icon: Icons.restaurant_menu_outlined,
                    label: 'Restaurant',
                    route: '/restaurant-panel',
                    onTap: () => _handleNavigation(context, '/restaurant-panel'),
                  ),
                _NavItem(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  route: '/profile',
                  onTap: () => _handleNavigation(context, '/profile'),
                ),
              ] else
                _NavItem(
                  icon: Icons.login_outlined,
                  label: 'Login',
                  route: '/login',
                  onTap: () => _handleNavigation(context, '/login'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, String route) {
    final isCurrentRoute = ModalRoute.of(context)?.settings.name == route;
    if (!isCurrentRoute) {
      Navigator.pushReplacementNamed(context, route);
    }
  }
}

// Separate stateless widget for nav items to optimize rebuilds
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrentRoute = ModalRoute.of(context)?.settings.name == route;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: CustomNavbar._itemBorderRadius,
        child: Container(
          padding: CustomNavbar._itemPadding,
          decoration: BoxDecoration(
            color: isCurrentRoute ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: CustomNavbar._itemBorderRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isCurrentRoute ? AppTheme.primary : Colors.grey[600],
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: isCurrentRoute 
                  ? CustomNavbar._activeTextStyle 
                  : CustomNavbar._defaultTextStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 