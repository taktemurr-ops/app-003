import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'hydration.dart';

class HydrationStore extends ChangeNotifier {
  static const storageKey = 'hydration_entries_v1';
  final List<WaterEntry> _entries = [];
  List<WaterEntry> get entries => List.unmodifiable(_entries);

  List<WaterEntry> entriesFor(DateTime date) =>
      List.unmodifiable(_entries.where((entry) => isSameLocalDay(entry.at, date)));

  int totalFor(DateTime date) =>
      entriesFor(date).fold(0, (sum, entry) => sum + entry.amountMl);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final restored = decoded
          .map((item) => WaterEntry.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList()
        ..sort((a, b) => b.at.compareTo(a.at));
      _entries
        ..clear()
        ..addAll(restored);
      notifyListeners();
    } catch (_) {
      // Do not overwrite malformed saved data or partially replace in-memory data.
    }
  }

  Future<void> add(int amountMl) async {
    if (amountMl < 1 || amountMl > 2000) throw ArgumentError.value(amountMl, 'amountMl');
    final now = DateTime.now();
    _entries.insert(0, WaterEntry(
      id: '${now.microsecondsSinceEpoch}-${_entries.length}',
      amountMl: amountMl,
      at: now,
    ));
    notifyListeners();
    await _save();
  }

  Future<void> remove(String id) async {
    _entries.removeWhere((entry) => entry.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(storageKey, jsonEncode(_entries.map((e) => e.toJson()).toList()));
    if (!ok) throw StateError('Could not save hydration entries');
  }
}
