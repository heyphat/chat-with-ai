import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../router/browser_url_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  static const String _themeKey = 'isDarkMode';

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  bool get isDarkMode => _isDarkMode;

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    await _saveThemeToPrefs();

    // Preserve URL state on web after toggling theme
    if (kIsWeb) {
      // Add a small delay to ensure the UI updates first
      Future.delayed(const Duration(milliseconds: 50), () {
        BrowserUrlManager.preserveUrlState();
      });
    }
  }

  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    notifyListeners();
  }

  Future<void> _saveThemeToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
  }
}
