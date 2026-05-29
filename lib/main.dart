import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  // Standard Material 3 dark scheme seeded from a rich amber.
  // fromSeed generates the full tonal palette automatically.
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFFFAB00), // Amber A700
    brightness: Brightness.dark,
  );

  runApp(MaterialApp(
    title: 'Daily',
    home: const HomeScreen(),
    theme: ThemeData(
      colorScheme: scheme,
      brightness: Brightness.dark,
      // Input fields — always readable inside dialogs
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle:
            TextStyle(color: scheme.onSurfaceVariant.withValues(alpha:0.5)),
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface),
        contentTextStyle:
            TextStyle(fontSize: 15, color: scheme.onSurface),
      ),
      // Scrollbar
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(scheme.primary),
        trackColor:
            WidgetStatePropertyAll(scheme.surfaceContainerHighest),
        thumbVisibility: const WidgetStatePropertyAll(true),
        trackVisibility: const WidgetStatePropertyAll(true),
      ),
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        ),
      ),
      // ListTile — needed for attendee names
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: scheme.onSurface,
        ),
      ),
      useMaterial3: true,
    ),
  ));
}
