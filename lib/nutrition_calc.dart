import 'user_targets.dart';

enum BiologicalSex { male, female }

enum FitnessGoal {
  mildIncrease(250, 'Mild Weight Increase', '+250 kcal/day surplus'),
  maintain(0, 'Maintain', 'Stay at current weight'),
  recomp(-250, 'Slow Fat Loss / Recomp', '-250 kcal/day deficit'),
  mediumLoss(-500, 'Medium Fat Loss', '-500 kcal/day deficit'),
  rapidLoss(-1000, 'Rapid Fat Loss', '-1000 kcal/day deficit');

  final int calorieAdjustment;
  final String label;
  final String description;
  const FitnessGoal(this.calorieAdjustment, this.label, this.description);
}

class RecommendationInput {
  final BiologicalSex sex;
  final double heightCm;
  final double weightKg;
  final int age;
  final int dailySteps;
  final FitnessGoal goal;

  const RecommendationInput({
    required this.sex,
    required this.heightCm,
    required this.weightKg,
    required this.age,
    required this.dailySteps,
    required this.goal,
  });
}

/// Calories burned walking per step, scaled by bodyweight — roughly 0.04
/// kcal/step for a 70kg adult (~3.5 MET walking pace, ~0.75m stride),
/// extrapolated linearly from there.
const _kcalPerStepPerKg = 0.04 / 70;

/// Mifflin-St Jeor basal metabolic rate.
double computeBmr({required BiologicalSex sex, required double heightCm, required double weightKg, required int age}) {
  return sex == BiologicalSex.male
      ? 10 * weightKg + 6.25 * heightCm - 5 * age + 5
      : 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
}

/// Mifflin-St Jeor BMR, scaled by a flat non-exercise-activity multiplier
/// plus estimated calories burned walking (from daily steps), adjusted for
/// goal, then split into macros: 0.7g fat/kg bodyweight, 0.8g protein/lb
/// bodyweight, remaining calories filled with carbs.
UserTargets computeRecommendation(RecommendationInput input) {
  final bmr = computeBmr(sex: input.sex, heightCm: input.heightCm, weightKg: input.weightKg, age: input.age);
  final walkingKcal = input.dailySteps * input.weightKg * _kcalPerStepPerKg;
  final tdee = bmr * 1.2 + walkingKcal;
  final calories = (tdee + input.goal.calorieAdjustment).clamp(1200, 6000).toDouble();

  final weightLb = input.weightKg * 2.2046226218;
  final fatG = 0.7 * input.weightKg;
  final proteinG = 0.8 * weightLb;
  final remainingKcal = calories - (proteinG * 4) - (fatG * 9);
  final carbsG = remainingKcal > 0 ? remainingKcal / 4 : 0.0;

  return UserTargets(calories: calories, proteinG: proteinG, carbsG: carbsG, fatG: fatG);
}
