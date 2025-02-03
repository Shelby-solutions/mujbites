import 'package:flutter/material.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomNavbar extends StatelessWidget {
  final String userRole;
  final bool isLoggedIn;
  final VoidCallback onLogout;

  const CustomNavbar({
    super.key,
    required this.userRole,
    required this.isLoggedIn,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _getCurrentIndex(context),
      onTap: (index) => _onItemTapped(index, context),
      selectedItemColor: const Color(0xFFFAC744),
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        if (userRole == 'restaurant')
          const BottomNavigationBarItem(
            icon: Icon(Icons.restaurant),
            label: 'Restaurant Panel',
          ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'Orders',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  void _onItemTapped(int index, BuildContext context) {
    print('\n=== NavBar Item Tapped ===');
    print('Index: $index');
    print('Current role: $userRole');
    print('Is logged in: $isLoggedIn');

    if (!isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        if (userRole == 'restaurant') {
          Navigator.pushReplacementNamed(context, '/restaurant-panel');
        } else {
          Navigator.pushReplacementNamed(context, '/orders');
        }
        break;
      case 2:
        if (userRole == 'restaurant') {
          Navigator.pushReplacementNamed(context, '/orders');
        } else {
          Navigator.pushReplacementNamed(context, '/profile');
        }
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  int _getCurrentIndex(BuildContext context) {
    final String currentRoute = ModalRoute.of(context)?.settings.name ?? '/';
    
    switch (currentRoute) {
      case '/home':
        return 0;
      case '/restaurant-panel':
        return userRole == 'restaurant' ? 1 : 0;
      case '/orders':
        return userRole == 'restaurant' ? 2 : 1;
      case '/profile':
        return userRole == 'restaurant' ? 3 : 2;
      default:
        return 0;
    }
  }
} 