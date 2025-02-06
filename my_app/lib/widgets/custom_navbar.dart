import 'package:flutter/material.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class CustomNavbar extends StatelessWidget {
  final bool isLoggedIn;
  final String userRole;
  final VoidCallback onLogout;

  const CustomNavbar({
    Key? key,
    required this.isLoggedIn,
    required this.userRole,
    required this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);
    
    return Container(
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
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: BottomNavigationBar(
            elevation: 0,
            backgroundColor: Colors.white.withOpacity(0.9),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppTheme.primary,
            unselectedItemColor: Colors.grey.shade600,
            selectedLabelStyle: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            currentIndex: currentIndex,
            onTap: (index) => _onItemTapped(context, index),
            items: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                isSelected: currentIndex == 0,
              ),
              _buildNavItem(
                icon: Icons.recommend_outlined,
                activeIcon: Icons.recommend_rounded,
                label: 'For You',
                isSelected: currentIndex == 1,
              ),
              _buildNavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'Orders',
                isSelected: currentIndex == 2,
              ),
              if (userRole == 'restaurant')
                _buildNavItem(
                  icon: Icons.restaurant_outlined,
                  activeIcon: Icons.restaurant_rounded,
                  label: 'Restaurant',
                  isSelected: currentIndex == 3,
                ),
              _buildNavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                isSelected: userRole == 'restaurant' ? currentIndex == 4 : currentIndex == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
  }) {
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: isSelected ? 20 : 0,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
      activeIcon: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Icon(
              activeIcon,
              size: 24,
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: isSelected ? 20 : 0,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
      label: label,
    );
  }

  int _getCurrentIndex(BuildContext context) {
    final String currentRoute = ModalRoute.of(context)?.settings.name ?? '/';
    switch (currentRoute) {
      case '/':
      case '/home':
        return 0;
      case '/recommendations':
        return 1;
      case '/orders':
        return 2;
      case '/restaurant-panel':
        return userRole == 'restaurant' ? 3 : 0;
      case '/profile':
        return userRole == 'restaurant' ? 4 : 3;
      default:
        return 0;
    }
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/recommendations');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/orders');
        break;
      case 3:
        if (userRole == 'restaurant') {
          Navigator.pushReplacementNamed(context, '/restaurant-panel');
        } else {
          Navigator.pushReplacementNamed(context, '/profile');
        }
        break;
      case 4:
        if (userRole == 'restaurant') {
          Navigator.pushReplacementNamed(context, '/profile');
        }
        break;
    }
  }
} 