/// Catalog of optional micronutrients a custom food can carry, beyond the
/// core calories/protein/carbs/fat. Kept out of every list/summary view —
/// only surfaced behind "Show More Nutrients" on the create/edit food page.
library;

enum NutrientGroup { vitamins, minerals, aminoAcids, fats, other }

class NutrientDef {
  final String key;
  final String label;
  final String unit;

  /// Reference daily intake used to compute the "% of daily value" bar.
  /// Null means there's no established daily value (only Total Sugars, by
  /// design — every other nutrient below has at least a reasonable
  /// reference figure) — the field is still collected, just shown without
  /// a percentage bar.
  final double? rdi;
  final NutrientGroup group;

  const NutrientDef(this.key, this.label, this.unit, this.rdi, this.group);
}

const List<NutrientDef> nutrientCatalog = [
  // --- Vitamins ---
  NutrientDef('vitaminA', 'Vitamin A', 'mcg', 900, NutrientGroup.vitamins),
  NutrientDef('vitaminC', 'Vitamin C', 'mg', 90, NutrientGroup.vitamins),
  NutrientDef('vitaminD', 'Vitamin D', 'mcg', 20, NutrientGroup.vitamins),
  NutrientDef('vitaminE', 'Vitamin E', 'mg', 15, NutrientGroup.vitamins),
  NutrientDef('vitaminK', 'Vitamin K', 'mcg', 120, NutrientGroup.vitamins),
  NutrientDef('thiamin', 'Thiamin (B1)', 'mg', 1.2, NutrientGroup.vitamins),
  NutrientDef('riboflavin', 'Riboflavin (B2)', 'mg', 1.3, NutrientGroup.vitamins),
  NutrientDef('niacin', 'Niacin (B3)', 'mg', 16, NutrientGroup.vitamins),
  NutrientDef('vitaminB6', 'Vitamin B6', 'mg', 1.7, NutrientGroup.vitamins),
  NutrientDef('folate', 'Folate', 'mcg', 400, NutrientGroup.vitamins),
  NutrientDef('vitaminB12', 'Vitamin B12', 'mcg', 2.4, NutrientGroup.vitamins),
  NutrientDef('biotin', 'Biotin', 'mcg', 30, NutrientGroup.vitamins),
  NutrientDef('pantothenicAcid', 'Pantothenic Acid', 'mg', 5, NutrientGroup.vitamins),

  // --- Minerals ---
  NutrientDef('calcium', 'Calcium', 'mg', 1300, NutrientGroup.minerals),
  NutrientDef('iron', 'Iron', 'mg', 18, NutrientGroup.minerals),
  NutrientDef('magnesium', 'Magnesium', 'mg', 420, NutrientGroup.minerals),
  NutrientDef('phosphorus', 'Phosphorus', 'mg', 1250, NutrientGroup.minerals),
  NutrientDef('potassium', 'Potassium', 'mg', 4700, NutrientGroup.minerals),
  NutrientDef('sodium', 'Sodium', 'mg', 2300, NutrientGroup.minerals),
  NutrientDef('zinc', 'Zinc', 'mg', 11, NutrientGroup.minerals),
  NutrientDef('copper', 'Copper', 'mg', 0.9, NutrientGroup.minerals),
  NutrientDef('manganese', 'Manganese', 'mg', 2.3, NutrientGroup.minerals),
  NutrientDef('selenium', 'Selenium', 'mcg', 55, NutrientGroup.minerals),
  NutrientDef('iodine', 'Iodine', 'mcg', 150, NutrientGroup.minerals),
  NutrientDef('chromium', 'Chromium', 'mcg', 35, NutrientGroup.minerals),
  NutrientDef('molybdenum', 'Molybdenum', 'mcg', 45, NutrientGroup.minerals),

  // --- Amino acids (essential — WHO/FAO/UNU 2007, 70kg reference adult) ---
  NutrientDef('histidine', 'Histidine', 'g', 0.7, NutrientGroup.aminoAcids),
  NutrientDef('isoleucine', 'Isoleucine', 'g', 1.4, NutrientGroup.aminoAcids),
  NutrientDef('leucine', 'Leucine', 'g', 2.7, NutrientGroup.aminoAcids),
  NutrientDef('lysine', 'Lysine', 'g', 2.1, NutrientGroup.aminoAcids),
  NutrientDef('methionine', 'Methionine', 'g', 1.1, NutrientGroup.aminoAcids),
  NutrientDef('phenylalanine', 'Phenylalanine', 'g', 1.75, NutrientGroup.aminoAcids),
  NutrientDef('threonine', 'Threonine', 'g', 1.05, NutrientGroup.aminoAcids),
  NutrientDef('tryptophan', 'Tryptophan', 'g', 0.28, NutrientGroup.aminoAcids),
  NutrientDef('valine', 'Valine', 'g', 1.8, NutrientGroup.aminoAcids),

  // --- Fats (breakdown of the Fat total) ---
  NutrientDef('saturatedFat', 'Saturated Fat', 'g', 20, NutrientGroup.fats),
  NutrientDef('transFat', 'Trans Fat', 'g', 2, NutrientGroup.fats),
  NutrientDef('monounsaturatedFat', 'Monounsaturated Fat', 'g', 44, NutrientGroup.fats),
  NutrientDef('polyunsaturatedFat', 'Polyunsaturated Fat', 'g', 22, NutrientGroup.fats),
  NutrientDef('cholesterol', 'Cholesterol', 'mg', 300, NutrientGroup.fats),
  NutrientDef('omega3', 'Omega-3', 'g', 1.6, NutrientGroup.fats),
  NutrientDef('omega6', 'Omega-6', 'g', 17, NutrientGroup.fats),
  NutrientDef('dha', 'DHA', 'mg', 250, NutrientGroup.fats),
  NutrientDef('epa', 'EPA', 'mg', 250, NutrientGroup.fats),

  // --- Other useful info ---
  NutrientDef('fiber', 'Dietary Fiber', 'g', 28, NutrientGroup.other),
  NutrientDef('totalSugars', 'Total Sugars', 'g', null, NutrientGroup.other),
  NutrientDef('addedSugars', 'Added Sugars', 'g', 50, NutrientGroup.other),
];

const Map<NutrientGroup, String> nutrientGroupLabels = {
  NutrientGroup.vitamins: 'VITAMINS',
  NutrientGroup.minerals: 'MINERALS',
  NutrientGroup.aminoAcids: 'AMINO ACIDS',
  NutrientGroup.fats: 'FATS',
  NutrientGroup.other: 'OTHER',
};

/// [def]'s RDI, or the user's override for it if one exists in [overrides].
/// Still null for Total Sugars (by design — see [NutrientDef.rdi]).
double? effectiveRdi(NutrientDef def, Map<String, double> overrides) => overrides[def.key] ?? def.rdi;
