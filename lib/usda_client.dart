import 'dart:convert';

import 'package:http/http.dart' as http;

class UsdaFoodResult {
  final String description;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double kcal;

  const UsdaFoodResult({
    required this.description,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.kcal,
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

      results.add(UsdaFoodResult(
        description: description,
        proteinG: nutrients[_nutrientIds['protein']] ?? 0,
        carbsG: nutrients[_nutrientIds['carbs']] ?? 0,
        fatG: nutrients[_nutrientIds['fat']] ?? 0,
        kcal: kcal,
      ));
    }
    return results;
  }
}
