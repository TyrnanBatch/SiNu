import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the app is in dark or light mode — a single source of truth that
/// [AppColors]'s getters read from, so toggling it and rebuilding the app
/// (see [SiNuApp]) is enough to retheme every screen.
class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._();
  ThemeController._();

  static const _key = 'dark_mode';

  bool _isDark = true;
  bool get isDark => _isDark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_key);
    if (stored != null && stored != _isDark) {
      _isDark = stored;
      notifyListeners();
    }
  }

  Future<void> setDark(bool value) async {
    if (value == _isDark) return;
    _isDark = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
