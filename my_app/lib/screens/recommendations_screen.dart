import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/custom_navbar.dart';
import '../services/api_service.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../models/cart.dart';
import '../widgets/cart_button.dart';
import '../widgets/cart.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final GeminiService _geminiService = GeminiService();
  String? _selectedMood;
  bool _isLoading = false;
  List<Map<String, dynamic>> _recommendations = [];
  String? _userRole;
  bool _isLoggedIn = false;
  List<String> _orderHistory = [];
  List<String> _moodBasedCategories = [];
  
  // Animation controllers
  late final AnimationController _moodAnimationController;
  late final Animation<double> _backgroundScaleAnimation;
  late final Animation<double> _contentOpacityAnimation;
  late final AnimationController _cardAnimationController;
  late final Animation<double> _cardScaleAnimation;

  // Carousel controllers
  late final PageController _carouselController;
  late final AnimationController _sparkleController;
  late final AnimationController _reactionController;
  late final Animation<double> _sparkleAnimation;
  late final Animation<double> _reactionScale;
  int _currentCarouselIndex = 0;
  bool _showSparkle = false;

  // XP system
  late AnimationController _xpAnimationController;
  late Animation<double> _xpScaleAnimation;
  int _currentXP = 0;
  int _streakDays = 0;
  bool _hasSelectedMoodToday = false;
  List<Map<String, dynamic>> _achievements = [];
  Map<String, dynamic> _userProgress = {
    'foodExplorer': 0.0,
    'socialChef': 0,
  };

  // Add these variables to the state class
  bool _isPreloading = false;
  bool _hasPreloadedNextPage = false;
  final Map<String, bool> _preloadedImages = {};
  final Map<String, bool> _preloadedAnimations = {};
  late final AnimationController _loadingAnimationController;
  late final Animation<double> _loadingProgressAnimation;

  final List<Map<String, dynamic>> _moods = [
    {
      'name': 'Happy',
      'icon': '😊',
      'color': Color(0xFFFFD700),
      'gradient': [Color(0xFFFFD700), Color(0xFFFFB347)],
      'message': "Let's celebrate with some delicious food!",
      'animation': 'assets/animations/happy.json',
      'haptic': 'light',
    },
    {
      'name': 'Stressed',
      'icon': '😓',
      'color': Color(0xFF4A90E2),
      'gradient': [Color(0xFF4A90E2), Color(0xFF357ABD)],
      'message': 'Time for some comfort food to relax',
      'animation': 'assets/animations/stressed.json',
      'haptic': 'medium',
    },
    {
      'name': 'Tired',
      'icon': '😴',
      'color': Color(0xFF9B59B6),
      'gradient': [Color(0xFF9B59B6), Color(0xFF8E44AD)],
      'message': 'Boost your energy with these picks',
      'animation': 'assets/animations/tired.json',
      'haptic': 'light',
    },
    {
      'name': 'Healthy',
      'icon': '🥗',
      'color': Color(0xFF2ECC71),
      'gradient': [Color(0xFF2ECC71), Color(0xFF27AE60)],
      'message': 'Fresh and nutritious choices for you',
      'animation': 'assets/animations/healthy.json',
      'haptic': 'light',
    },
    {
      'name': 'Adventurous',
      'icon': '🌶️',
      'color': Color(0xFFE74C3C),
      'gradient': [Color(0xFFE74C3C), Color(0xFFC0392B)],
      'message': 'Try something new and exciting',
      'animation': 'assets/animations/adventurous.json',
      'haptic': 'medium',
    },
    {
      'name': 'Indecisive',
      'icon': '🤔',
      'color': Color(0xFFF1C40F),
      'gradient': [Color(0xFFF1C40F), Color(0xFFF39C12)],
      'message': "Let us help you decide what's best",
      'animation': 'assets/animations/indecisive.json',
      'haptic': 'light',
    },
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize all animation controllers
    _moodAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _reactionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _xpAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Initialize all animations
    _backgroundScaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _moodAnimationController,
      curve: Curves.easeOutBack,
    ));

    _contentOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _moodAnimationController,
      curve: Curves.easeIn,
    ));

    _cardScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOutBack,
    ));

    _sparkleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeOutBack,
    ));

    _reactionScale = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _reactionController,
      curve: Curves.easeOutBack,
    ));

    _xpScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _xpAnimationController,
      curve: Curves.easeOutBack,
    ));

    _loadingProgressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingAnimationController,
      curve: Curves.easeInOut,
    ));

    // Initialize carousel controller
    _carouselController = PageController(
      viewportFraction: 0.85,
      initialPage: 0,
    );

    // Start initial animations
    _moodAnimationController.forward();
    _cardAnimationController.forward();
    _loadingAnimationController.repeat(reverse: true);

    // Load user data and initialize other features
    _loadUserData();
    _loadXPData();
    _preloadInitialAssets();
  }

  @override
  void dispose() {
    // Dispose all animation controllers
    _moodAnimationController.dispose();
    _cardAnimationController.dispose();
    _sparkleController.dispose();
    _reactionController.dispose();
    _xpAnimationController.dispose();
    _loadingAnimationController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  void _initializeXPSystem() {
    _xpAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _xpScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(
      CurvedAnimation(
        parent: _xpAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    // Initialize achievements
    _achievements = [
      {
        'name': 'Daily Mood Streak',
        'icon': '🔥',
        'progress': _streakDays,
        'target': 7,
        'reward': 50,
      },
      {
        'name': 'Food Explorer',
        'icon': '🌍',
        'progress': _userProgress['foodExplorer'],
        'target': 1.0,
        'reward': 100,
      },
      {
        'name': 'Social Chef',
        'icon': '👥',
        'progress': _userProgress['socialChef'],
        'target': 5,
        'reward': 200,
      },
    ];

    _loadXPData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
        _userRole = prefs.getString('role');
      });
      
      // Load order history from shared preferences
      final history = prefs.getStringList('orderHistory') ?? [];
      setState(() {
        _orderHistory = history;
      });
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _updateMoodBasedCategories(String mood) async {
    try {
      final categories = await _geminiService.getMoodBasedCategories(mood);
      if (mounted && categories.isNotEmpty) {
        setState(() {
          _moodBasedCategories = categories;
        });
      }
    } catch (e) {
      print('Error getting mood-based categories: $e');
    }
  }

  Future<String> _getPersonalizedReason(Map<String, dynamic> item) async {
    try {
      final sizes = Map<String, dynamic>.from(item['sizes'] ?? {});
      final priceRange = sizes.isEmpty ? 0.0 : 
        sizes.values.reduce((curr, next) => 
          (curr as num) < (next as num) ? curr : next).toDouble();

      return await _geminiService.getPersonalizedRecommendation(
        mood: _selectedMood ?? 'neutral',
        category: item['category'] as String? ?? '',
        cuisine: item['cuisine'] as String? ?? 'various',
        orderHistory: _orderHistory,
        priceRange: priceRange,
      );
    } catch (e) {
      print('Error getting personalized reason: $e');
      return 'You might want to try this';
    }
  }

  Future<void> _loadRecommendations() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    try {
      if (_selectedMood != null) {
        await _updateMoodBasedCategories(_selectedMood!);
      }

      final response = await _apiService.getRecommendations(
        mood: _selectedMood,
      );
      
      if (!mounted) return;

      if (response['success']) {
        final recommendations = List<Map<String, dynamic>>.from(response['recommendations'] ?? []);
        
        final enhancedItems = recommendations.map((rec) {
          final item = rec['item'] as Map<String, dynamic>;
          final restaurant = item['restaurant'] as Map<String, dynamic>;
          
          return {
            'id': item['_id'] as String? ?? '',
            'name': item['name'] as String? ?? '',
            'restaurant': restaurant['name'] as String? ?? '',
            'restaurantId': restaurant['_id'] as String? ?? '',
            'imageUrl': item['imageUrl'] as String? ?? 'assets/images/placeholder.png',
            'description': item['description'] as String? ?? '',
            'category': item['category'] as String? ?? '',
            'sizes': Map<String, dynamic>.from(item['sizes'] ?? {}),
            'isAvailable': item['isAvailable'] ?? true,
            'reason': rec['reason'] as String? ?? 'You might want to try this',
            'score': rec['score'] as num? ?? 0,
          };
        }).toList();

        setState(() {
          _recommendations = [
            {
              'type': _selectedMood != null 
                ? 'Recommended for your ${_selectedMood!.toLowerCase()} mood' 
                : 'Personalized for you',
              'items': enhancedItems,
            },
          ];
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to load recommendations');
      }
    } catch (e) {
      print('Error loading recommendations: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error loading recommendations: ${e.toString()}',
            style: GoogleFonts.montserrat(),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  Future<void> _loadXPData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentXP = prefs.getInt('userXP') ?? 0;
        _streakDays = prefs.getInt('streakDays') ?? 0;
        _hasSelectedMoodToday = prefs.getBool('moodSelectedToday') ?? false;
        _userProgress['foodExplorer'] = prefs.getDouble('foodExplorerProgress') ?? 0.0;
        _userProgress['socialChef'] = prefs.getInt('socialChefProgress') ?? 0;
      });
    } catch (e) {
      print('Error loading XP data: $e');
    }
  }

  Future<void> _updateXP(int amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentXP += amount;
        prefs.setInt('userXP', _currentXP);
      });
      _xpAnimationController.forward(from: 0.0);
      HapticFeedback.mediumImpact();
    } catch (e) {
      print('Error updating XP: $e');
    }
  }

  Future<void> _updateStreak() async {
    if (_hasSelectedMoodToday) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMoodDate = prefs.getString('lastMoodDate');
      final today = DateTime.now().toIso8601String().split('T')[0];

      if (lastMoodDate != today) {
        setState(() {
          _streakDays++;
          _hasSelectedMoodToday = true;
        });

        await prefs.setString('lastMoodDate', today);
        await prefs.setInt('streakDays', _streakDays);
        await prefs.setBool('moodSelectedToday', true);

        // Award XP for daily streak
        _updateXP(50);
        
        // Show streak notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  '$_streakDays Day Streak! +50 XP',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error updating streak: $e');
    }
  }

  void _initializeLoadingAnimations() {
    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _loadingProgressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingAnimationController,
      curve: Curves.easeInOut,
    ));

    _loadingAnimationController.repeat(reverse: true);
  }

  Future<void> _preloadInitialAssets() async {
    setState(() => _isPreloading = true);
    try {
      // Preload mood animations in parallel
      await Future.wait(_moods.map((mood) async {
        final animationPath = mood['animation'] as String;
        if (!_preloadedAnimations.containsKey(animationPath)) {
          try {
            final assetBundle = DefaultAssetBundle.of(context);
            await assetBundle.load(animationPath);
            _preloadedAnimations[animationPath] = true;
          } catch (e) {
            print('Error preloading animation: $e');
          }
        }
      }));

      // Start loading recommendations in the background
      _loadRecommendations();
    } catch (e) {
      print('Error in preloading assets: $e');
    } finally {
      if (mounted) setState(() => _isPreloading = false);
    }
  }

  Future<void> _preloadNextPageImages() async {
    if (_hasPreloadedNextPage || _recommendations.isEmpty) return;

    try {
      final items = _recommendations.first['items'] as List<Map<String, dynamic>>;
      final nextIndex = _currentCarouselIndex + 1;
      
      if (nextIndex < items.length) {
        final nextItem = items[nextIndex];
        final imageUrl = nextItem['imageUrl'] as String?;
        
        if (imageUrl != null && 
            !imageUrl.startsWith('assets/') && 
            !_preloadedImages.containsKey(imageUrl)) {
          // Preload the next image
          final configuration = createLocalImageConfiguration(context);
          final imageProvider = NetworkImage(imageUrl);
          imageProvider.resolve(configuration);
          _preloadedImages[imageUrl] = true;
        }
        _hasPreloadedNextPage = true;
      }
    } catch (e) {
      print('Error preloading next page: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final isMediumScreen = screenSize.width < 600;
    
    // Responsive card sizing
    final cardWidth = isSmallScreen 
        ? screenSize.width * 0.42 
        : isMediumScreen 
            ? screenSize.width * 0.35
            : 200.0;
    
    final cardHeight = isSmallScreen 
        ? 260
        : isMediumScreen 
            ? 280
            : 300;

    final moodIconSize = isSmallScreen ? 24.0 : 32.0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Food Recommendations',
                style: GoogleFonts.playfairDisplay(
                  fontSize: isSmallScreen ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      _selectedMood != null 
                        ? (_moods.firstWhere((m) => m['name'] == _selectedMood)['gradient'] as List<Color>).first.withOpacity(0.1)
                        : Colors.white,
                    ],
                  ),
                ),
              ),
              centerTitle: true,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16,
                vertical: isSmallScreen ? 8 : 12,
              ),
              child: _buildMoodSelectionSection(isSmallScreen),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16,
                vertical: isSmallScreen ? 8 : 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildXPIndicator(isSmallScreen),
                  TextButton.icon(
                    onPressed: () {
                      // Show achievements dialog
                      showDialog(
                        context: context,
                        builder: (context) => _buildAchievementsDialog(isSmallScreen),
                      );
                    },
                    icon: const Icon(Icons.emoji_events),
                    label: Text(
                      'Achievements',
                      style: GoogleFonts.montserrat(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Finding the perfect food for your mood...',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_recommendations.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 100,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No recommendations available',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try selecting a different mood',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadRecommendations,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 8 : 12,
                ),
                child: _buildMealCarousel(
                  _recommendations.isNotEmpty 
                    ? (_recommendations.first['items'] as List<Map<String, dynamic>>)
                    : [],
                  isSmallScreen,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: CustomNavbar(
        isLoggedIn: _isLoggedIn,
        userRole: _userRole ?? '',
        onLogout: _handleLogout,
      ),
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cart, child) {
          return cart.itemCount > 0
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 16),
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
                )
              : const SizedBox.shrink();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildMoodSelectionSection(bool isSmallScreen) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenWidth < 360;
    final gridCrossAxisCount = screenWidth < 360 ? 2 : screenWidth < 600 ? 3 : 4;
    final gridSpacing = isVerySmallScreen ? 8.0 : isSmallScreen ? 12.0 : 16.0;
    final contentPadding = isVerySmallScreen ? 8.0 : isSmallScreen ? 12.0 : 16.0;

    return AnimatedBuilder(
      animation: _moodAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _backgroundScaleAnimation.value,
          child: Opacity(
            opacity: _contentOpacityAnimation.value,
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: contentPadding,
                horizontal: contentPadding * 0.75,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: contentPadding,
                      vertical: contentPadding * 0.5,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'How are you feeling today?',
                            style: GoogleFonts.montserrat(
                              fontSize: isVerySmallScreen ? 14 : isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (_selectedMood != null)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedMood = null;
                                _loadRecommendations();
                              });
                            },
                            icon: Icon(
                              Icons.refresh_rounded,
                              size: isVerySmallScreen ? 14 : isSmallScreen ? 16 : 18,
                              color: Colors.grey[600],
                            ),
                            label: Text(
                              'Reset',
                              style: GoogleFonts.montserrat(
                                color: Colors.grey[600],
                                fontSize: isVerySmallScreen ? 10 : isSmallScreen ? 12 : 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: contentPadding),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridCrossAxisCount,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: gridSpacing,
                      mainAxisSpacing: gridSpacing,
                    ),
                    itemCount: _moods.length,
                    itemBuilder: (context, index) {
                      final mood = _moods[index];
                      final isSelected = _selectedMood == mood['name'];
                      final emojiSize = isVerySmallScreen ? 24.0 : isSmallScreen ? 28.0 : 32.0;
                      final labelSize = isVerySmallScreen ? 10.0 : isSmallScreen ? 12.0 : 14.0;
                      
                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 200 + (index * 50)),
                        tween: Tween<double>(begin: 0, end: 1),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: GestureDetector(
                          onTap: () => _handleMoodSelection(mood),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isSelected 
                                  ? (mood['gradient'] as List<Color>)
                                  : [Colors.white, Colors.white],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? mood['color'] : Colors.grey[300]!,
                                width: isSelected ? 2 : 1.5,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: (mood['color'] as Color).withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 4),
                                  ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontSize: isSelected ? emojiSize * 1.2 : emojiSize,
                                  ),
                                  child: Text(mood['icon']),
                                ),
                                SizedBox(height: gridSpacing * 0.5),
                                Text(
                                  mood['name'],
                                  style: GoogleFonts.montserrat(
                                    color: isSelected ? Colors.white : Colors.grey[800],
                                    fontSize: labelSize,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    letterSpacing: 0.3,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMealCarousel(List<Map<String, dynamic>> items, bool isSmallScreen) {
    if (items.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenWidth < 360;
    final carouselHeight = isVerySmallScreen ? 360.0 : isSmallScreen ? 400.0 : 450.0;
    final imageHeight = isVerySmallScreen ? 160.0 : isSmallScreen ? 180.0 : 200.0;
    final contentPadding = isVerySmallScreen ? 8.0 : isSmallScreen ? 12.0 : 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: carouselHeight,
              child: PageView.builder(
                controller: _carouselController,
                onPageChanged: (index) {
                  setState(() {
                    _currentCarouselIndex = index;
                    _hasPreloadedNextPage = false;
                  });
                  _sparkleController.forward(from: 0.0);
                  _preloadNextPageImages();
                },
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isCurrentPage = _currentCarouselIndex == index;
                  
                  return AnimatedScale(
                    scale: isCurrentPage ? 1.0 : 0.9,
                    duration: const Duration(milliseconds: 300),
                    child: AnimatedOpacity(
                      opacity: isCurrentPage ? 1.0 : 0.7,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: contentPadding,
                          vertical: contentPadding * 0.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Image Section
                            SizedBox(
                              height: imageHeight,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                                child: Hero(
                                  tag: 'food_image_${item['id']}',
                                  child: Image.network(
                                    item['imageUrl'] ?? 'placeholder_url',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey[200],
                                      child: Center(
                                        child: Icon(
                                          Icons.restaurant,
                                          size: isVerySmallScreen ? 32 : isSmallScreen ? 40 : 48,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            // Content Section
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(contentPadding),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['name'] ?? 'Unnamed Item',
                                            style: GoogleFonts.montserrat(
                                              fontSize: isVerySmallScreen ? 16 : isSmallScreen ? 18 : 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: contentPadding,
                                            vertical: contentPadding * 0.25,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '₹${_getLowestPrice(item)}',
                                            style: GoogleFonts.montserrat(
                                              fontSize: isVerySmallScreen ? 12 : isSmallScreen ? 14 : 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: contentPadding * 0.5),
                                    Text(
                                      item['restaurant'] ?? 'Unknown Restaurant',
                                      style: GoogleFonts.montserrat(
                                        fontSize: isVerySmallScreen ? 12 : isSmallScreen ? 14 : 16,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Spacer(),
                                    _buildReactionButtons(isVerySmallScreen, isSmallScreen),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: contentPadding),
            _buildCarouselIndicator(items.length, isSmallScreen),
            if (_showSparkle && _currentCarouselIndex < items.length)
              _buildPerfectMatchBadge(items[_currentCarouselIndex], isSmallScreen),
          ],
        );
      },
    );
  }

  Widget _buildCarouselIndicator(int itemCount, bool isSmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        itemCount,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: _currentCarouselIndex == index ? 24 : 8,
          decoration: BoxDecoration(
            color: _currentCarouselIndex == index 
              ? AppTheme.primary 
              : Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildPerfectMatchBadge(Map<String, dynamic> item, bool isSmallScreen) {
    return AnimatedBuilder(
      animation: _sparkleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _sparkleAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary,
                  AppTheme.primary.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star,
                  color: Colors.white,
                  size: isSmallScreen ? 16 : 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Perfect Match!',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReactionButtons(bool isVerySmallScreen, bool isSmallScreen) {
    final buttonHeight = isVerySmallScreen ? 36.0 : isSmallScreen ? 40.0 : 44.0;
    final iconSize = isVerySmallScreen ? 18.0 : isSmallScreen ? 20.0 : 24.0;
    final fontSize = isVerySmallScreen ? 12.0 : isSmallScreen ? 14.0 : 16.0;
    final padding = isVerySmallScreen ? 8.0 : isSmallScreen ? 12.0 : 16.0;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: ElevatedButton.icon(
              onPressed: _handleAddToCart,
              icon: Icon(
                Icons.shopping_cart,
                size: iconSize,
                color: Colors.white,
              ),
              label: Text(
                'Add to Cart',
                style: GoogleFonts.montserrat(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(horizontal: padding),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
        SizedBox(width: padding),
        Container(
          height: buttonHeight,
          width: buttonHeight,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: _handleShare,
            icon: Icon(
              Icons.share,
              color: Colors.green,
              size: iconSize,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _handleAddToCart() async {
    if (!_isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please login to add items to cart',
            style: GoogleFonts.montserrat(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushNamed('/login');
      return;
    }

    try {
      final currentItem = _recommendations.first['items'][_currentCarouselIndex];
      
      // Get the lowest price size
      final sizes = Map<String, dynamic>.from(currentItem['sizes'] ?? {});
      if (sizes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This item is currently not available',
              style: GoogleFonts.montserrat(),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }

      // Find the size with the lowest price
      final lowestPriceEntry = sizes.entries.reduce((curr, next) => 
        (curr.value as num) < (next.value as num) ? curr : next);
      
      final selectedSize = lowestPriceEntry.key;
      final price = lowestPriceEntry.value;

      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      
      cartProvider.addItem(
        CartItem(
          id: currentItem['id']?.toString() ?? DateTime.now().toString(),
          name: currentItem['name'] ?? 'Unknown Item',
          price: (price as num).toDouble(),
          size: selectedSize,
          restaurantId: currentItem['restaurantId'] ?? '',
          restaurantName: currentItem['restaurant'] ?? 'Unknown Restaurant',
        ),
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${currentItem['name']} to cart',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Trigger haptic feedback
      HapticFeedback.mediumImpact();
      
      // Trigger sparkle animation
      _sparkleController.forward(from: 0.0);
      setState(() => _showSparkle = true);

    } catch (e) {
      print('Error adding to cart: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error adding item to cart: $e',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  double _getLowestPrice(Map<String, dynamic> item) {
    final sizes = Map<String, dynamic>.from(item['sizes'] ?? {});
    if (sizes.isEmpty) return 0.0;
    return sizes.values.reduce((curr, next) => 
      (curr as num) < (next as num) ? curr : next).toDouble();
  }

  void _handleItemTap(Map<String, dynamic> item) {
    setState(() => _showSparkle = true);
    _sparkleController.forward(from: 0.0);
    HapticFeedback.mediumImpact();
    
    // Show tooltip
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item['reason'] ?? 'A perfect match for your taste!',
          style: GoogleFonts.montserrat(),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _triggerHaptic(String type) {
    switch (type) {
      case 'light':
        HapticFeedback.lightImpact();
        break;
      case 'medium':
        HapticFeedback.mediumImpact();
        break;
      case 'heavy':
        HapticFeedback.heavyImpact();
        break;
      default:
        HapticFeedback.selectionClick();
    }
  }

  void _handleMoodSelection(Map<String, dynamic> mood) {
    _triggerHaptic(mood['haptic'] as String);
    setState(() => _selectedMood = mood['name'] as String);
    _loadRecommendations();
    _updateStreak();
  }

  void _handleShare() async {
    try {
      // ... existing share code ...

      // Update Social Chef progress
      final prefs = await SharedPreferences.getInstance();
      final currentProgress = _userProgress['socialChef'] as int;
      if (currentProgress < 5) {
        setState(() {
          _userProgress['socialChef'] = currentProgress + 1;
        });
        await prefs.setInt('socialChefProgress', currentProgress + 1);

        // Check if badge earned
        if (_userProgress['socialChef'] == 5) {
          _updateXP(200); // Award XP for completing the challenge
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Text('🥉'),
                  const SizedBox(width: 8),
                  Text(
                    'Social Chef Badge Earned! +200 XP',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      // ... rest of the existing share code ...
    } catch (e) {
      print('Error in share handler: $e');
    }
  }

  Widget _buildXPIndicator(bool isSmallScreen) {
    return AnimatedBuilder(
      animation: _xpScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _xpScaleAnimation.value,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: isSmallScreen ? 6 : 8,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber[700]!,
                  Colors.amber[500]!,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber[700]!.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.stars,
                  color: Colors.white,
                  size: isSmallScreen ? 16 : 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '$_currentXP XP',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_streakDays > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '🔥',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_streakDays',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 10 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAchievementsDialog(bool isSmallScreen) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your Achievements',
              style: GoogleFonts.playfairDisplay(
                fontSize: isSmallScreen ? 20 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ...List.generate(_achievements.length, (index) {
              final achievement = _achievements[index];
              final progress = achievement['progress'];
              final target = achievement['target'];
              final percent = progress is int 
                ? progress / target 
                : progress as double;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          achievement['icon'],
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                achievement['name'],
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallScreen ? 14 : 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: percent,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.amber[700]!,
                                  ),
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber[700],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '+${achievement['reward']} XP',
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 10 : 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isSmallScreen) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: isSmallScreen ? 200 : 250,
            child: AnimatedBuilder(
              animation: _loadingProgressAnimation,
              builder: (context, child) {
                return Column(
                  children: [
                    LinearProgressIndicator(
                      value: _loadingProgressAnimation.value,
                      backgroundColor: Colors.amber[100],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.amber[700]!,
                      ),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 16),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          Colors.amber[700]!,
                          Colors.amber[300]!,
                        ],
                        stops: [0.0, _loadingProgressAnimation.value],
                      ).createShader(bounds),
                      child: Text(
                        'Loading your personalized experience...',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          if (_isPreloading)
            Text(
              'Optimizing content for your device...',
              style: GoogleFonts.montserrat(
                fontSize: isSmallScreen ? 12 : 14,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }
} 