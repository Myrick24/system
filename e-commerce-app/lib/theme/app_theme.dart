import 'package:flutter/material.dart';

class AppTheme {
  // Primary Green Color Scheme (main theme)
  static const Color primaryGreen = Color(0xFF4CAF50); // Green shade 500
  static const Color primaryGreenLight = Color(0xFF81C784); // Green shade 400
  static const Color primaryGreenDark = Color(0xFF388E3C); // Green shade 700

  // Secondary Colors
  static const Color accentBlue =
      Color(0xFF2196F3); // Blue for secondary actions
  static const Color accentOrange =
      Color(0xFFFF9800); // Orange for warnings/notifications
  static const Color accentPurple =
      Color(0xFF9C27B0); // Purple for payment/premium features

  // Neutral Colors
  static const Color backgroundColor =
      Color(0xFFFAFAFA); // Light grey background
  static const Color surfaceColor = Color(0xFFFFFFFF); // White surface
  static const Color onSurfaceColor = Color(0xFF212121); // Dark text
  static const Color secondaryTextColor = Color(0xFF757575); // Grey text

  // Status Colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);

  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: _createMaterialColor(primaryGreen),
      primaryColor: primaryGreen,
      primaryColorLight: primaryGreenLight,
      primaryColorDark: primaryGreenDark,

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Card Theme
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: surfaceColor,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        primaryContainer: primaryGreenLight,
        secondary: accentBlue,
        secondaryContainer: Color(0xFFE3F2FD),
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: onSurfaceColor,
        onBackground: onSurfaceColor,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: backgroundColor,

      // Text Theme
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: onSurfaceColor,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: onSurfaceColor,
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: onSurfaceColor,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: onSurfaceColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: onSurfaceColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: onSurfaceColor,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: onSurfaceColor,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: secondaryTextColor,
          fontSize: 12,
        ),
      ),
    );
  }

  // Helper method to create MaterialColor from a single color
  static MaterialColor _createMaterialColor(Color color) {
    List<double> strengths = <double>[.05];
    Map<int, Color> swatch = <int, Color>{};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (double strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }

  // Gradient styles for cards and containers
  static BoxDecoration primaryGradientDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryGreenLight, primaryGreenDark],
    ),
    boxShadow: [
      BoxShadow(
        color: primaryGreen.withOpacity(0.3),
        spreadRadius: 2,
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration successGradientDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryGreen.withOpacity(0.8), primaryGreen],
    ),
    boxShadow: [
      BoxShadow(
        color: primaryGreen.withOpacity(0.3),
        spreadRadius: 2,
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration warningGradientDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [accentOrange.withOpacity(0.8), accentOrange],
    ),
    boxShadow: [
      BoxShadow(
        color: accentOrange.withOpacity(0.3),
        spreadRadius: 2,
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
