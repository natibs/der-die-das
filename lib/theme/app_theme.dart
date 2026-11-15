import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'nati_tokens.dart';

ThemeData buildTheme(Brightness brightness) {
  final nati = brightness == Brightness.dark ? NatiTheme.dark : NatiTheme.light;
  final scheme = ColorScheme.fromSeed(seedColor: NatiColors.basic500, brightness: brightness).copyWith(
    primary: nati.primary,
    onPrimary: nati.onPrimary,
    surface: nati.surface,
    onSurface: nati.text,
    error: nati.danger,
  );
  final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: nati.text,
      displayColor: nati.text,
    ),
    extensions: [nati],
  );
}

/// Hebrew text style (Heebo, like the A1 app's `.he` class).
TextStyle hebrewStyle({double size = 18, FontWeight weight = FontWeight.w500, Color? color}) =>
    GoogleFonts.heebo(fontSize: size, fontWeight: weight, color: color);
