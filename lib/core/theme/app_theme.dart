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
    final primary = isLight ? const Color(0xFF2C4A8C) : const Color(0xFF7B9CF0);

    // ColorScheme.light()/.dark() only let you override a few named slots;
    // everything else (secondary, secondaryContainer, tertiary...) falls back
    // to Material's own baked-in tones -- which is where a stray teal
    // "selected" pill on SegmentedButton/Chip was coming from. fromSeed
    // derives *all* of those from our own accent instead, then copyWith pins
    // the exact tokens the design actually specifies.
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
      primary: primary,
      onPrimary: isLight ? Colors.white : Colors.black,
      surface: isLight ? Colors.white : const Color(0xFF0A0A0A),
      onSurface: isLight ? const Color(0xFF1C1B1A) : const Color(0xFFF0EFEA),
      outline: isLight ? const Color(0xFFE7E3DB) : const Color(0xFF242424),
      onSurfaceVariant: isLight ? const Color(0xFF7A756E) : const Color(0xFF96938E),
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
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.transparent,
          selectedBackgroundColor: scheme.surface,
          selectedForegroundColor: scheme.onSurface,
          foregroundColor: scheme.onSurfaceVariant,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

/// Splash + FAB accent (validated against the HTML prototype's ".fab" and
/// splash background gradients). Kept out of ColorScheme since it's a single
/// fixed brand color, not something that should shift with the theme.
class AppAccents {
  AppAccents._();
  static const Color fabGradientStart = Color(0xFFFFA25E);
  static const Color fabGradientEnd = Color(0xFFE8620A);
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
