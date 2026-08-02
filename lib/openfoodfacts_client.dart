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

  const ProductLookupResult({
    required this.name,
    required this.portionGrams,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.kcal,
  });
}

/// Looks up products directly against OpenFoodFacts' public API — no
/// backend server involved.
class OpenFoodFactsClient {
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

    return ProductLookupResult(
      name: name,
      portionGrams: 100,
      proteinG: (nutriments['proteins_100g'] as num).toDouble(),
      carbsG: (nutriments['carbohydrates_100g'] as num).toDouble(),
      fatG: (nutriments['fat_100g'] as num).toDouble(),
      kcal: (nutriments['energy-kcal_100g'] as num).toDouble(),
    );
  }
}
