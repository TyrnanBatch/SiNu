import 'dart:convert';

import 'package:http/http.dart' as http;

class UsdaFoodResult {
  final String description;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double kcal;

  /// Whatever of our nutrients.dart catalog USDA happened to have measured
  /// for this specific food, keyed by [NutrientDef.key] — coverage varies
  /// wildly per food (raw/whole foods tend to have amino acids and most
  /// vitamins/minerals measured; processed foods often have almost none of
  /// that, just a fatty-acid breakdown). Absence of a key means USDA didn't
  /// report it, not that the true value is zero.
  final Map<String, double> nutrients;

  const UsdaFoodResult({
    required this.description,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.kcal,
    this.nutrients = const {},
  });
}

/// Searches USDA FoodData Central's public API directly — no backend
/// server involved.
class UsdaFoodsClient {
  static const _apiKey = 'iZi05VCowYyuw4cSJPICWSvy6xqWKiR0StQckjDn';

  static const _nutrientIds = {
    'protein': 1003,
    'fat': 1004,
    'carbs': 1005,
    'kcal': 1008,
  };

  /// Maps our nutrients.dart catalog keys to USDA's nutrientId, with a
  /// multiplier to reconcile unit differences (USDA reports DHA/EPA in
  /// grams; we display them in mg). IDs verified against live API
  /// responses except vitaminK/biotin/iodine/chromium/molybdenum, which
  /// are rare enough in USDA's data that no sample food had them to check
  /// against — worst case a wrong ID there just never matches, same as any
  /// other nutrient USDA didn't measure.
  static const _catalogNutrientIds = <String, (int, double)>{
    'vitaminA': (1106, 1),
    'vitaminC': (1162, 1),
    'vitaminD': (1114, 1),
    'vitaminE': (1109, 1),
    'vitaminK': (1185, 1),
    'thiamin': (1165, 1),
    'riboflavin': (1166, 1),
    'niacin': (1167, 1),
    'vitaminB6': (1175, 1),
    'folate': (1177, 1),
    'vitaminB12': (1178, 1),
    'biotin': (1176, 1),
    'pantothenicAcid': (1170, 1),
    'calcium': (1087, 1),
    'iron': (1089, 1),
    'magnesium': (1090, 1),
    'phosphorus': (1091, 1),
    'potassium': (1092, 1),
    'sodium': (1093, 1),
    'zinc': (1095, 1),
    'copper': (1098, 1),
    'manganese': (1101, 1),
    'selenium': (1103, 1),
    'iodine': (1100, 1),
    'chromium': (1096, 1),
    'molybdenum': (1102, 1),
    'histidine': (1221, 1),
    'isoleucine': (1212, 1),
    'leucine': (1213, 1),
    'lysine': (1214, 1),
    'methionine': (1215, 1),
    'phenylalanine': (1217, 1),
    'threonine': (1211, 1),
    'tryptophan': (1210, 1),
    'valine': (1219, 1),
    'saturatedFat': (1258, 1),
    'transFat': (1257, 1),
    'monounsaturatedFat': (1292, 1),
    'polyunsaturatedFat': (1293, 1),
    'cholesterol': (1253, 1),
    'omega3': (1270, 1), // ALA (18:3) — DHA/EPA tracked separately below
    'omega6': (1269, 1), // Linoleic acid (18:2)
    'dha': (2025, 1000), // USDA: grams -> our catalog: mg
    'epa': (2023, 1000),
    'fiber': (1079, 1),
    'totalSugars': (2000, 1),
    'addedSugars': (1235, 1), // rarely present outside Branded foods
  };

  Future<List<UsdaFoodResult>> search(String query) async {
    final uri = Uri.https('api.nal.usda.gov', '/fdc/v1/foods/search', {
      'api_key': _apiKey,
      'query': query,
      'pageSize': '25',
      'dataType': 'Foundation,SR Legacy',
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Could not reach USDA FoodData Central (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final foods = data['foods'] as List<dynamic>? ?? [];

    final results = <UsdaFoodResult>[];
    for (final food in foods) {
      final map = food as Map<String, dynamic>;
      final description = map['description'] as String?;
      if (description == null || description.isEmpty) continue;

      final nutrients = <int, double>{};
      for (final n in (map['foodNutrients'] as List<dynamic>? ?? [])) {
        final nutrientMap = n as Map<String, dynamic>;
        final id = nutrientMap['nutrientId'] as int?;
        final value = nutrientMap['value'];
        if (id == null || value == null) continue;
        nutrients[id] = (value as num).toDouble();
      }

      final kcal = nutrients[_nutrientIds['kcal']];
      if (kcal == null) continue;

      final catalogNutrients = <String, double>{};
      for (final entry in _catalogNutrientIds.entries) {
        final (id, factor) = entry.value;
        final value = nutrients[id];
        if (value != null) catalogNutrients[entry.key] = value * factor;
      }

      results.add(UsdaFoodResult(
        description: description,
        proteinG: nutrients[_nutrientIds['protein']] ?? 0,
        carbsG: nutrients[_nutrientIds['carbs']] ?? 0,
        fatG: nutrients[_nutrientIds['fat']] ?? 0,
        kcal: kcal,
        nutrients: catalogNutrients,
      ));
    }
    return results;
  }
}
