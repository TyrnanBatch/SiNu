import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The user's daily calorie/macro targets. Drives the home page's ENERGY
/// ring and the "% of daily target" bars on the create/edit food page.
class UserTargets {
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const UserTargets({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  static const defaults = UserTargets(calories: 2500, proteinG: 180, carbsG: 280, fatG: 80);

  UserTargets copyWith({double? calories, double? proteinG, double? carbsG, double? fatG}) {
    return UserTargets(
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
    );
  }

  Map<String, dynamic> toJson() => {
    'calories': calories,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
  };

  factory UserTargets.fromJson(Map<String, dynamic> json) {
    return UserTargets(
      calories: (json['calories'] as num).toDouble(),
      proteinG: (json['proteinG'] as num).toDouble(),
      carbsG: (json['carbsG'] as num).toDouble(),
      fatG: (json['fatG'] as num).toDouble(),
    );
  }
}

/// On-device store for [UserTargets], SharedPreferences-backed like the
/// custom foods store.
class UserTargetsStore {
  static const _key = 'user_targets';

  Future<UserTargets> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return UserTargets.defaults;
    return UserTargets.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(UserTargets targets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(targets.toJson()));
  }
}
