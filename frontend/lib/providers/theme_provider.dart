import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ThemeProvider — persists light/dark preference via SharedPreferences.
/// Use from any screen:
///   context.read<ThemeProvider>().setTheme(ThemeMode.dark);
///   context.watch<ThemeProvider>().themeMode
class ThemeProvider extends ChangeNotifier {
  static const _key = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get themeMode => _mode;

  bool get isDark => _mode == ThemeMode.dark;
  bool get isLight => _mode == ThemeMode.light;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == 'dark')   _mode = ThemeMode.dark;
      else if (saved == 'light') _mode = ThemeMode.light;
      else _mode = ThemeMode.system;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setTheme(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode == ThemeMode.dark ? 'dark'
          : mode == ThemeMode.light ? 'light' : 'system');
    } catch (_) {}
  }

  void toggleTheme() {
    setTheme(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
