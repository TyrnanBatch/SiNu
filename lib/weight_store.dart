import 'package:shared_preferences/shared_preferences.dart';

/// Persists a daily body-weight log on-device, keyed by date — one value
/// per day, same storage shape as [MealsStorage].
class WeightStore {
  static String _keyFor(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return 'weight_${d.toIso8601String().split('T').first}';
  }

  /// Null means no weight was logged for that day.
  Future<double?> loadWeight(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyFor(date));
  }

  Future<void> saveWeight(DateTime date, double weightKg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFor(date), weightKg);
  }
}
