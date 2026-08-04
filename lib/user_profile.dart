import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'nutrition_calc.dart';

/// Body stats used to compute BMR/TDEE for the Nutrition page's
/// recommendations. Saved separately from [UserTargets] since these are
/// facts about the person, not a chosen target.
class UserProfile {
  final BiologicalSex sex;
  final double heightCm;
  final double weightKg;
  final int age;

  const UserProfile({
    required this.sex,
    required this.heightCm,
    required this.weightKg,
    required this.age,
  });

  Map<String, dynamic> toJson() => {
    'sex': sex.name,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'age': age,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      sex: BiologicalSex.values.byName(json['sex'] as String),
      heightCm: (json['heightCm'] as num).toDouble(),
      weightKg: (json['weightKg'] as num).toDouble(),
      age: json['age'] as int,
    );
  }
}

class UserProfileStore {
  static const _key = 'user_profile';

  /// Null means no profile has been saved yet.
  Future<UserProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }
}
