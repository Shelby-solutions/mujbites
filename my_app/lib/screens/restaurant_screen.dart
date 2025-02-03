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
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:ui';

class RestaurantScreen extends StatefulWidget {
  final String restaurantId;

  const RestaurantScreen({super.key, required this.restaurantId});

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

// Add new import for animations

class _RestaurantScreenState extends State<RestaurantScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Add scroll controller and offset
  late ScrollController _scrollController;
  double _scrollOffset = 0;
  
  // Add these missing variables
  Map<String, dynamic>? _restaurant;
  List<Map<String, dynamic>> _menu = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        if (mounted) {  // Add mounted check
          setState(() {
            _scrollOffset = _scrollController.offset;
          });
        }
      });
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    // Add error handling for data fetching
    _fetchRestaurantData().catchError((error) {
      if (mounted) {
        setState(() {
          _error = 'Failed to connect to server. Please check your internet connection.';
          _isLoading = false;
        });
      }
    });
    _animationController.forward();
  }

  // Keep only this enhanced version of _fetchRestaurantData
  Future<void> _fetchRestaurantData() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);
      
      final response = await _apiService.getRestaurantById(widget.restaurantId)
          .timeout(const Duration(seconds: 10));
      
      if (!mounted) return;
      
      if (response is Map<String, dynamic>) {
        final menuItems = response['menu'];
        
        setState(() {
          _restaurant = response;
          if (menuItems is List) {
            _menu = menuItems.map((item) {
              try {
                final sizesMap = item['sizes'] as Map<String, dynamic>;
                final sizesList = sizesMap.entries.map((entry) => {
                  'name': entry.key,
                  'price': entry.value,
                }).toList();
                
                return {
                  'id': item['_id'],
                  'name': item['itemName'],
                  'price': sizesMap.values.first,
                  'sizes': sizesList,
                  'category': item['category'] ?? 'Other',
                  'imageUrl': item['imageUrl'],
                  'isAvailable': item['isAvailable'] ?? true,
                  'description': item['description'] ?? '',
                };
              } catch (e) {
                return null;
              }
            }).whereType<Map<String, dynamic>>().toList();
          }
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load restaurant data. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Add controller disposal
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingScreen());
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Text(
            _error!,
            style: GoogleFonts.montserrat(
              color: AppTheme.error,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.white.withOpacity(0.7),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: TextField(
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search menu items...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CartButton(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => CartWidget(
                                  onClose: () => Navigator.pop(context),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      // Removed duplicate appBar and extendBodyBehindAppBar declarations
      floatingActionButton: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: Offset(0, _scrollOffset > 100 ? 0 : 2),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _scrollOffset > 100 ? 1 : 0,
          child: CartButton(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => CartWidget(onClose: () => Navigator.pop(context)),
              );
            },
          ),
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'restaurant-${widget.restaurantId}',
                    child: Image.network(
                      _restaurant?['imageUrl'] ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: Icon(Icons.restaurant, color: Colors.grey.shade400, size: 60),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Update the search and filter section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search menu items...',
                        hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade600),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Category Filters
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = _selectedCategory == category;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: FilterChip(
                              selected: isSelected,
                              label: Text(category),
                              onSelected: (_) => setState(() => _selectedCategory = category),
                              backgroundColor: Colors.white,
                              selectedColor: AppTheme.primary,
                              checkmarkColor: Colors.white,
                              labelStyle: GoogleFonts.montserrat(
                                color: isSelected ? Colors.white : AppTheme.textSecondary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              elevation: isSelected ? 4 : 0,
                              pressElevation: 2,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Update the menu grid styling
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: MediaQuery.of(context).size.width > 600 ? 0.8 : 0.7,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _animationController,
                      curve: Interval(
                        0.4 + (index * 0.1),
                        1.0,
                        curve: Curves.easeOut,
                      ),
                    )),
                    child: _buildMenuItemCard(_filteredItems[index]),
                  ),
                ),
                childCount: _filteredItems.length,
              ),
            ),
          ),

          // Responsibility Disclaimer
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Note: The products may not exactly match the images displayed. Actual products may vary.',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Update the _buildMenuItem method
  Widget _buildMenuItem(Map<String, dynamic> item) {
    final isAvailable = item['isAvailable'] ?? true;
    final sizes = List<Map<String, dynamic>>.from(item['sizes'] ?? []);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  item['imageUrl'] ?? '',
                  height: 100, // Reduced height
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 100, // Match the image height
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.restaurant,
                      color: Colors.grey.shade400,
                      size: 40,
                    ),
                  ),
                ),
              ),
              if (!isAvailable)
                Container(
                  height: 100, // Match the image height
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Center(
                    child: Text(
                      'Currently Unavailable',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8), // Reduced padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['name'] ?? '',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 14, // Reduced font size
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₹${item['price']?.toString() ?? '0'}',
                        style: GoogleFonts.montserrat(
                          fontSize: 12, // Reduced font size
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (sizes.isNotEmpty) ...[
                    const SizedBox(height: 4), // Reduced spacing
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 2,
                          runSpacing: 2,
                          children: sizes.map((size) {
                            return Chip(
                              label: Text(
                                '${size['name']} - ₹${size['price']}',
                                style: const TextStyle(fontSize: 10), // Reduced font size
                              ),
                              backgroundColor: Colors.grey.shade100,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4), // Reduced spacing
                  SizedBox(
                    width: double.infinity,
                    height: 32, // Fixed height for button
                    child: ElevatedButton(
                      onPressed: isAvailable ? () => _addToCart(item) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        isAvailable ? 'Add to Cart' : 'Not Available',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold,
                          fontSize: 12, // Reduced font size
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addToCart(Map<String, dynamic> item) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    try {
      // Safely get values with null checks
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
          restaurantName: restaurantName, // Added restaurant name
        ),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added $itemName to cart',
            style: GoogleFonts.montserrat(),
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to add item to cart: ${e.toString()}',
            style: GoogleFonts.montserrat(),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Add these getter methods
  List<String> get _categories {
    final categories = _menu
        .map((item) => item['category'].toString())
        .toSet()
        .toList();
    return ['All', ...categories];
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _menu.where((item) {
      final matchesSearch = item['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || item['category'] == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  // Enhanced menu item card with animations and tap functionality
  Widget _buildAnimatedMenuItemCard(Map<String, dynamic> item) {
    return AnimationConfiguration.staggeredGrid(
      position: _menu.indexOf(item),
      duration: const Duration(milliseconds: 375),
      columnCount: 2,
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: _buildMenuItemCard(item)
        ),
      ),
    );
  }

  void _showItemDetails(Map<String, dynamic> item) {
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
            // Item image with gradient overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.network(
                    item['imageUrl'] ?? '',
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: Icon(Icons.restaurant, color: Colors.grey.shade400, size: 60),
                    ),
                  ),
                ),

                // Add gradient overlay
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.5),
                      ],
                    ),
                  ),
                ),
                // Close button with background
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
            // Item details
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? '',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item['description']?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 8),
                      Text(
                        item['description'],
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Size selection
                    if (item['sizes']?.isNotEmpty ?? false) ...[
                      Text(
                        'Available Sizes',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (item['sizes'] as List).map((size) {
                          return ChoiceChip(
                            label: Text('${size['name']} - ₹${size['price']}'),
                            selected: false,
                            onSelected: (_) {},
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Add to cart button
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  _addToCart(item);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Add to Cart',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Base menu item card with content and tap handler
  Widget _buildMenuItemCard(Map<String, dynamic> item) {
    final isAvailable = item['isAvailable'] ?? true;
    final sizes = List<Map<String, dynamic>>.from(item['sizes'] ?? []);

    return GestureDetector(
      onTap: () => _showItemDetails(item),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    item['imageUrl'] ?? '',
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 100,
                      width: double.infinity,
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.restaurant,
                        color: Colors.grey.shade400,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                if (!isAvailable)
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Center(
                      child: Text(
                        'Currently Unavailable',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['name'] ?? '',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₹${item['price']?.toString() ?? '0'}',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    if (sizes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 2,
                            runSpacing: 2,
                            children: sizes.map((size) {
                              return Chip(
                                label: Text(
                                  '${size['name']} - ₹${size['price']}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                                backgroundColor: Colors.grey.shade100,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: isAvailable ? () => _addToCart(item) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isAvailable ? 'Add to Cart' : 'Not Available',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
