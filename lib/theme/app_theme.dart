import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PremiumTheme {
  // ─── Brand Colors ───
  static const Color orangePrimary = Color(0xFFF2540D); // From code.html
  static const Color orangeDark = Color(0xFFE85A2A);
  static const Color darkBg = Color(0xFF0F1115); // From code.html
  static const Color cardBg = Colors.white;
  static const Color surfaceBg = Color(
    0xFFFFFFFF,
  ); // From code.html background-light
  static const Color greyText = Color(0xFF666666);
  static const Color greyLight = Color(0xFFF5F5F5);
  static const Color greyBorder = Color(0xFFE0E0E0);

  // ─── Gradient Colors ───
  static const Color gradientOrangeStart = Color(0xFFFF7A18);
  static const Color gradientOrangeEnd = Color(0xFFFF4D00);
  static const Color gradientGoldStart = Color(0xFFFFD700);
  static const Color gradientGoldEnd = Color(0xFFFFA500);

  // ─── Gradient ───
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [gradientOrangeStart, gradientOrangeEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [gradientGoldStart, gradientGoldEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Spacing ───
  static const double spacingXS = 4;
  static const double spacingSM = 8;
  static const double spacingMD = 16;
  static const double spacingLG = 24;
  static const double spacingXL = 32;
  static const double spacingXXL = 48;

  // ─── Border Radius ───
  static const double radiusSM = 12;
  static const double radiusMD = 20;
  static const double radiusLG = 24;
  static const double radiusXL = 28;

  // ─── Button Heights ───
  static const double buttonHeight = 52;

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: orangePrimary,
      brightness: Brightness.light,
      primary: orangePrimary,
      onPrimary: Colors.white,
      surface: cardBg,
      onSurface: darkBg,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      primaryColor: orangePrimary,
      scaffoldBackgroundColor: surfaceBg,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,

      // ─── Text Theme ───
      textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 56,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.1,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 40,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.15,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: darkBg,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: darkBg,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: darkBg,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkBg,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          color: darkBg,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: greyText,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // ─── AppBar Theme ───
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark, // For Android (Dark icons)
          statusBarBrightness: Brightness.light, // For iOS (Dark icons)
        ),
        toolbarHeight: 72,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      // ─── Card Theme ───
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
        ),
      ),

      // ─── Dialog Theme ───
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: darkBg,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: greyText,
        ),
      ),

      // ─── Elevated Button Theme ───
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orangePrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSM),
          ),
          elevation: 0,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),

      // ─── Outlined Button Theme ───
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: orangePrimary,
          minimumSize: const Size(0, buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSM),
          ),
          side: const BorderSide(
            color: orangePrimary,
            width: 1.5,
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),

      // ─── Text Button Theme ───
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: orangePrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
      ),

      // ─── Input Decoration Theme ───
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: greyLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: BorderSide(color: greyBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: BorderSide(color: greyBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: orangePrimary, width: 1.5),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF9E9E9E),
          fontSize: 14,
        ),
      ),
    );
  }
}
