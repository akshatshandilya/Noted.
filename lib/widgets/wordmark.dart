import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// "Noted." — serif wordmark with the period in the accent color, exactly as
/// in the splash animation. The period is part of the brand.
class NotedWordmark extends StatelessWidget {
  final double size;
  const NotedWordmark({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Noted.',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Noted', style: AppTheme.display(size, color: scheme.onSurface)),
          TextSpan(text: '.', style: AppTheme.display(size, color: scheme.primary)),
        ]),
      ),
    );
  }
}
