import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('en'), Locale('fr'), Locale('de'),
      Locale('es'), Locale('it'), Locale('nl'), Locale('pt'), Locale('ja'),
      Locale('zh'), Locale('ko'), Locale('ar'), Locale('ru'), Locale('pl'),
      Locale('tr'), Locale('sv'), Locale('da'), Locale('fi'), Locale('nb')],
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
