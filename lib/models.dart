class CustomFood {
  final int id;
  final String name;
  final String source;
  final double portionGrams;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double kcal;
  final bool isFavorite;

  /// Optional micronutrients (vitamins, minerals, fat breakdown, fiber/sugar
  /// etc), keyed by [NutrientDef.key] from nutrients.dart. Amount is in that
  /// nutrient's unit, for this food's reference portion. Never shown outside
  /// the create/edit food page.
  final Map<String, double> nutrients;

  const CustomFood({
    required this.id,
    required this.name,
    required this.source,
    required this.portionGrams,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.kcal,
    required this.isFavorite,
    this.nutrients = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'source': source,
    'portionGrams': portionGrams,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'kcal': kcal,
    'isFavorite': isFavorite,
    'nutrients': nutrients,
  };

  factory CustomFood.fromJson(Map<String, dynamic> json) {
    return CustomFood(
      id: json['id'] as int,
      name: json['name'] as String,
      source: json['source'] as String,
      portionGrams: (json['portionGrams'] as num).toDouble(),
      proteinG: (json['proteinG'] as num).toDouble(),
      carbsG: (json['carbsG'] as num).toDouble(),
      fatG: (json['fatG'] as num).toDouble(),
      kcal: (json['kcal'] as num).toDouble(),
      isFavorite: json['isFavorite'] as bool,
      nutrients: (json['nutrients'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          const {},
    );
  }
}

/// A food logged into a meal. Stores per-gram macro rates for display and
/// persistence, but they're kept in sync with the source CustomFood (via
/// [foodId]) whenever it's edited — see [updateRatesFrom]. Items whose food
/// was later deleted just keep their last-known rates.
class LoggedItem {
  final int? foodId;
  String name;
  double grams;
  double proteinPerGram;
  double carbsPerGram;
  double fatPerGram;
  double kcalPerGram;

  LoggedItem({
    this.foodId,
    required this.name,
    required this.grams,
    required this.proteinPerGram,
    required this.carbsPerGram,
    required this.fatPerGram,
    required this.kcalPerGram,
  });

  double get proteinG => proteinPerGram * grams;
  double get carbsG => carbsPerGram * grams;
  double get fatG => fatPerGram * grams;
  double get kcal => kcalPerGram * grams;

  factory LoggedItem.fromCustomFood(CustomFood food, double grams) {
    return LoggedItem(
      foodId: food.id,
      name: food.name,
      grams: grams,
      proteinPerGram: food.proteinG / food.portionGrams,
      carbsPerGram: food.carbsG / food.portionGrams,
      fatPerGram: food.fatG / food.portionGrams,
      kcalPerGram: food.kcal / food.portionGrams,
    );
  }

  /// Returns true if any rate actually changed.
  bool updateRatesFrom(CustomFood food) {
    final newProteinPerGram = food.proteinG / food.portionGrams;
    final newCarbsPerGram = food.carbsG / food.portionGrams;
    final newFatPerGram = food.fatG / food.portionGrams;
    final newKcalPerGram = food.kcal / food.portionGrams;
    final changed = name != food.name ||
        proteinPerGram != newProteinPerGram ||
        carbsPerGram != newCarbsPerGram ||
        fatPerGram != newFatPerGram ||
        kcalPerGram != newKcalPerGram;
    name = food.name;
    proteinPerGram = newProteinPerGram;
    carbsPerGram = newCarbsPerGram;
    fatPerGram = newFatPerGram;
    kcalPerGram = newKcalPerGram;
    return changed;
  }

  Map<String, dynamic> toJson() => {
    'foodId': foodId,
    'name': name,
    'grams': grams,
    'proteinPerGram': proteinPerGram,
    'carbsPerGram': carbsPerGram,
    'fatPerGram': fatPerGram,
    'kcalPerGram': kcalPerGram,
  };

  factory LoggedItem.fromJson(Map<String, dynamic> json) {
    return LoggedItem(
      foodId: json['foodId'] as int?,
      name: json['name'] as String,
      grams: (json['grams'] as num).toDouble(),
      proteinPerGram: (json['proteinPerGram'] as num).toDouble(),
      carbsPerGram: (json['carbsPerGram'] as num).toDouble(),
      fatPerGram: (json['fatPerGram'] as num).toDouble(),
      kcalPerGram: (json['kcalPerGram'] as num).toDouble(),
    );
  }
}

class MealData {
  final int number;
  final List<LoggedItem> items;

  MealData({required this.number, List<LoggedItem>? items}) : items = items ?? [];

  double get kcalTotal => items.fold(0, (sum, i) => sum + i.kcal);
  double get proteinTotal => items.fold(0, (sum, i) => sum + i.proteinG);
  double get carbsTotal => items.fold(0, (sum, i) => sum + i.carbsG);
  double get fatTotal => items.fold(0, (sum, i) => sum + i.fatG);

  Map<String, dynamic> toJson() => {
    'number': number,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory MealData.fromJson(Map<String, dynamic> json) {
    return MealData(
      number: json['number'] as int,
      items: (json['items'] as List<dynamic>)
          .map((e) => LoggedItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
