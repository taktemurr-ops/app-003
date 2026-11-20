import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hydration_universe/beverages.dart';
import 'package:hydration_universe/hydration.dart';
import 'package:hydration_universe/hydration_store.dart';
import 'package:hydration_universe/privacy_export.dart';
import 'package:hydration_universe/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('v1 records without drink fields load as water', () async {
    SharedPreferences.setMockInitialValues({
      HydrationStore.storageKey: jsonEncode([
        {'id': 'old', 'amountMl': 300, 'at': DateTime.now().toIso8601String()}
      ]),
    });
    final store = HydrationStore();
    await store.load();
    expect(store.entries.single.beverageId, 'water');
    expect(store.hydrationFor(DateTime.now()), 300);
  });

  test('coffee counts partially and tracks caffeine', () async {
    final store = HydrationStore();
    await store.load();
    await store.add(200, beverage: builtInBeverage('coffee'));
    expect(store.totalFor(DateTime.now()), 200);
    expect(store.hydrationFor(DateTime.now()), 160);
    expect(store.caffeineFor(DateTime.now()), 80);
  });

  test('edit amount rescales caffeine, undo restores deleted entry', () async {
    final store = HydrationStore();
    await store.load();
    final entry = await store.add(100, beverage: builtInBeverage('coffee'));
    await store.updateAmount(entry.id, 300);
    expect(store.caffeineFor(DateTime.now()), 120);
    final edited = store.entries.single;
    await store.remove(edited.id);
    expect(store.entries, isEmpty);
    await store.restore(edited);
    final reloaded = HydrationStore();
    await reloaded.load();
    expect(reloaded.entries.single.amountMl, 300);
  });

  test('back-fill a past day but never the future', () async {
    final store = HydrationStore();
    await store.load();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await store.add(250, at: yesterday);
    expect(store.totalFor(yesterday), 250);
    await expectLater(store.add(250, at: DateTime.now().add(const Duration(hours: 2))), throwsArgumentError);
  });

  test('custom drinks persist, validate and fall back when removed', () async {
    final store = HydrationStore();
    await store.load();
    final b = await store.addCustomBeverage('Ayran', 90, 0);
    await store.updateSettings(store.settings.copyWith(selectedBeverageId: b.id));
    expect(store.selectedBeverage.customName, 'Ayran');
    await expectLater(store.addCustomBeverage('  ', 90, 0), throwsArgumentError);
    await expectLater(store.addCustomBeverage('X', 200, 0), throwsArgumentError);
    final reloaded = HydrationStore();
    await reloaded.load();
    expect(reloaded.customBeverages.single.customName, 'Ayran');
    await reloaded.removeCustomBeverage(b.id);
    expect(reloaded.settings.selectedBeverageId, 'water');
  });

  test('corrupt settings do not affect entries', () async {
    SharedPreferences.setMockInitialValues({HydrationStore.settingsKey: '{not json'});
    final store = HydrationStore();
    await store.load();
    expect(store.loaded, isTrue);
    expect(store.goalMl, 2000);
    await store.add(100);
    expect(store.entries.length, 1);
  });

  test('settings persist and clearAll wipes everything', () async {
    final store = HydrationStore();
    await store.load();
    await store.updateSettings(const HydrationSettings(onboarded: true, weightKg: 60));
    await store.addCustomBeverage('Kefir', 90, 0);
    await store.clearAll();
    final reloaded = HydrationStore();
    await reloaded.load();
    expect(reloaded.settings.onboarded, isFalse);
    expect(reloaded.customBeverages, isEmpty);
  });

  test('CSV export escapes and neutralises formulas', () {
    final csv = exportHydrationCsv([
      WaterEntry(id: '1', amountMl: 250, at: DateTime.utc(2026, 11, 21, 10), beverageId: '=cmd'),
    ]);
    final lines = csv.trim().split('\n');
    expect(lines.first, 'time_utc,beverage,volume_ml,hydration_ml,caffeine_mg');
    expect(lines[1], "2026-11-21T10:00:00.000Z,'=cmd,250,250,0");
  });

  test('entry JSON rejects invalid drink factors', () {
    final ok = WaterEntry(id: 'a', amountMl: 250, at: DateTime.utc(2026)).toJson();
    expect(() => WaterEntry.fromJson({...ok, 'hydrationPercent': 999}), throwsFormatException);
    expect(() => WaterEntry.fromJson({...ok, 'caffeineMg': -1}), throwsFormatException);
  });
}
