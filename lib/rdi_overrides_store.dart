import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// User-customized reference daily intakes, keyed by [NutrientDef.key].
/// Only nutrients that differ from their catalog default are stored here —
/// absence means "use the default".
class RdiOverridesStore {
  static const _key = 'rdi_overrides';

  Future<Map<String, double>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  Future<void> save(Map<String, double> overrides) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(overrides));
  }
}
