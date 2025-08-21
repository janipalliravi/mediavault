import 'package:flutter/material.dart';
import 'spacing.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData build({required bool dark, Color seed = const Color(0xFF1877F2), bool amoled = false, double fontScale = 1.0}) {
    
    if (dark) {
      // Dark theme
      final darkBase = ThemeData.dark(useMaterial3: true);
      final darkColorScheme = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      );
      
      final textTheme = GoogleFonts.poppinsTextTheme(darkBase.textTheme,).copyWith(
        headlineSmall: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.poppins(),
        bodyMedium: GoogleFonts.poppins(),
      );
      
      return darkBase.copyWith(
        colorScheme: darkColorScheme,
        scaffoldBackgroundColor: amoled ? Colors.black : const Color(0xFF121212),
        textTheme: textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: seed,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ThemeSpacing.radius12),
            borderSide: const BorderSide(color: Color(0xFF404040)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white54),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: const TextStyle(color: Colors.white),
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFF2A2A2A)),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeSpacing.radius12)),
        ),
        chipTheme: darkBase.chipTheme.copyWith(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeSpacing.radius12)),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      );
    } else {
      // Light theme
      final lightBase = ThemeData.light(useMaterial3: true);
      final lightColorScheme = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
      );
      
      final textTheme = GoogleFonts.poppinsTextTheme(lightBase.textTheme).copyWith(
        headlineSmall: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.poppins(),
        bodyMedium: GoogleFonts.poppins(),
      );
      
      return lightBase.copyWith(
        colorScheme: lightColorScheme,
        scaffoldBackgroundColor: const Color(0xFFEFF2F5),
        textTheme: textTheme.apply(bodyColor: Colors.black87, displayColor: Colors.black87),
        appBarTheme: AppBarTheme(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: seed,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThemeSpacing.radius12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          labelStyle: const TextStyle(color: Colors.black87),
          hintStyle: const TextStyle(color: Colors.black54),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: const TextStyle(color: Colors.black87),
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(Colors.white),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeSpacing.radius12)),
        ),
        chipTheme: lightBase.chipTheme.copyWith(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeSpacing.radius12)),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      );
    }
  }
}
