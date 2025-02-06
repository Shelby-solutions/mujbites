import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/custom_navbar.dart';
import '../widgets/cart_button.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../models/cart.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/cart.dart';
import '../widgets/loading_screen.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math' as math;
import 'dart:io';

class RestaurantScreen extends StatefulWidget {
  final String restaurantId;

  const RestaurantScreen({super.key, required this.restaurantId});

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _restaurant;
  List<Map<String, dynamic>> _menu = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fetchRestaurantData();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchRestaurantData() async {
    try {
      setState(() => _isLoading = true);
      
      final response = await _apiService.getRestaurantById(widget.restaurantId);
      print('Raw response: $response'); // Debug print
      
      if (response is Map<String, dynamic>) {
        final menuItems = response['menu'];
        print('Menu items type: ${menuItems.runtimeType}'); // Debug print
        print('Menu items content: $menuItems'); // Debug print
        
        setState(() {
          _restaurant = response;
          if (menuItems is List) {
            _menu = menuItems.map((item) {
              // Convert sizes object to list of maps
              final sizesMap = item['sizes'] as Map<String, dynamic>;
              final sizesList = sizesMap.entries.map((entry) => {
                'name': entry.key,
                'price': entry.value,
              }).toList();
              
              return {
                'id': item['_id'],
                'name': item['itemName'],
                'price': sizesMap.values.first, // Use smallest size price as default
                'sizes': sizesList,
                'category': item['category'] ?? 'Other',
                'imageUrl': item['imageUrl'],
                'isAvailable': item['isAvailable'] ?? true,
              };
            }).toList();
          } else {
            _menu = [];
          }
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      print('Error fetching restaurant data: $e');
      setState(() {
        _error = 'Failed to load restaurant data';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _menu.where((item) {
      final matchesSearch = item['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || item['category'] == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<String> get _categories {
    final categories = _menu.map((item) => item['category'].toString()).toSet().toList();
    return ['All', ...categories];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingScreen());
    }

    if (_error != null) {
      return _buildErrorScreen();
    }

    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(isSmallScreen),
              SliverToBoxAdapter(
                child: _buildRestaurantInfo(isSmallScreen),
              ),
              _buildCategoryList(),
              _buildSearchBar(isSmallScreen),
              _buildMenuList(isSmallScreen),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: bottomPadding + 80,
                ),
              ),
            ],
          ),
          _buildFloatingCart(),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppTheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Oops! Something went wrong',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: GoogleFonts.montserrat(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchRestaurantData,
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
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool isSmallScreen) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'restaurant_${widget.restaurantId}',
              child: CachedNetworkImage(
                imageUrl: _restaurant?['imageUrl'] ?? '',
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: Icon(
                    Icons.restaurant_rounded,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                ),
                memCacheWidth: 800,
                memCacheHeight: 500,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _restaurant?['name'] ?? '',
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 28 : 32,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '4.5',
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '• Open',
                          style: GoogleFonts.montserrat(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantInfo(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_restaurant?['address'] != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: AppTheme.primary,
                      size: isSmallScreen ? 20 : 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _restaurant!['address'],
                      style: GoogleFonts.montserrat(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'Menu',
            style: GoogleFonts.playfairDisplay(
              fontSize: isSmallScreen ? 24 : 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return SliverToBoxAdapter(
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = category == _selectedCategory;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedCategory = category);
                },
                backgroundColor: Colors.white,
                selectedColor: AppTheme.primary.withOpacity(0.2),
                checkmarkColor: AppTheme.primary,
                labelStyle: GoogleFonts.montserrat(
                  color: isSelected ? AppTheme.primary : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primary : Colors.grey[300]!,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isSmallScreen) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
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
              hintText: 'Search menu items...',
              hintStyle: GoogleFonts.montserrat(
                color: Colors.grey[400],
                fontSize: isSmallScreen ? 14 : 16,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppTheme.primary,
                size: isSmallScreen ? 20 : 24,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuList(bool isSmallScreen) {
    if (_filteredItems.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.no_meals_rounded,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No items found',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              if (_searchQuery.isNotEmpty || _selectedCategory != 'All') ...[
                const SizedBox(height: 8),
                Text(
                  'Try adjusting your filters',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = _filteredItems[index];
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(
                    (index / _filteredItems.length) * 0.6,
                    math.min(1.0, (index / _filteredItems.length) * 0.6 + 0.4),
                    curve: Curves.easeOut,
                  ),
                )),
                child: MenuItemCard(
                  name: item['name'] ?? '',
                  description: item['sizes']?.first['name'] ?? '',
                  price: item['price']?.toDouble() ?? 0.0,
                  imageUrl: item['imageUrl'] ?? '',
                  sizes: List<Map<String, dynamic>>.from(item['sizes'] ?? []),
                  onAddToCart: () => _addToCart(item),
                  isSmallScreen: isSmallScreen,
                ),
              ),
            );
          },
          childCount: _filteredItems.length,
        ),
      ),
    );
  }

  Widget _buildFloatingCart() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          bottom: cart.itemCount > 0 ? bottomPadding + 16 : -100,
          left: 24,
          right: 24,
          child: CartButton(
            itemCount: cart.itemCount,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => CartWidget(onClose: () => Navigator.pop(context)),
              );
            },
          ),
        );
      },
    );
  }

  void _addToCart(Map<String, dynamic> item) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    try {
      final itemId = item['_id']?.toString() ?? item['id']?.toString();
      final itemName = item['name']?.toString() ?? 'Unknown Item';
      final itemPrice = (item['price'] ?? 0).toDouble();
      final restaurantName = _restaurant?['name']?.toString() ?? 'Unknown Restaurant';

      if (itemId == null) {
        throw Exception('Invalid item data');
      }

      final selectedSize = item['sizes'] != null && (item['sizes'] as List).isNotEmpty
          ? (item['sizes'] as List).first
          : {'name': 'Regular', 'price': itemPrice};

      cartProvider.addItem(
        CartItem(
          id: itemId,
          name: itemName,
          price: (selectedSize['price'] as num).toDouble(),
          size: selectedSize['name']?.toString() ?? 'Regular',
          restaurantId: widget.restaurantId,
          restaurantName: restaurantName,
        ),
      );
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Added $itemName to cart',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 1500),
          backgroundColor: AppTheme.success.withOpacity(0.95),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.1,
            left: 16,
            right: 16,
          ),
          elevation: 4,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Failed to add item to cart',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 2000),
          backgroundColor: AppTheme.error.withOpacity(0.95),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.1,
            left: 16,
            right: 16,
          ),
          elevation: 4,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      );
    }
  }
}

