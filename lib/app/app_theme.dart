import 'package:flutter/material.dart';

ThemeData buildMurajaahTheme(Brightness brightness) {
  const seed = Color(0xFF246B55);
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      minTileHeight: 64,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
  );
}
