import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'photo_entry.dart';

/// On-device library of progress photos — metadata (date, kcal/weight
/// snapshot) in SharedPreferences like everything else; the actual image
/// bytes live in the app's documents directory since prefs isn't meant for
/// binary blobs. One photo per day — logging again the same day replaces it,
/// same convention as [WeightStore].
class PhotosStore {
  static const _key = 'progress_photos';

  static String _dateKey(DateTime d) => DateTime(d.year, d.month, d.day).toIso8601String();

  Future<List<PhotoEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    final entries = decoded.map((e) => PhotoEntry.fromJson(e as Map<String, dynamic>)).toList();
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  Future<void> _saveAll(SharedPreferences prefs, List<PhotoEntry> entries) async {
    await prefs.setString(_key, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  Future<PhotoEntry> save(PhotoEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await loadAll();
    final index = entries.indexWhere((e) => _dateKey(e.date) == _dateKey(entry.date));
    if (index != -1) {
      // Replacing this day's photo — delete the old file so it doesn't
      // linger as an orphaned file forever.
      final old = File(entries[index].imagePath);
      if (await old.exists()) await old.delete();
      entries[index] = entry;
    } else {
      entries.add(entry);
    }
    await _saveAll(prefs, entries);
    return entry;
  }

  Future<void> delete(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await loadAll();
    final index = entries.indexWhere((e) => _dateKey(e.date) == _dateKey(date));
    if (index == -1) return;
    final file = File(entries[index].imagePath);
    if (await file.exists()) await file.delete();
    entries.removeAt(index);
    await _saveAll(prefs, entries);
  }

  Future<PhotoEntry?> forDate(DateTime date) async {
    final entries = await loadAll();
    for (final e in entries) {
      if (_dateKey(e.date) == _dateKey(date)) return e;
    }
    return null;
  }
}
