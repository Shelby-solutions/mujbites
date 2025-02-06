import 'package:flutter/material.dart';
import '../widgets/custom_navbar.dart';
import '../widgets/cart_button.dart';
import '../widgets/cart.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_preferences.dart';
import '../widgets/loading_screen.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _userRole;
  bool _isLoggedIn = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _restaurants = [];
  String? _error;
  
  // Animation controller for search bar
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchRestaurants();
    _setupAutoRefresh();
    
    // Initialize search animation
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    );
    _searchAnimationController.forward();
  }

  @override
  void dispose() {
    _searchAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final role = await UserPreferences.getRole();
      final isLoggedIn = await UserPreferences.isLoggedIn();
      
      print('Loading user data in HomeScreen:');
      print('Role from storage: $role');
      print('Is logged in: $isLoggedIn');
      
      if (mounted) {
        setState(() {
          _userRole = role;
          _isLoggedIn = isLoggedIn;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  void _setupAutoRefresh() {
    Future.delayed(const Duration(minutes: 5), () {
      if (mounted) {
        _fetchRestaurants();
        _setupAutoRefresh();
      }
    });
  }

  Future<void> _fetchRestaurants() async {
    try {
      final restaurants = await _apiService.getAllRestaurants();
      if (mounted) {
        setState(() {
          _restaurants = restaurants.where((r) => r['isActive'] == true).toList();
          _restaurants.sort((a, b) {
            if (a['name'].toLowerCase() == "chaizza") return -1;
            if (b['name'].toLowerCase() == "chaizza") return 1;
            return 0;
          });
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error fetching restaurants. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredRestaurants {
    if (_searchQuery.isEmpty) return _restaurants;
    return _restaurants.where((restaurant) {
      return restaurant['name']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _handleLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      print('Logout error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.amber[50]!,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Enhanced Header Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Restaurants',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: isSmallScreen ? 28 : 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        _buildCartButton(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Animated Search Bar
                    FadeTransition(
                      opacity: _searchAnimation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, -0.2),
                          end: Offset.zero,
                        ).animate(_searchAnimation),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            onChanged: (value) => setState(() => _searchQuery = value),
                            style: GoogleFonts.montserrat(
                              fontSize: isSmallScreen ? 14 : 16,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search restaurants...',
                              hintStyle: GoogleFonts.montserrat(
                                color: Colors.grey.shade400,
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: AppTheme.primary,
                                size: isSmallScreen ? 20 : 24,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: _isLoading
                    ? const LoadingScreen()
                    : _error != null
                        ? _buildErrorView()
                        : _buildRestaurantGrid(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomNavbar(
        isLoggedIn: _isLoggedIn,
        userRole: _userRole ?? '',
        onLogout: _handleLogout,
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'An error occurred',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchRestaurants,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              'Try Again',
              style: GoogleFonts.montserrat(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return GridView.builder(
      padding: EdgeInsets.all(screenWidth < 400 ? 8 : 16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1024 ? 3 : 2,
        childAspectRatio: screenWidth < 400 ? 0.75 : 0.85,
        crossAxisSpacing: screenWidth < 400 ? 8 : 16,
        mainAxisSpacing: screenWidth < 400 ? 8 : 16,
      ),
      itemCount: _filteredRestaurants.length,
      itemBuilder: (context, index) {
        final restaurant = _filteredRestaurants[index];
        return _buildRestaurantCard(restaurant);
      },
    );
  }

  Widget _buildRestaurantCard(Map<String, dynamic> restaurant) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isVerySmallScreen = screenWidth < 400;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.pushNamed(context, '/restaurant/${restaurant['_id']}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Restaurant Image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: AspectRatio(
                  aspectRatio: 1.5,
                  child: Hero(
                    tag: 'restaurant_${restaurant['_id']}',
                    child: Image.network(
                      restaurant['imageUrl'] ?? 'placeholder_url',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: Icon(
                            Icons.restaurant,
                            size: isVerySmallScreen ? 24 : isSmallScreen ? 32 : 40,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[100],
                          child: Center(
                            child: SizedBox(
                              width: isVerySmallScreen ? 20 : 24,
                              height: isVerySmallScreen ? 20 : 24,
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: isVerySmallScreen ? 2 : 3,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              
              // Restaurant Info
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(isVerySmallScreen ? 8 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        restaurant['name'],
                        style: GoogleFonts.playfairDisplay(
                          fontSize: isVerySmallScreen ? 14 : isSmallScreen ? 16 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isVerySmallScreen ? 4 : 8),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: isVerySmallScreen ? 12 : isSmallScreen ? 14 : 16,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: isVerySmallScreen ? 2 : 4),
                            Expanded(
                              child: Text(
                                restaurant['address'],
                                style: GoogleFonts.montserrat(
                                  color: Colors.grey[600],
                                  fontSize: isVerySmallScreen ? 10 : isSmallScreen ? 12 : 14,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildCartButton() {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        final hasItems = cart.itemCount > 0;
        
        return Container(
          margin: const EdgeInsets.only(left: 8),
          child: Material(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(30),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => CartWidget(onClose: () => Navigator.pop(context)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    if (hasItems) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          cart.itemCount.toString(),
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
} 