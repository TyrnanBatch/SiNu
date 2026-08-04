import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Exports/imports everything SiNu stores on-device (custom foods, meal
/// templates, logged meal history, nutrition/step targets) as one JSON
/// blob, and provides the granular reset actions the Settings page offers.
class BackupService {
  static const _staticKeys = [
    'custom_foods',
    'custom_foods_next_id',
    'meal_templates',
    'meal_templates_next_id',
    'user_targets',
  ];

  Future<String> exportAll() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, Object?>{};
    for (final key in prefs.getKeys()) {
      if (_staticKeys.contains(key) || key.startsWith('meals_')) {
        data[key] = prefs.get(key);
      }
    }
    return jsonEncode({'version': 1, 'data': data});
  }

  /// Overwrites matching local keys with whatever's in [json]. Throws if the
  /// text isn't a backup this app produced.
  Future<void> importAll(String json) async {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      }
    }
  }

  Future<void> clearMealHistory() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith('meals_'))) {
      await prefs.remove(key);
    }
  }

  Future<void> resetCustomFoods() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('custom_foods');
    await prefs.remove('custom_foods_next_id');
  }

  Future<void> resetMealTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('meal_templates');
    await prefs.remove('meal_templates_next_id');
  }
}
