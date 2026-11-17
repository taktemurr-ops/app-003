import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hydration_universe/hydration.dart';
import 'package:hydration_universe/hydration_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('water entry JSON round trip', () {
    final original = WaterEntry(id: 'a', amountMl: 250, at: DateTime.utc(2026, 11, 17));
    final restored = WaterEntry.fromJson(original.toJson());
    expect(restored.amountMl, 250);
    expect(restored.at, original.at);
  });

  test('local day comparison ignores time of day', () {
    expect(isSameLocalDay(DateTime(2026, 11, 17, 8), DateTime(2026, 11, 17, 23)), isTrue);
    expect(isSameLocalDay(DateTime(2026, 11, 17), DateTime(2026, 11, 18)), isFalse);
  });

  test('add, reload, remove and totals', () async {
    final store = HydrationStore();
    await store.add(250);
    await store.add(300);
    expect(store.totalFor(DateTime.now()), 550);
    final restored = HydrationStore();
    await restored.load();
    expect(restored.entries.length, 2);
    await restored.remove(restored.entries.first.id);
    final reloaded = HydrationStore();
    await reloaded.load();
    expect(reloaded.entries.length, 1);
  });

  test('invalid amount is rejected', () async {
    final store = HydrationStore();
    await expectLater(store.add(0), throwsArgumentError);
    await expectLater(store.add(2001), throwsArgumentError);
  });

  test('corrupt saved payload does not crash or partially restore', () async {
    SharedPreferences.setMockInitialValues({HydrationStore.storageKey: '[{"id":"broken"}]'});
    final store = HydrationStore();
    await store.load();
    expect(store.entries, isEmpty);
  });
}
