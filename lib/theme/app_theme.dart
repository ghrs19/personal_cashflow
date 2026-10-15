import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Minimalist, elegant theme: near-monochrome surfaces, hairline rules
/// instead of boxed cards, generous whitespace, and one restrained
/// emerald accent reserved for money-in and primary actions.
/// Outflows are rendered in ink/neutral tones — the sign does the talking.
class AppTheme {
  static const seed = Color(0xFF0E7C66);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final scaffold = dark ? const Color(0xFF0B0D0C) : const Color(0xFFFBFBF9);
    final surface = dark ? const Color(0xFF131514) : Colors.white;
    final hairline = scheme.outlineVariant.withValues(alpha: dark ? 0.55 : 0.75);
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
      titleLarge: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleMedium: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
    );
    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 19),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: hairline),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: hairline),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 62,
        backgroundColor: surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.10),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: hairline),
        backgroundColor: Colors.transparent,
        selectedColor: scheme.primary.withValues(alpha: 0.10),
        labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
      dividerTheme: DividerThemeData(color: hairline, space: 1, thickness: 1),
      dialogTheme: DialogThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }
}
