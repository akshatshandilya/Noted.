import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// The create button, matching the HTML prototype's ".fab": a circular
/// orange-gradient button rather than Material's default FAB colors.
class GradientFab extends StatelessWidget {
  final VoidCallback onTap;
  const GradientFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Create a new note',
      child: Material(
        shape: const CircleBorder(),
        color: Colors.transparent,
        child: Ink(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppAccents.fabGradientStart, AppAccents.fabGradientEnd],
            ),
            boxShadow: [
              BoxShadow(
                color: AppAccents.fabGradientEnd.withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const Icon(Icons.add, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}
