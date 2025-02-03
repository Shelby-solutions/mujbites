import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors - Luxury palette
  static const Color primary = Color(0xFFFFB300); // Gold
  static const Color secondary = Color(0xFFFFF3D6); // Cream
  static const Color background = Color(0xFFFFFBF5); // Warm white
  static const Color navBackground = Color(0xFFFFF8E7); // Creamy white
  static const Color textPrimary = Color(0xFF2C2C2C); // Rich black
  static const Color textSecondary = Color(0xFF757575); // Sophisticated gray
  static const Color accent = Color(0xFF6C63FF); // Vibrant accent
  static const Color success = Color(0xFF4CAF50); // Emerald
  static const Color error = Color(0xFFE53935); // Ruby

  // Spacing - Consistent scale for layout
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;

  // Border Radius - More refined scale
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 20.0;
  static const double radiusXL = 28.0;

  // Breakpoints - Optimized for modern devices
  static const double mobileBreakpoint = 480.0;
  static const double tabletBreakpoint = 820.0;
  static const double desktopBreakpoint = 1200.0;

  // Animation Durations - Smoother transitions
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationDefault = Duration(milliseconds: 350);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Typography - Elegant font combinations
  static final TextTheme textTheme = TextTheme(
    // Hero text
    displayLarge: GoogleFonts.playfairDisplay(
      fontSize: 48,
      fontWeight: FontWeight.bold,
      color: textPrimary,
      height: 1.2,
      letterSpacing: -0.5,
    ),
    // Section headings
    displayMedium: GoogleFonts.playfairDisplay(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: textPrimary,
      letterSpacing: -0.3,
    ),
    // Card titles
    titleLarge: GoogleFonts.montserrat(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      letterSpacing: 0.15,
    ),
    // Body text
    bodyLarge: GoogleFonts.montserrat(
      fontSize: 16,
      color: textSecondary,
      height: 1.5,
    ),
  );

  // Input Decoration - Refined search bar
  static final searchInputDecoration = InputDecoration(
    hintText: 'Search dishes...',
    prefixIcon: const Icon(Icons.search, color: textSecondary),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: primary.withOpacity(0.2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: primary.withOpacity(0.2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(color: primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 12,
    ),
    hintStyle: GoogleFonts.montserrat(
      color: textSecondary,
      fontSize: 14,
    ),
  );

  // Button Styles - Elegant interaction
  static final ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: textPrimary,
    padding: const EdgeInsets.symmetric(
      horizontal: 32,
      vertical: 16,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 4,
    shadowColor: primary.withOpacity(0.4),
  ).copyWith(
    overlayColor: MaterialStateProperty.resolveWith<Color?>(
      (states) => states.contains(MaterialState.hovered) 
          ? primary.withOpacity(0.9) 
          : null,
    ),
  );

  // Card Theme - Sophisticated elevation
  static final cardTheme = CardTheme(
    elevation: 8,
    shadowColor: Colors.black.withOpacity(0.1),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    margin: const EdgeInsets.all(8),
  );

  // Navigation Bar Theme
  static final appBarTheme = AppBarTheme(
    backgroundColor: navBackground,
    elevation: 4,
    shadowColor: Colors.black.withOpacity(0.1),
    titleTextStyle: GoogleFonts.playfairDisplay(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: textPrimary,
    ),
    iconTheme: const IconThemeData(
      color: textPrimary,
      size: 24,
    ),
  );

  // Transitions
  static const Duration quickTransition = Duration(milliseconds: 200);
  static const Duration normalTransition = Duration(milliseconds: 300);

  // Shadows
  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get emphasizedShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // Helper methods for responsive design
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768 &&
      MediaQuery.of(context).size.width < 1024;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  static EdgeInsets getScreenPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(24);
    }
    return const EdgeInsets.all(32);
  }
}