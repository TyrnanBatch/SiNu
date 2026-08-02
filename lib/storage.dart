import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Persists a day's logged meals on-device (SharedPreferences: real storage
/// on mobile/desktop, localStorage on web), keyed by date so each day gets
/// its own entry once day navigation is added.
class MealsStorage {
  static String _keyFor(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return 'meals_${d.toIso8601String().split('T').first}';
  }

  Future<List<MealData>?> loadMeals(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(date));
    if (raw == null) return null;
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => MealData.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveMeals(DateTime date, List<MealData> meals) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(meals.map((m) => m.toJson()).toList());
    await prefs.setString(_keyFor(date), encoded);
  }
}
