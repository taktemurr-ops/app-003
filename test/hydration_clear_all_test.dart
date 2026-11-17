import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hydration_universe/hydration_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('clearAll deletes persisted data and memory', () async {
    final store = HydrationStore();
    await store.add(250);
    expect(store.entriesFor(DateTime.now()), isNotEmpty);
    await store.clearAll();
    expect(store.entriesFor(DateTime.now()), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(HydrationStore.storageKey), isFalse);
    final reloaded = HydrationStore();
    await reloaded.load();
    expect(reloaded.entriesFor(DateTime.now()), isEmpty);
  });
}
