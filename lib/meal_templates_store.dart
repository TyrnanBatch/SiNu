import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// On-device library of saved meal templates (SharedPreferences-backed,
/// same pattern as [CustomFoodsStore]).
class MealTemplatesStore {
  static const _key = 'meal_templates';
  static const _nextIdKey = 'meal_templates_next_id';

  Future<List<MealTemplate>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => MealTemplate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveAll(SharedPreferences prefs, List<MealTemplate> templates) async {
    await prefs.setString(_key, jsonEncode(templates.map((t) => t.toJson()).toList()));
  }

  Future<MealTemplate> create({required String name, required List<LoggedItem> items}) async {
    final prefs = await SharedPreferences.getInstance();
    final templates = await loadAll();
    final nextId = prefs.getInt(_nextIdKey) ?? 1;

    final template = MealTemplate(id: nextId, name: name, items: items);
    templates.add(template);
    await _saveAll(prefs, templates);
    await prefs.setInt(_nextIdKey, nextId + 1);
    return template;
  }

  Future<MealTemplate> update(int id, {String? name, List<LoggedItem>? items}) async {
    final prefs = await SharedPreferences.getInstance();
    final templates = await loadAll();
    final index = templates.indexWhere((t) => t.id == id);
    if (index == -1) throw Exception('Meal template not found');

    final existing = templates[index];
    final updated = MealTemplate(id: existing.id, name: name ?? existing.name, items: items ?? existing.items);
    templates[index] = updated;
    await _saveAll(prefs, templates);
    return updated;
  }

  Future<void> delete(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final templates = await loadAll();
    templates.removeWhere((t) => t.id == id);
    await _saveAll(prefs, templates);
  }
}
