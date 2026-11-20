import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'beverages.dart';
import 'goal.dart';
import 'hydration.dart';
import 'settings.dart';

/// Offline-first local store. Each data set is saved under its own key so a
/// corrupt value in one never destroys the others.
class HydrationStore extends ChangeNotifier {
  static const storageKey = 'hydration_entries_v1';
  static const settingsKey = 'hydration_settings_v1';
  static const beveragesKey = 'hydration_custom_beverages_v1';
  static const maxCustomBeverages = 30;

  final List<WaterEntry> _entries = [];
  final List<Beverage> _customBeverages = [];
  HydrationSettings _settings = const HydrationSettings();
  bool _loaded = false;
  int _idCounter = 0;

  bool get loaded => _loaded;
  List<WaterEntry> get entries => List.unmodifiable(_entries);
  HydrationSettings get settings => _settings;
  List<Beverage> get customBeverages => List.unmodifiable(_customBeverages);
  List<Beverage> get allBeverages => [...builtInBeverages, ..._customBeverages];
  GoalBreakdown get goal => calculateGoal(_settings);
  int get goalMl => goal.totalMl;

  Beverage? findBeverage(String id) {
    for (final b in allBeverages) {
      if (b.id == id) return b;
    }
    return null;
  }

  Beverage beverageById(String id) {
    for (final b in allBeverages) {
      if (b.id == id) return b;
    }
    return builtInBeverages.first;
  }

  Beverage get selectedBeverage => beverageById(_settings.selectedBeverageId);

  List<WaterEntry> entriesFor(DateTime date) =>
      List.unmodifiable(_entries.where((entry) => isSameLocalDay(entry.at, date)));

  /// Raw drink volume for the day.
  int totalFor(DateTime date) => entriesFor(date).fold(0, (sum, entry) => sum + entry.amountMl);

  /// Goal-credited hydration for the day (drink volume × hydration factor).
  int hydrationFor(DateTime date) => entriesFor(date).fold(0, (sum, entry) => sum + entry.hydrationMl);

  int caffeineFor(DateTime date) => entriesFor(date).fold(0, (sum, entry) => sum + entry.caffeineMg);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final restored = decoded
            .map((item) => WaterEntry.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList()
          ..sort((a, b) => b.at.compareTo(a.at));
        _entries
          ..clear()
          ..addAll(restored);
      } catch (_) {
        // Do not overwrite malformed saved data or partially replace in-memory data.
      }
    }
    final rawSettings = prefs.getString(settingsKey);
    if (rawSettings != null) {
      try {
        _settings = HydrationSettings.fromJson(Map<String, dynamic>.from(jsonDecode(rawSettings) as Map));
      } catch (_) {
        _settings = const HydrationSettings();
      }
    }
    final rawBeverages = prefs.getString(beveragesKey);
    if (rawBeverages != null) {
      try {
        final list = (jsonDecode(rawBeverages) as List<dynamic>)
            .map((item) => Beverage.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        _customBeverages
          ..clear()
          ..addAll(list);
      } catch (_) {
        // Keep built-in drinks usable even if custom drinks are corrupt.
      }
    }
    _loaded = true;
    notifyListeners();
  }

  String _newId(DateTime now) => '${now.microsecondsSinceEpoch}-${_idCounter++}';

  /// Logs a drink. [at] allows back-filling another time or day.
  Future<WaterEntry> add(int amountMl, {Beverage? beverage, DateTime? at}) async {
    if (amountMl < 1 || amountMl > 2000) throw ArgumentError.value(amountMl, 'amountMl');
    final now = DateTime.now();
    final when = at ?? now;
    if (when.isAfter(now.add(const Duration(minutes: 5)))) throw ArgumentError.value(at, 'at', 'Future time');
    final b = beverage ?? builtInBeverages.first;
    final entry = WaterEntry(
      id: _newId(now),
      amountMl: amountMl,
      at: when,
      beverageId: b.id,
      hydrationPercent: b.hydrationPercent,
      caffeineMg: b.caffeineFor(amountMl),
    );
    _entries
      ..add(entry)
      ..sort((a, b) => b.at.compareTo(a.at));
    notifyListeners();
    await _saveEntries();
    return entry;
  }

  /// Changes the volume of an existing entry, keeping its drink factors.
  Future<void> updateAmount(String id, int amountMl) async {
    if (amountMl < 1 || amountMl > 2000) throw ArgumentError.value(amountMl, 'amountMl');
    final index = _entries.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final old = _entries[index];
    final perMl = old.amountMl == 0 ? 0 : old.caffeineMg / old.amountMl;
    _entries[index] = old.copyWith(amountMl: amountMl, caffeineMg: (perMl * amountMl).round());
    notifyListeners();
    await _saveEntries();
  }

  Future<void> remove(String id) async {
    _entries.removeWhere((entry) => entry.id == id);
    notifyListeners();
    await _saveEntries();
  }

  /// Re-inserts an entry removed by mistake (undo).
  Future<void> restore(WaterEntry entry) async {
    if (_entries.any((e) => e.id == entry.id)) return;
    _entries
      ..add(entry)
      ..sort((a, b) => b.at.compareTo(a.at));
    notifyListeners();
    await _saveEntries();
  }

  Future<void> updateSettings(HydrationSettings value) async {
    _settings = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(settingsKey, jsonEncode(value.toJson()));
    if (!ok) throw StateError('Could not save settings');
  }

  Future<Beverage> addCustomBeverage(String name, int hydrationPercent, int caffeinePer100Ml) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 40) throw ArgumentError.value(name, 'name');
    if (hydrationPercent < 0 || hydrationPercent > 150) throw ArgumentError.value(hydrationPercent, 'hydrationPercent');
    if (caffeinePer100Ml < 0 || caffeinePer100Ml > 500) throw ArgumentError.value(caffeinePer100Ml, 'caffeinePer100Ml');
    if (_customBeverages.length >= maxCustomBeverages) throw StateError('Too many custom drinks');
    final beverage = Beverage(
      id: 'custom-${_newId(DateTime.now())}',
      customName: trimmed,
      hydrationPercent: hydrationPercent,
      caffeinePer100Ml: caffeinePer100Ml,
    );
    _customBeverages.add(beverage);
    notifyListeners();
    await _saveBeverages();
    return beverage;
  }

  /// Removes a custom drink. Past entries keep their stored factors.
  Future<void> removeCustomBeverage(String id) async {
    _customBeverages.removeWhere((b) => b.id == id);
    if (_settings.selectedBeverageId == id) {
      await updateSettings(_settings.copyWith(selectedBeverageId: 'water'));
    }
    notifyListeners();
    await _saveBeverages();
  }

  /// Deletes every locally stored record, setting and custom drink.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final removed = await prefs.remove(storageKey);
    await prefs.remove(settingsKey);
    await prefs.remove(beveragesKey);
    if (!removed) throw StateError('Could not delete locally stored hydration entries');
    _entries.clear();
    _customBeverages.clear();
    _settings = const HydrationSettings();
    notifyListeners();
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(storageKey, jsonEncode(_entries.map((e) => e.toJson()).toList()));
    if (!ok) throw StateError('Could not save hydration entries');
  }

  Future<void> _saveBeverages() async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(beveragesKey, jsonEncode(_customBeverages.map((b) => b.toJson()).toList()));
    if (!ok) throw StateError('Could not save custom drinks');
  }
}
