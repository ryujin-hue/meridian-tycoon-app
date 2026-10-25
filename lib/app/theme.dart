/// Tema Material 3 — warna sektor datang dari data (sectors.json colorHex).
library;

import 'package:flutter/material.dart';

import '../data/models.dart';

class MeridianTheme {
  static const Color _seedDark = Color(0xFF0E1420);
  static const Color _accent = Color(0xFF4C7DF0);

  static ThemeData dark() => _base(Brightness.dark);
  static ThemeData light() => _base(Brightness.light);

  static ThemeData _base(Brightness b) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: b,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: b == Brightness.dark ? _seedDark : null,
      appBarTheme: AppBarTheme(
        backgroundColor: b == Brightness.dark ? _seedDark : null,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: b == Brightness.dark
            ? const Color(0xFF18202F)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: b == Brightness.dark ? const Color(0xFF141B29) : null,
        indicatorColor: scheme.primaryContainer,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }

  /// Warna sektor dari data (fallback sekiranya format tidak dijangka).
  static Color sectorColor(GameData? data, String sectorId) {
    try {
      final hex = data?.sector(sectorId).colorHex ?? '#4C7DF0';
      final v = hex.replaceFirst('#', '');
      return Color(int.parse('FF$v', radix: 16));
    } catch (_) {
      return _accent;
    }
  }
}
