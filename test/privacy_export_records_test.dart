import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydration_universe/hydration.dart';
import 'package:hydration_universe/privacy_export.dart';

void main() {
  test('export round-trips records and preserves Unicode identifiers', () {
    final at = DateTime.utc(2026, 11, 17, 11);
    final entry = WaterEntry(id: 'su-١-💧', amountMl: 250, at: at);
    final payload = jsonDecode(exportHydrationEntries([entry])) as Map<String, dynamic>;
    final records = payload['hydrationEntries'] as List<dynamic>;
    expect(records.length, 1);
    final restored = WaterEntry.fromJson(Map<String, dynamic>.from(records.single as Map));
    expect(restored.id, entry.id);
    expect(restored.amountMl, 250);
    expect(restored.at, at);
  });

  test('export includes only declared local data fields', () {
    final payload = jsonDecode(exportHydrationEntries([])) as Map<String, dynamic>;
    expect(payload.keys.toSet(), {'schemaVersion', 'exportedAtUtc', 'hydrationEntries'});
    expect(payload['hydrationEntries'], isEmpty);
  });
}
