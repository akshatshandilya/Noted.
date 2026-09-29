import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'splash_config.dart';

/// The animated "Noted." wordmark: letters rise + fade in with a small
/// stagger, the period settles in the accent color, then two ruled lines
/// are drawn beneath. Driven entirely by [controller] (0 → 1 over
/// [SplashConfig.revealMs]).
class NotedLogoAnimation extends StatelessWidget {
  final AnimationController controller;
  const NotedLogoAnimation({super.key, required this.controller});

  static const _letters = ['N', 'o', 't', 'e', 'd', '.'];

  Animation<double> _interval(int startMs, int durMs, Curve curve) {
    final total = SplashConfig.revealMs.toDouble();
    return CurvedAnimation(
      parent: controller,
      curve: Interval(
        (startMs / total).clamp(0.0, 1.0).toDouble(),
        ((startMs + durMs) / total).clamp(0.0, 1.0).toDouble(),
        curve: curve,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final double size = (width * 0.16).clamp(40.0, SplashConfig.wordmarkSize + 14).toDouble();

    final letterAnims = [
      for (var i = 0; i < _letters.length; i++)
        _interval(
          SplashConfig.firstLetterDelayMs + i * SplashConfig.letterStaggerMs,
          SplashConfig.letterDurationMs,
          SplashConfig.letterCurve,
        ),
    ];
    final line1 = _interval(SplashConfig.line1DelayMs, SplashConfig.lineDurationMs, SplashConfig.lineCurve);
    final line2 = _interval(SplashConfig.line2DelayMs, SplashConfig.lineDurationMs, SplashConfig.lineCurve);

    return Semantics(
      label: 'Noted.',
      excludeSemantics: true,
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _letters.length; i++)
                  _Letter(
                    char: _letters[i],
                    animation: letterAnims[i],
                    size: size,
                    isDot: i == _letters.length - 1,
                    color: i == _letters.length - 1 ? scheme.primary : scheme.onSurface,
                  ),
              ],
            ),
            SizedBox(height: size * 0.22),
            SizedBox(
              height: size * 0.34,
              child: AnimatedBuilder(
                animation: controller,
                builder: (_, __) => CustomPaint(
                  painter: _LinesPainter(
                    p1: line1.value,
                    p2: line2.value,
                    color: scheme.primary,
                    stroke: size * 0.042,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Letter extends StatelessWidget {
  final String char;
  final Animation<double> animation;
  final double size;
  final bool isDot;
  final Color color;

  const _Letter({
    required this.char,
    required this.animation,
    required this.size,
    required this.isDot,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final t = animation.value;
        final dy = (1 - t) * size * SplashConfig.letterRise;
        final scale = isDot ? SplashConfig.dotStartScale + (1 - SplashConfig.dotStartScale) * t : 1.0;
        return Opacity(
          opacity: t.clamp(0.0, 1.0).toDouble(),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: scale,
              child: Text(char, style: AppTheme.display(size, color: color)),
            ),
          ),
        );
      },
    );
  }
}

class _LinesPainter extends CustomPainter {
  final double p1, p2, stroke;
  final Color color;
  _LinesPainter({required this.p1, required this.p2, required this.color, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final r = stroke / 2;
    final w = size.width;
    void line(double y, double fullFraction, double progress) {
      if (progress <= 0) return;
      final x0 = r;
      final x1 = r + (w * fullFraction - 2 * r) * progress;
      canvas.drawLine(Offset(x0, y), Offset(x1, y), paint);
    }

    line(size.height * 0.25, 0.84, p1);
    line(size.height * 0.80, 0.64, p2);
  }

  @override
  bool shouldRepaint(_LinesPainter old) => old.p1 != p1 || old.p2 != p2 || old.color != color;
}
