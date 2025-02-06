import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_preferences.dart';
import 'dart:ui';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _showPassword = false;
  String? _error;
  
  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutBack,
    ));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.login(
        _mobileController.text,
        _passwordController.text,
      );

      if (response['success']) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', response['token']);
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('role', response['user']['role']);
        await prefs.setString('userId', response['user']['_id']);
        await prefs.setString('username', response['user']['username']);
        
        if (response['user']['restaurant'] != null) {
          await prefs.setString('restaurantId', response['user']['restaurant']['_id']);
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        throw Exception(response['message'] ?? 'Login failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final contentPadding = isSmallScreen ? 20.0 : 24.0;
    final logoSize = isSmallScreen ? 40.0 : 48.0;
    final titleSize = isSmallScreen ? 28.0 : 32.0;
    final subtitleSize = isSmallScreen ? 16.0 : 18.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.amber[50]!,
              Colors.white,
              Colors.amber[50]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(contentPadding),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Enhanced Logo Section
                      Container(
                        padding: EdgeInsets.all(contentPadding),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.restaurant_menu,
                          size: logoSize,
                          color: AppTheme.primary,
                        ),
                      ),
                      SizedBox(height: contentPadding),

                      // Enhanced Welcome Text
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.black87,
                            Colors.black54,
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'Welcome back',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to your account',
                        style: GoogleFonts.montserrat(
                          color: Colors.grey[600],
                          fontSize: subtitleSize,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: contentPadding),

                      // Enhanced Form Section
                      Container(
                        padding: EdgeInsets.all(contentPadding),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel('Phone Number'),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _mobileController,
                                icon: Icons.phone,
                                hint: 'Enter your phone number',
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your phone number';
                                  }
                                  if (value.length != 10) {
                                    return 'Phone number must be 10 digits';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: contentPadding),
                              _buildInputLabel('Password'),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _passwordController,
                                icon: Icons.lock_outline,
                                hint: 'Enter your password',
                                isPassword: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),

                              // Enhanced Error Display
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red[100]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.red[400],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: GoogleFonts.montserrat(
                                            color: Colors.red[700],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Enhanced Login Button
                              SizedBox(height: contentPadding),
                              SizedBox(
                                width: double.infinity,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: LinearGradient(
                                      colors: _isLoading
                                          ? [Colors.grey[300]!, Colors.grey[400]!]
                                          : [AppTheme.primary, AppTheme.primary.withOpacity(0.8)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.black87,
                                      elevation: 0,
                                      padding: EdgeInsets.symmetric(
                                        vertical: contentPadding * 0.75,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    Colors.grey[800]!,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Signing In...',
                                                style: GoogleFonts.montserrat(
                                                  color: Colors.grey[800],
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            'Sign In',
                                            style: GoogleFonts.montserrat(
                                              color: Colors.black87,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Enhanced Sign Up Link
                      SizedBox(height: contentPadding),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/signup'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text.rich(
                          TextSpan(
                            text: "Don't have an account? ",
                            style: GoogleFonts.montserrat(
                              color: Colors.grey[600],
                              fontSize: subtitleSize * 0.9,
                            ),
                            children: [
                              TextSpan(
                                text: 'Sign up',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Enhanced Footer
                      SizedBox(height: contentPadding),
                      Text(
                        '© 2025 MujBites. All rights reserved.',
                        style: GoogleFonts.montserrat(
                          color: Colors.grey[500],
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey[700],
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !_showPassword,
        keyboardType: keyboardType,
        style: GoogleFonts.montserrat(
          fontSize: 15,
          color: Colors.grey[800],
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                )
              : null,
          hintText: hint,
          hintStyle: GoogleFonts.montserrat(
            color: Colors.grey[400],
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        validator: validator,
      ),
    );
  }
} 