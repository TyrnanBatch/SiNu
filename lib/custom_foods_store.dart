import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// On-device custom foods library. No server involved — everything lives
/// in SharedPreferences (real storage on mobile/desktop, localStorage on web).
class CustomFoodsStore {
  static const _key = 'custom_foods';
  static const _nextIdKey = 'custom_foods_next_id';

  Future<List<CustomFood>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      final seeded = _seedFoods();
      await _saveAll(prefs, seeded);
      await prefs.setInt(_nextIdKey, seeded.length + 1);
      return seeded;
    }
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => CustomFood.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveAll(SharedPreferences prefs, List<CustomFood> foods) async {
    await prefs.setString(_key, jsonEncode(foods.map((f) => f.toJson()).toList()));
  }

  Future<CustomFood> create({
    required String name,
    required String source,
    required double portionGrams,
    required double proteinG,
    required double carbsG,
    required double fatG,
    required double kcal,
    Map<String, double> nutrients = const {},
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final foods = await loadAll();
    final nextId = prefs.getInt(_nextIdKey) ?? 1;

    final food = CustomFood(
      id: nextId,
      name: name,
      source: source,
      portionGrams: portionGrams,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      kcal: kcal,
      isFavorite: false,
      nutrients: nutrients,
    );
    foods.add(food);
    await _saveAll(prefs, foods);
    await prefs.setInt(_nextIdKey, nextId + 1);
    return food;
  }

  Future<CustomFood> update(
    int id, {
    String? name,
    double? portionGrams,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? kcal,
    bool? isFavorite,
    Map<String, double>? nutrients,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final foods = await loadAll();
    final index = foods.indexWhere((f) => f.id == id);
    if (index == -1) throw Exception('Custom food not found');

    final existing = foods[index];
    final updated = CustomFood(
      id: existing.id,
      name: name ?? existing.name,
      source: existing.source,
      portionGrams: portionGrams ?? existing.portionGrams,
      proteinG: proteinG ?? existing.proteinG,
      carbsG: carbsG ?? existing.carbsG,
      fatG: fatG ?? existing.fatG,
      kcal: kcal ?? existing.kcal,
      isFavorite: isFavorite ?? existing.isFavorite,
      nutrients: nutrients ?? existing.nutrients,
    );
    foods[index] = updated;
    await _saveAll(prefs, foods);
    return updated;
  }

  Future<void> delete(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final foods = await loadAll();
    foods.removeWhere((f) => f.id == id);
    await _saveAll(prefs, foods);
  }

  List<CustomFood> _seedFoods() => [
    const CustomFood(
      id: 1,
      name: 'Chicken breast, cooked',
      source: 'custom',
      portionGrams: 100,
      proteinG: 31,
      carbsG: 0,
      fatG: 3.6,
      kcal: 165,
      isFavorite: false,
    ),
    const CustomFood(
      id: 2,
      name: 'Semi-skimmed milk',
      source: 'custom',
      portionGrams: 100,
      proteinG: 3.4,
      carbsG: 4.8,
      fatG: 1.6,
      kcal: 46,
      isFavorite: false,
    ),
  ];
}
