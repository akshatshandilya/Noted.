import 'package:flutter/material.dart';

/// Parses a swatch like '#F6D9C7'. Returns null for 'default'.
Color? parseNoteColor(String value) {
  if (value == 'default' || !value.startsWith('#') || value.length != 7) return null;
  final v = int.tryParse(value.substring(1), radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

/// Pastel note colors are always light, so text on them is always dark ink,
/// in both light and dark mode.
const Color kInkOnPastel = Color(0xFF1C1B1A);