class MenuItemCard extends StatelessWidget {
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final VoidCallback onAddToCart;
  final List<Map<String, dynamic>> sizes;
  final bool isSmallScreen;

  const MenuItemCard({
    Key? key,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.onAddToCart,
    required this.isSmallScreen,
    this.sizes = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final density = MediaQuery.of(context).devicePixelRatio;
    
    final cardHeight = screenHeight < 700 ? 110.0 :
                      screenWidth < 360 ? 110.0 : 
                      screenWidth < 400 ? 120.0 :
                      screenWidth < 600 ? 130.0 : 140.0;
    
    final imageSize = screenHeight < 700 ? 70.0 :
                     screenWidth < 360 ? 70.0 :
                     screenWidth < 400 ? 80.0 :
                     screenWidth < 600 ? 90.0 : 100.0;
    
    final titleFontSize = screenHeight < 700 ? 13.0 :
                         screenWidth < 360 ? 13.0 :
                         screenWidth < 400 ? 14.0 :
                         screenWidth < 600 ? 15.0 : 16.0;
    
    final descFontSize = screenHeight < 700 ? 11.0 :
                        screenWidth < 360 ? 11.0 :
                        screenWidth < 400 ? 12.0 :
                        screenWidth < 600 ? 13.0 : 14.0;

    final horizontalPadding = screenWidth < 360 ? 8.0 :
                             screenWidth < 400 ? 10.0 :
                             screenWidth < 600 ? 12.0 : 16.0;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: screenHeight < 700 ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showItemDetails(context),
          child: SizedBox(
            height: cardHeight,
            child: Padding(
              padding: EdgeInsets.all(screenWidth < 400 ? 8 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Hero(
                    tag: 'menu_item_$name',
                    child: Container(
                      width: imageSize,
                      height: imageSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[100],
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[100],
                            child: Icon(
                              Icons.restaurant_rounded,
                              size: imageSize * 0.4,
                              color: Colors.grey[400],
                            ),
                          ),
                          memCacheWidth: (imageSize * MediaQuery.of(context).devicePixelRatio).toInt(),
                          memCacheHeight: (imageSize * MediaQuery.of(context).devicePixelRatio).toInt(),
                          maxWidthDiskCache: 800,
                          maxHeightDiskCache: 800,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth < 400 ? 8 : 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.montserrat(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (description.isNotEmpty) ...[
                              SizedBox(height: screenWidth < 400 ? 2 : 4),
                              Text(
                                description,
                                style: GoogleFonts.montserrat(
                                  fontSize: descFontSize,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '₹${price.toStringAsFixed(2)}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: titleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: onAddToCart,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black87,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: screenWidth < 400 ? 12 : 16,
                                      vertical: screenWidth < 400 ? 4 : 6,
                                    ),
                                    minimumSize: Size(screenWidth < 400 ? 50 : 60, 0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: Text(
                                    'ADD',
                                    style: GoogleFonts.montserrat(
                                      fontSize: descFontSize,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showItemDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                Hero(
                  tag: 'menu_item_$name',
                  child: Container(
                    height: 250,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[100],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[100],
                        child: Icon(
                          Icons.restaurant_rounded,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                      ),
                      memCacheWidth: 800,
                      memCacheHeight: 500,
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: Colors.white,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Available Sizes',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sizes.map((size) => ChoiceChip(
                      label: Text(
                        '${size['name']} - ₹${size['price']}',
                        style: GoogleFonts.montserrat(),
                      ),
                      selected: false,
                      onSelected: (_) {
                        Navigator.pop(context);
                        onAddToCart();
                      },
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}