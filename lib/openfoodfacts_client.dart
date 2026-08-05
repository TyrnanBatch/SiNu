import 'dart:convert';

import 'package:http/http.dart' as http;

class ProductNotFoundException implements Exception {}

class ProductDataIncompleteException implements Exception {}

class ProductLookupResult {
  final String name;
  final double portionGrams;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double kcal;

  /// Whatever of our nutrients.dart catalog this product's label declares,
  /// keyed by [NutrientDef.key]. OpenFoodFacts is community-submitted from
  /// packaging, so coverage is far patchier than USDA's — most products
  /// only declare what their local label law requires (macros, saturated
  /// fat, sugars, sodium); vitamins/minerals mainly show up on fortified
  /// foods, and amino acids never appear at all (not a label concept).
  final Map<String, double> nutrients;

  const ProductLookupResult({
    required this.name,
    required this.portionGrams,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.kcal,
    this.nutrients = const {},
  });
}

/// Looks up products directly against OpenFoodFacts' public API — no
/// backend server involved.
class OpenFoodFactsClient {
  /// Maps our nutrients.dart catalog keys to OpenFoodFacts' nutriment field
  /// name, with a multiplier converting OFF's uniform gram-based values to
  /// our catalog's mixed mg/mcg units. Verified against live product data
  /// for the mg-scale fields; the mcg-scale ones (selenium, iodine, etc.)
  /// follow the same unit convention but weren't individually spot-checked.
  /// Deliberately excludes amino acids — OFF has no such field, ever.
  static const _fieldMap = <String, (String, double)>{
    'vitaminA': ('vitamin-a', 1e6),
    'vitaminC': ('vitamin-c', 1000),
    'vitaminD': ('vitamin-d', 1e6),
    'vitaminE': ('vitamin-e', 1000),
    'vitaminK': ('vitamin-k', 1e6),
    'thiamin': ('vitamin-b1', 1000),
    'riboflavin': ('vitamin-b2', 1000),
    'niacin': ('vitamin-pp', 1000),
    'vitaminB6': ('vitamin-b6', 1000),
    'folate': ('folates', 1e6),
    'vitaminB12': ('vitamin-b12', 1e6),
    'biotin': ('biotin', 1e6),
    'pantothenicAcid': ('pantothenic-acid', 1000),
    'calcium': ('calcium', 1000),
    'iron': ('iron', 1000),
    'magnesium': ('magnesium', 1000),
    'phosphorus': ('phosphorus', 1000),
    'potassium': ('potassium', 1000),
    'zinc': ('zinc', 1000),
    'copper': ('copper', 1000),
    'manganese': ('manganese', 1000),
    'selenium': ('selenium', 1e6),
    'iodine': ('iodine', 1e6),
    'chromium': ('chromium', 1e6),
    'molybdenum': ('molybdenum', 1e6),
    'saturatedFat': ('saturated-fat', 1),
    'transFat': ('trans-fat', 1),
    'monounsaturatedFat': ('monounsaturated-fat', 1),
    'polyunsaturatedFat': ('polyunsaturated-fat', 1),
    'cholesterol': ('cholesterol', 1000),
    'omega3': ('omega-3-fat', 1),
    'omega6': ('omega-6-fat', 1),
    'dha': ('docosahexaenoic-acid', 1e6),
    'epa': ('eicosapentaenoic-acid', 1e6),
    'fiber': ('fiber', 1),
    'totalSugars': ('sugars', 1),
    'addedSugars': ('added-sugars', 1),
  };

  Future<ProductLookupResult> fetchProduct(String barcode) async {
    final uri = Uri.https('world.openfoodfacts.org', '/api/v2/product/$barcode.json', {
      'fields': 'product_name,nutriments',
    });
    final response = await http.get(uri, headers: {'User-Agent': 'SiNu/1.0'});
    if (response.statusCode != 200) {
      throw Exception('Could not reach OpenFoodFacts (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 1) throw ProductNotFoundException();

    final product = data['product'] as Map<String, dynamic>;
    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
    final name = product['product_name'] as String?;

    const required = ['energy-kcal_100g', 'proteins_100g', 'carbohydrates_100g', 'fat_100g'];
    if (name == null || name.isEmpty || required.any((f) => nutriments[f] == null)) {
      throw ProductDataIncompleteException();
    }

    final catalogNutrients = <String, double>{};
    for (final entry in _fieldMap.entries) {
      final (field, factor) = entry.value;
      final value = nutriments['${field}_100g'];
      if (value != null) catalogNutrients[entry.key] = (value as num).toDouble() * factor;
    }

    return ProductLookupResult(
      name: name,
      portionGrams: 100,
      proteinG: (nutriments['proteins_100g'] as num).toDouble(),
      carbsG: (nutriments['carbohydrates_100g'] as num).toDouble(),
      fatG: (nutriments['fat_100g'] as num).toDouble(),
      kcal: (nutriments['energy-kcal_100g'] as num).toDouble(),
      nutrients: catalogNutrients,
    );
  }
}
