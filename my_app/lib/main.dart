import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/restaurant_screen.dart';
import 'screens/restaurant_panel_screen.dart';
import 'screens/recommendations_screen.dart';
import 'theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'providers/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/custom_navbar.dart';
import 'services/user_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';  // This was auto-generated
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final token = prefs.getString('token');
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await UserPreferences.init();
  
  // Initialize sqflite database
  final databasesPath = await getDatabasesPath();
  final path = join(databasesPath, 'cache.db');
  await openDatabase(path, version: 1);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MyApp(initialRoute: isLoggedIn && token != null ? '/home' : '/login'),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MujBites',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primary),
        useMaterial3: true,
        textTheme: TextTheme(
          displayLarge: AppTheme.textTheme.displayLarge,
          displayMedium: AppTheme.textTheme.displayMedium,
          bodyLarge: AppTheme.textTheme.bodyLarge,
          titleLarge: AppTheme.textTheme.titleLarge,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: AppTheme.primaryButton,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            borderSide: const BorderSide(color: AppTheme.textPrimary, width: 2),
          ),
        ),
      ),
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const HomeScreen(),
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/orders': (context) => const OrdersScreen(),
        '/restaurant-panel': (context) => const RestaurantPanelScreen(),
        '/recommendations': (context) => const RecommendationsScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle dynamic routes
        if (settings.name?.startsWith('/restaurant/') ?? false) {
          final restaurantId = settings.name!.split('/').last;
          return MaterialPageRoute(
            builder: (context) => RestaurantScreen(restaurantId: restaurantId),
          );
        }
        return null;
      },
    );
  }
}
