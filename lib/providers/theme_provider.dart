import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'qibli_theme';

  String _themeKey = defaultThemeKey;
  String get themeKey => _themeKey;
  AppTheme get theme => getTheme(_themeKey);

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && themes.containsKey(saved)) {
      _themeKey = saved;
      notifyListeners();
    }
  }

  Future<void> setThemeKey(String key) async {
    if (!themes.containsKey(key)) return;
    _themeKey = key;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, key);
  }
}
