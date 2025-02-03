import 'package:flutter/material.dart';

class AuthTheme {
  // Modern color palette with luxury gold accents
  static const inputFocus = Color(0xFFFFD700); // Rich gold
  static const fontColor = Color(0xFF1A1A1A); // Deep black
  static const fontColorSub = Color(0xFF4A4A4A); // Softer dark gray
  static const bgColor = Color(0xF5FFFFFF); // Slightly transparent white
  static const mainColor = Color(0xFF2C2C2C); // Charcoal black
  static const buttonColor = Color(0xFFFFD700); // Rich gold
  static const shadowColor = Color(0x40000000); // Soft shadow

  static InputDecoration inputDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(prefixIcon, color: fontColorSub),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: mainColor, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: mainColor.withOpacity(0.5), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: inputFocus, width: 2),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.95),
      labelStyle: TextStyle(
        color: fontColorSub,
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    );
  }

  static ButtonStyle elevatedButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: buttonColor,
      foregroundColor: fontColor,
      padding: const EdgeInsets.symmetric(vertical: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: mainColor.withOpacity(0.2), width: 1),
      ),
      elevation: 8,
      shadowColor: shadowColor,
    ).copyWith(
      overlayColor: MaterialStateProperty.resolveWith<Color?>(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.pressed)) {
            return buttonColor.withOpacity(0.8);
          }
          return null;
        },
      ),
    );
  }

  static TextStyle headerStyle() {
    return const TextStyle(
      color: fontColor,
      fontSize: 32,
      fontWeight: FontWeight.w800,
      fontFamily: 'Poppins',
      letterSpacing: -0.5,
    );
  }

  static TextStyle subHeaderStyle() {
    return const TextStyle(
      color: fontColorSub,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      fontFamily: 'Poppins',
      letterSpacing: 0.2,
    );
  }
}