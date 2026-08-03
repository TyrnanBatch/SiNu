import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:health/health.dart';

/// Thin wrapper around the `health` plugin (Health Connect on Android,
/// HealthKit on iOS) for pulling step counts. Desktop/web builds have no
/// backing implementation, so every method degrades to returning null
/// instead of throwing — callers just treat that as "no step data".
class HealthService {
  static bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  final Health _health = Health();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    _health.configure();
    _configured = true;
  }

  /// Requests step-read access if not already granted. Returns false on
  /// unsupported platforms or if the user declines.
  Future<bool> requestStepsPermission() async {
    if (!isSupported) return false;
    await _ensureConfigured();
    try {
      var granted = await _health.hasPermissions([HealthDataType.STEPS]) ?? false;
      if (!granted) {
        granted = await _health.requestAuthorization([HealthDataType.STEPS]);
      }
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// Total steps recorded for the calendar day of [date] — midnight to
  /// midnight, or midnight to now if [date] is today. Null means no data
  /// (unsupported platform, permission denied, or a plugin error).
  Future<int?> stepsForDay(DateTime date) async {
    if (!isSupported) return null;
    await _ensureConfigured();

    final start = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = start.isAtSameMomentAs(today) ? now : start.add(const Duration(days: 1));

    try {
      return await _health.getTotalStepsInInterval(start, end);
    } catch (_) {
      return null;
    }
  }
}
