import 'package:flutter/material.dart';
import 'spacing.dart';

class AppTheme {
  static ThemeData build({required bool dark, Color seed = const Color(0xFF1877F2), bool amoled = false, double fontScale = 1.0}) {
    
    if (dark) {
      // Dark theme
      final darkBase = ThemeData.dark(useMaterial3: true);
      final darkColorScheme = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      );
      
      final textTheme = darkBase.textTheme.copyWith(
        headlineSmall: darkBase.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: darkBase.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: darkBase.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: darkBase.textTheme.bodyLarge,
        bodyMedium: darkBase.textTheme.bodyMedium,
      );
      
      return darkBase.copyWith(
        colorScheme: darkColorScheme,
        scaffoldBackgroundColor: amoled ? Colors.black : darkColorScheme.surface,
        textTheme: textTheme.apply(bodyColor: darkColorScheme.onSurface, displayColor: darkColorScheme.onSurface),
        appBarTheme: AppBarTheme(
          backgroundColor: darkColorScheme.surface,
          foregroundColor: darkColorScheme.onSurface,
          elevation: 0,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: darkColorScheme.primary,
          foregroundColor: darkColorScheme.onPrimary,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkColorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ThemeSpacing.radius12),
            borderSide: BorderSide(color: darkColorScheme.outline),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          labelStyle: TextStyle(color: darkColorScheme.onSurface.withValues(alpha: 0.7)),
          hintStyle: TextStyle(color: darkColorScheme.onSurface.withValues(alpha: 0.5)),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: TextStyle(color: darkColorScheme.onSurface),
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(darkColorScheme.surfaceContainerHighest),
          ),
        ),
        cardTheme: CardThemeData(
          color: darkColorScheme.surface,
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
      
      final textTheme = lightBase.textTheme.copyWith(
        headlineSmall: lightBase.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: lightBase.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: lightBase.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: lightBase.textTheme.bodyLarge,
        bodyMedium: lightBase.textTheme.bodyMedium,
      );
      
      return lightBase.copyWith(
        colorScheme: lightColorScheme,
        scaffoldBackgroundColor: lightColorScheme.surface,
        textTheme: textTheme.apply(bodyColor: lightColorScheme.onSurface, displayColor: lightColorScheme.onSurface),
        appBarTheme: AppBarTheme(
          backgroundColor: lightColorScheme.primary,
          foregroundColor: lightColorScheme.onPrimary,
          elevation: 0,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: lightColorScheme.primary,
          foregroundColor: lightColorScheme.onPrimary,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightColorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ThemeSpacing.radius12),
            borderSide: BorderSide(color: lightColorScheme.outline),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          labelStyle: TextStyle(color: lightColorScheme.onSurface.withValues(alpha: 0.7)),
          hintStyle: TextStyle(color: lightColorScheme.onSurface.withValues(alpha: 0.5)),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: TextStyle(color: lightColorScheme.onSurface),
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(lightColorScheme.surfaceContainerHighest),
          ),
        ),
        cardTheme: CardThemeData(
          color: lightColorScheme.surface,
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
