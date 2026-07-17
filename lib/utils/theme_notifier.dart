import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app-wide [ThemeMode] and persists the selection.
class ThemeNotifier extends ChangeNotifier {
  static const kThemeModeKey = 'app_theme_mode';

  ThemeNotifier(this._prefs) : _themeMode = _load(_prefs);

  final SharedPreferencesWithCache _prefs;
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  static ThemeMode _load(SharedPreferencesWithCache prefs) {
    final value = prefs.getString(kThemeModeKey);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setTheme(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(kThemeModeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    });
  }
}
