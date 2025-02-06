import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  String? _errorMessage;

  final ApiService _apiService = ApiService();
  
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

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      _showError('Please agree to the terms and conditions');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _apiService.register(
        _nameController.text,
        _mobileController.text,
        _passwordController.text,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Please login.')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _launchTerms() async {
    final Uri url = Uri.parse('https://archive.org/details/termsandconditions_202501');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.platformDefault,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open terms and conditions')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening terms and conditions')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    super.dispose();
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
                          Icons.person_add,
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
                          'Create Account',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign up to get started',
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
                              _buildFormField(
                                controller: _nameController,
                                label: 'Full Name',
                                icon: Icons.person_outline,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your name';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: contentPadding),
                              _buildFormField(
                                controller: _mobileController,
                                label: 'Phone Number',
                                icon: Icons.phone_outlined,
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
                              _buildFormField(
                                controller: _passwordController,
                                label: 'Password',
                                icon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                showPasswordToggle: true,
                                onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
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
                              SizedBox(height: contentPadding),
                              _buildFormField(
                                controller: _confirmPasswordController,
                                label: 'Confirm Password',
                                icon: Icons.lock_outline,
                                obscureText: _obscureConfirmPassword,
                                showPasswordToggle: true,
                                onTogglePassword: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: contentPadding),

                              // Enhanced Terms Checkbox
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey[200]!,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _agreeToTerms,
                                        onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
                                        activeColor: AppTheme.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: _launchTerms,
                                        child: Text(
                                          'I agree to the terms and conditions',
                                          style: GoogleFonts.montserrat(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Enhanced Error Display
                              if (_errorMessage != null) ...[
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
                                          _errorMessage!,
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

                              // Enhanced Sign Up Button
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
                                    onPressed: _isLoading ? null : _handleSignup,
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
                                                'Creating Account...',
                                                style: GoogleFonts.montserrat(
                                                  color: Colors.grey[800],
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            'Sign Up',
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

                      // Enhanced Sign In Link
                      SizedBox(height: contentPadding),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text.rich(
                          TextSpan(
                            text: 'Already have an account? ',
                            style: GoogleFonts.montserrat(
                              color: Colors.grey[600],
                              fontSize: subtitleSize * 0.9,
                            ),
                            children: [
                              TextSpan(
                                text: 'Sign in',
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

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool showPasswordToggle = false,
    VoidCallback? onTogglePassword,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
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
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: GoogleFonts.montserrat(
              fontSize: 15,
              color: Colors.grey[800],
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
              suffixIcon: showPasswordToggle
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      onPressed: onTogglePassword,
                    )
                  : null,
              hintText: 'Enter your ${label.toLowerCase()}',
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
        ),
      ],
    );
  }
} 