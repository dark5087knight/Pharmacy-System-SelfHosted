import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color foreground;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color border;
  final Color borderStrong;
  final Color mutedForeground;
  final Color success;
  final Color warning;
  final Color destructive;

  AppColors({
    required this.background,
    required this.foreground,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.borderStrong,
    required this.mutedForeground,
    required this.success,
    required this.warning,
    required this.destructive,
  });

  @override
  ThemeExtension<AppColors> copyWith({
    Color? background,
    Color? foreground,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? border,
    Color? borderStrong,
    Color? mutedForeground,
    Color? success,
    Color? warning,
    Color? destructive,
  }) {
    return AppColors(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      destructive: destructive ?? this.destructive,
    );
  }

  @override
  ThemeExtension<AppColors> lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
    );
  }
}

class AppTheme {
  static AppColors get darkColors => AppColors(
    background: const Color(0xFF141414),
    foreground: const Color(0xFFF7F7F7),
    surface1: const Color(0xFF1B1B1B),
    surface2: const Color(0xFF212121),
    surface3: const Color(0xFF262626),
    border: const Color(0xFF2B2B2B),
    borderStrong: const Color(0xFF3B3B3B),
    mutedForeground: const Color(0xFF9E9E9E),
    success: const Color(0xFF81C784),
    warning: const Color(0xFFFFB74D),
    destructive: const Color(0xFFE57373),
  );

  static AppColors get lightColors => AppColors(
    background: const Color(0xFFFCFCFC),
    foreground: const Color(0xFF141414),
    surface1: const Color(0xFFF7F7F7),
    surface2: const Color(0xFFF0F0F0),
    surface3: const Color(0xFFE5E5E5),
    border: const Color(0xFFE0E0E0),
    borderStrong: const Color(0xFFCCCCCC),
    mutedForeground: const Color(0xFF737373),
    success: const Color(0xFF2E7D32),
    warning: const Color(0xFFEF6C00),
    destructive: const Color(0xFFC62828),
  );

  static ThemeData getDarkTheme() {
    final colors = darkColors;
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.background,
      cardColor: colors.surface1,
      dividerColor: colors.border,
      primaryColor: colors.foreground,
      colorScheme: ColorScheme.dark(
        surface: colors.surface1,
        primary: colors.foreground,
        secondary: colors.surface2,
        error: colors.destructive,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme.copyWith(
          bodyLarge: TextStyle(color: colors.foreground, fontSize: 14),
          bodyMedium: TextStyle(color: colors.foreground, fontSize: 13),
          labelMedium: TextStyle(color: colors.mutedForeground, fontSize: 11),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colors.borderStrong, width: 1.5),
        ),
        hintStyle: TextStyle(color: colors.mutedForeground, fontSize: 12),
      ),
      extensions: [colors],
    );
  }

  static ThemeData getLightTheme() {
    final colors = lightColors;
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: colors.background,
      cardColor: colors.surface1,
      dividerColor: colors.border,
      primaryColor: colors.foreground,
      colorScheme: ColorScheme.light(
        surface: colors.surface1,
        primary: colors.foreground,
        secondary: colors.surface2,
        error: colors.destructive,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme.copyWith(
          bodyLarge: TextStyle(color: colors.foreground, fontSize: 14),
          bodyMedium: TextStyle(color: colors.foreground, fontSize: 13),
          labelMedium: TextStyle(color: colors.mutedForeground, fontSize: 11),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colors.borderStrong, width: 1.5),
        ),
        hintStyle: TextStyle(color: colors.mutedForeground, fontSize: 12),
      ),
      extensions: [colors],
    );
  }

  // Mono Font style utilities
  static TextStyle mono({double? fontSize, Color? color, FontWeight? fontWeight}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
  }
}

extension CurrencyFormatter on num {
  String toIQD() {
    final format = NumberFormat("#,##0", "en_US");
    return "${format.format(this)} IQD";
  }
}

