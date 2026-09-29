import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider extends ChangeNotifier {
  final Box settingsBox;
  late ThemeMode _mode;
  late bool _iconFollowsTheme;

  ThemeProvider(this.settingsBox) {
    _mode = _parse(settingsBox.get('themeMode', defaultValue: 'system') as String);
    _iconFollowsTheme = settingsBox.get('iconFollowsTheme', defaultValue: true) as bool;
  }

  ThemeMode get mode => _mode;

  /// Whether the launcher icon switches between light and dark with the theme.
  bool get iconFollowsTheme => _iconFollowsTheme;

  void setIconFollowsTheme(bool v) {
    _iconFollowsTheme = v;
    settingsBox.put('iconFollowsTheme', v);
    notifyListeners();
  }

  static ThemeMode _parse(String v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void setMode(ThemeMode m) {
    _mode = m;
    final v = m == ThemeMode.light ? 'light' : m == ThemeMode.dark ? 'dark' : 'system';
    settingsBox.put('themeMode', v);
    notifyListeners();
  }
}
