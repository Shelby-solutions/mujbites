import 'package:flutter/material.dart';
import '../widgets/custom_navbar.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/loading_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String? _errorMessage;
  String? _successMessage;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final ApiService _apiService = ApiService();
  String? _userRole;
  bool _isLoggedIn = false;

  // Add animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _mobileNumberController.dispose();
    _addressController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedRole = prefs.getString('role');
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      
      print('Loading user data in ProfileScreen:');
      print('Stored role: $storedRole');
      print('Is logged in: $isLoggedIn');
      
      if (mounted) {
        setState(() {
          _userRole = storedRole;
          _isLoggedIn = isLoggedIn;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
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

  Future<void> _fetchProfile() async {
    try {
      final response = await _apiService.getUserProfile();
      setState(() {
        _usernameController.text = response['username'] ?? '';
        _mobileNumberController.text = response['mobileNumber'] ?? '';
        _addressController.text = response['address'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    // Check if password update is requested
    final isPasswordUpdate = _oldPasswordController.text.isNotEmpty ||
        _newPasswordController.text.isNotEmpty ||
        _confirmPasswordController.text.isNotEmpty;

    // Validate password fields if updating password
    if (isPasswordUpdate) {
      if (_oldPasswordController.text.isEmpty) {
        setState(() => _errorMessage = 'Old password is required');
        return;
      }
      if (_newPasswordController.text.isEmpty) {
        setState(() => _errorMessage = 'New password is required');
        return;
      }
      if (_confirmPasswordController.text.isEmpty) {
        setState(() => _errorMessage = 'Confirm password is required');
        return;
      }
      if (_newPasswordController.text != _confirmPasswordController.text) {
        setState(() => _errorMessage = 'Passwords do not match');
        return;
      }
      // Check password requirements
      if (!RegExp(r'^(?=.*[A-Z])(?=.*\d)').hasMatch(_newPasswordController.text)) {
        setState(() => _errorMessage = 
          'Password must contain at least one capital letter and one number');
        return;
      }
    }

    try {
      await _apiService.updateProfile(
        address: _addressController.text,
        oldPassword: isPasswordUpdate ? _oldPasswordController.text : null,
        newPassword: isPasswordUpdate ? _newPasswordController.text : null,
      );

      setState(() {
        _successMessage = 'Profile updated successfully';
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to update profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingScreen();
    }

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
              // Custom App Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: isSmallScreen ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.settings,
                        color: AppTheme.primary,
                        size: isSmallScreen ? 24 : 28,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              // Profile Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Header
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: isSmallScreen ? 50 : 60,
                                backgroundColor: AppTheme.primary,
                                child: Text(
                                  _usernameController.text.isNotEmpty 
                                    ? _usernameController.text[0].toUpperCase()
                                    : 'U',
                                  style: GoogleFonts.montserrat(
                                    fontSize: isSmallScreen ? 32 : 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _usernameController.text,
                                style: GoogleFonts.montserrat(
                                  fontSize: isSmallScreen ? 20 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _userRole?.toUpperCase() ?? 'USER',
                                style: GoogleFonts.montserrat(
                                  fontSize: isSmallScreen ? 12 : 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.primary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Notification Messages
                        if (_errorMessage != null)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.montserrat(
                                      color: Colors.red.shade700,
                                      fontSize: isSmallScreen ? 13 : 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (_successMessage != null)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _successMessage!,
                                    style: GoogleFonts.montserrat(
                                      color: Colors.green.shade700,
                                      fontSize: isSmallScreen ? 13 : 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Personal Information Section
                        _buildSectionCard(
                          title: 'Personal Information',
                          icon: Icons.person,
                          isSmallScreen: isSmallScreen,
                          children: [
                            _buildTextField(
                              _usernameController,
                              'Username',
                              enabled: false,
                              icon: Icons.account_circle,
                              isSmallScreen: isSmallScreen,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              _mobileNumberController,
                              'Mobile Number',
                              enabled: false,
                              icon: Icons.phone,
                              isSmallScreen: isSmallScreen,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              _addressController,
                              'Address',
                              icon: Icons.location_on,
                              isSmallScreen: isSmallScreen,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Security Section
                        _buildSectionCard(
                          title: 'Security',
                          icon: Icons.security,
                          isSmallScreen: isSmallScreen,
                          children: [
                            _buildTextField(
                              _oldPasswordController,
                              'Old Password',
                              isPassword: true,
                              icon: Icons.lock_outline,
                              isSmallScreen: isSmallScreen,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              _newPasswordController,
                              'New Password',
                              isPassword: true,
                              icon: Icons.lock,
                              isSmallScreen: isSmallScreen,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              _confirmPasswordController,
                              'Confirm New Password',
                              isPassword: true,
                              icon: Icons.lock_clock,
                              isSmallScreen: isSmallScreen,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 16 : 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Save Changes',
                              style: GoogleFonts.montserrat(
                                fontSize: isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool isSmallScreen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: AppTheme.primary,
                size: isSmallScreen ? 24 : 28,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool enabled = true,
    bool isPassword = false,
    required IconData icon,
    required bool isSmallScreen,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: isPassword,
      style: GoogleFonts.montserrat(
        fontSize: isSmallScreen ? 14 : 16,
        color: enabled ? Colors.black87 : Colors.grey[600],
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.montserrat(
          fontSize: isSmallScreen ? 14 : 16,
          color: Colors.grey[600],
        ),
        prefixIcon: Icon(
          icon,
          color: enabled ? AppTheme.primary : Colors.grey[400],
          size: isSmallScreen ? 20 : 24,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.primary,
            width: 2,
          ),
        ),
        filled: !enabled,
        fillColor: enabled ? Colors.transparent : Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isSmallScreen ? 12 : 16,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }
}

// Settings Screen with updated design
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _openTermsOfUse() async {
    final Uri url = Uri.parse('https://archive.org/details/muj-bites-terms-of-use');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final Uri url = Uri.parse('https://archive.org/details/muj-bites-privacy-policy');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.playfairDisplay(
            fontSize: isSmallScreen ? 20 : 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
      ),
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
        child: ListView(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
          children: [
            // Terms of Use Button
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: Icon(
                  Icons.description_outlined,
                  color: AppTheme.primary,
                  size: isSmallScreen ? 24 : 28,
                ),
                title: Text(
                  'Terms of Use',
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                trailing: Icon(
                  Icons.open_in_new,
                  color: Colors.grey[400],
                  size: isSmallScreen ? 20 : 24,
                ),
                onTap: _openTermsOfUse,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 24,
                  vertical: isSmallScreen ? 8 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Privacy Policy Button
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: Icon(
                  Icons.privacy_tip_outlined,
                  color: AppTheme.primary,
                  size: isSmallScreen ? 24 : 28,
                ),
                title: Text(
                  'Privacy Policy',
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                trailing: Icon(
                  Icons.open_in_new,
                  color: Colors.grey[400],
                  size: isSmallScreen ? 20 : 24,
                ),
                onTap: _openPrivacyPolicy,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 24,
                  vertical: isSmallScreen ? 8 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            
            // Logout Button
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Colors.red[400],
                  size: isSmallScreen ? 24 : 28,
                ),
                title: Text(
                  'Logout',
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.red[400],
                  ),
                ),
                onTap: () => _logout(context),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 24,
                  vertical: isSmallScreen ? 8 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}