import 'dart:ui' show FontVariation;

import 'package:flutter/material.dart';

/// Design tokens carried over from the validated prototype: a warm editorial
/// light theme and a deep near-black dark theme. Fraunces (display) and Inter
/// (body) are bundled as assets, so nothing is fetched at runtime.
class AppTheme {
  static const String displayFont = 'Fraunces';
  static const String bodyFont = 'Inter';

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  /// Serif display style (wght 600), used for the wordmark and headings.
  static TextStyle display(double size, {Color? color}) => TextStyle(
        fontFamily: displayFont,
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w600,
        fontVariations: const [FontVariation('wght', 600)],
        height: 1.1,
      );

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final base = isLight ? ThemeData.light(useMaterial3: true) : ThemeData.dark(useMaterial3: true);

    final scheme = isLight
        ? const ColorScheme.light(
            primary: Color(0xFF2C4A8C),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF1C1B1A),
            outline: Color(0xFFE7E3DB),
            onSurfaceVariant: Color(0xFF7A756E),
          )
        : const ColorScheme.dark(
            primary: Color(0xFF7B9CF0),
            onPrimary: Colors.black,
            surface: Color(0xFF0A0A0A),
            onSurface: Color(0xFFF0EFEA),
            outline: Color(0xFF242424),
            onSurfaceVariant: Color(0xFF96938E),
          );

    final bg = isLight ? const Color(0xFFF4F3EE) : Colors.black;

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: base.textTheme.apply(
        fontFamily: bodyFont,
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerColor: scheme.outline,
    );
  }
}

/// Preset note background swatches ('default' follows the theme).
const List<String> kNoteSwatches = [
  'default',
  '#F6D9C7',
  '#D9E7DD',
  '#DCE3F0',
  '#F0DCE7',
  '#EDE3D2',
  '#E9E5DF',
];
