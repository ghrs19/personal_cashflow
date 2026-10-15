import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// One selectable accent color, mirroring KasirFree POS's ThemeColor:
/// a MaterialColor seed plus its accent variant (used in dark scheme).
class AccentColor {
  final String nameId;
  final String nameEn;
  final MaterialColor color;
  final Color accent;
  const AccentColor(this.nameId, this.nameEn, this.color, this.accent);
}

/// Theme system aligned with KasirFree POS so both apps feel like one
/// product family:
/// - the same 7 selectable accent colors (picker in Settings),
/// - light scheme = ColorScheme.fromSeed(seed), dark = ColorScheme.dark
///   with primary/accent, exactly like KasirFree,
/// - Poppins typeface (KasirFree references 'Poppins' without bundling
///   it; here it is actually loaded via google_fonts),
/// - KasirFree component language: cards radius 12, filled buttons
///   radius 12, outlined inputs radius 12, circular center FAB.
class AppTheme {
  static const accents = <AccentColor>[
    AccentColor('Hitam', 'Indigo', Colors.indigo, Colors.indigoAccent),
    AccentColor('Hijau', 'Green', Colors.green, Colors.greenAccent),
    AccentColor('Biru', 'Blue', Colors.blue, Colors.blueAccent),
    AccentColor('Merah', 'Red', Colors.red, Colors.redAccent),
    AccentColor('Ungu', 'Purple', Colors.purple, Colors.purpleAccent),
    AccentColor('Jingga', 'Orange', Colors.orange, Colors.orangeAccent),
    AccentColor('Biru Laut', 'Teal', Colors.teal, Colors.tealAccent),
  ];

  /// Default accent: Teal — closest to this app's original emerald.
  static const defaultAccent = 6;

  static AccentColor accentAt(int index) =>
      accents[index.clamp(0, accents.length - 1)];

  static ThemeData light(int accentIndex) {
    final accent = accentAt(accentIndex);
    final scheme = ColorScheme.fromSeed(
      seedColor: accent.color,
      brightness: Brightness.light,
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: GoogleFonts.poppins().fontFamily,
    );
    return _components(base, scheme);
  }

  static ThemeData dark(int accentIndex) {
    final accent = accentAt(accentIndex);
    final scheme = ColorScheme.dark(
      primary: accent.color,
      secondary: accent.accent,
    );
    final base = ThemeData.dark().copyWith(
      colorScheme: scheme,
    );
    final themed = base.copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme),
    );
    return _components(themed, scheme);
  }

  static ThemeData _components(ThemeData base, ColorScheme scheme) {
    final textTheme = base.brightness == Brightness.light
        ? GoogleFonts.poppinsTextTheme(base.textTheme)
        : base.textTheme;
    return base.copyWith(
      textTheme: textTheme,
      primaryColor: scheme.primary,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 19,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: CircleBorder(),
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
