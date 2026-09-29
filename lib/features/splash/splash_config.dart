import 'package:flutter/animation.dart';

/// All tunable splash values live here (durations, stagger, sizes, curves).
class SplashConfig {
  SplashConfig._();

  // Timeline (milliseconds from launch)
  static const int firstLetterDelayMs = 200;
  static const int letterStaggerMs = 65;
  static const int letterDurationMs = 550;
  static const int line1DelayMs = 800;
  static const int line2DelayMs = 950;
  static const int lineDurationMs = 450;
  static const int holdMs = 350; // brand hold after the reveal completes
  static const int exitFadeMs = 450; // wordmark -> app
  static const int reducedMotionHoldMs = 600;

  // Type
  static const double wordmarkSize = 58;
  static const double letterRise = 0.28; // × font size, initial vertical offset
  static const double dotStartScale = 0.85;

  // Curves
  static const Curve letterCurve = Cubic(0.22, 1, 0.36, 1); // ease-out
  static const Curve lineCurve = Cubic(0.65, 0, 0.35, 1); // ease-in-out

  /// Length of the reveal itself (last thing to finish is line 2).
  static int get revealMs => line2DelayMs + lineDurationMs;
}
