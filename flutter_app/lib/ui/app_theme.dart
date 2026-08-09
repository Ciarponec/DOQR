import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF0B1020);
  static const navy = Color(0xFF111936);
  static const blue = Color(0xFF2F6BFF);
  static const blueDark = Color(0xFF1D4ED8);
  static const cyan = Color(0xFF22C7E8);
  static const mist = Color(0xFFF5F7FC);
  static const surface = Colors.white;
  static const line = Color(0xFFE5E9F2);
  static const muted = Color(0xFF667085);
  static const success = Color(0xFF0E9F6E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC4C64);
}

ThemeData buildDoqrTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.blue,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE7EEFF),
    onPrimaryContainer: AppColors.navy,
    secondary: AppColors.cyan,
    onSecondary: AppColors.ink,
    secondaryContainer: Color(0xFFDDF9FD),
    onSecondaryContainer: AppColors.navy,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    error: AppColors.danger,
    onError: Colors.white,
    outline: AppColors.line,
  );
  const baseText = TextTheme(
    displaySmall: TextStyle(
        fontSize: 36,
        height: 1.08,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.3),
    headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.7),
    headlineSmall: TextStyle(
        fontSize: 23,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4),
    titleLarge: TextStyle(
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2),
    titleMedium:
        TextStyle(fontSize: 16, height: 1.35, fontWeight: FontWeight.w700),
    bodyLarge:
        TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w500),
    bodyMedium:
        TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w500),
    bodySmall:
        TextStyle(fontSize: 12, height: 1.45, fontWeight: FontWeight.w600),
    labelLarge: TextStyle(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.mist,
    textTheme:
        baseText.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    splashFactory: InkRipple.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
          fontFamily: 'Manrope',
          color: AppColors.ink,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle:
          const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
      hintStyle: const TextStyle(color: Color(0xFF98A2B3)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.6)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.danger)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFD7DDEA),
        disabledForegroundColor: AppColors.muted,
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(
            fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 14),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle:
            const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          textStyle: const TextStyle(
              fontFamily: 'Manrope', fontWeight: FontWeight.w700)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFF98A2B3)),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.blue
              : const Color(0xFFD7DDEA)),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.blue,
        thumbColor: AppColors.blue,
        inactiveTrackColor: Color(0xFFDDE4F2)),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF0F3F9),
      selectedColor: const Color(0xFFE7EEFF),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          color: AppColors.ink),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: const TextStyle(
          fontFamily: 'Manrope',
          color: AppColors.ink,
          fontSize: 21,
          fontWeight: FontWeight.w800),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.navy,
      contentTextStyle: const TextStyle(
          fontFamily: 'Manrope',
          color: Colors.white,
          fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
  );
}
