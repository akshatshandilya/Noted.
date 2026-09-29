import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/platform/app_icon_service.dart';
import '../providers/theme_provider.dart';

/// Wraps the app and keeps the launcher icon in step with the *resolved*
/// theme (so "System" follows the phone's light/dark setting). It sits inside
/// MaterialApp's builder, where Theme.of already reflects that resolution.
class AppIconSync extends StatelessWidget {
  final Widget child;
  const AppIconSync({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final follow = context.watch<ThemeProvider>().iconFollowsTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // After the frame, and de-duplicated inside the service, so this is cheap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppIconService.sync(dark: dark, enabled: follow);
    });
    return child;
  }
}
