import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Deep navy/charcoal background for the app.
const kBackgroundColor = Color(0xFF1A1A2E);

/// Slightly lighter surface for cards/dialogs.
const kSurfaceColor = Color(0xFF16213E);

/// Warm amber/gold accent for interactive elements.
const kAccentColor = Color(0xFFE2B714);

/// Cream/off-white for playing cards.
const kCardColor = Color(0xFFFAF3E0);

/// Card number text color (dark, slightly warm).
const kCardTextColor = Color(0xFF2C2C2C);

/// Builds the dark theme for Countdown.
ThemeData countdownTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  final colorScheme = ColorScheme.dark(
    primary: kAccentColor,
    onPrimary: Colors.black,
    secondary: kAccentColor,
    onSecondary: Colors.black,
    surface: kSurfaceColor,
    onSurface: Colors.white,
    error: Colors.red.shade400,
    onError: Colors.white,
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: kBackgroundColor,
    appBarTheme: AppBarTheme(
      backgroundColor: kBackgroundColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kAccentColor,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kAccentColor,
        side: BorderSide(color: kAccentColor.withValues(alpha: 0.6)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccentColor,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kSurfaceColor,
      selectedColor: kAccentColor,
      labelStyle: const TextStyle(color: Colors.white),
      secondaryLabelStyle: const TextStyle(color: Colors.black),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
    ),
    dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.15)),
    cardTheme: CardThemeData(
      color: kCardColor,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kSurfaceColor,
      titleTextStyle: GoogleFonts.playfairDisplay(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: kAccentColor),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: kSurfaceColor,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
  );
}
