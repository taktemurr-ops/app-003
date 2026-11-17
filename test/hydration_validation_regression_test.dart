import 'package:flutter_test/flutter_test.dart';
import 'package:hydration_universe/hydration.dart';

void main() {
  test('water entry roundtrips and validates volume bounds', () {
    final entry = WaterEntry(id: 'a', amountMl: 250, at: DateTime.utc(2026, 11, 17));
    final restored = WaterEntry.fromJson(entry.toJson());
    expect(restored.id, 'a');
    expect(restored.amountMl, 250);
    expect(restored.at, entry.at);
    expect(() => WaterEntry.fromJson({...entry.toJson(), 'amountMl': 0}), throwsFormatException);
    expect(() => WaterEntry.fromJson({...entry.toJson(), 'amountMl': 2001}), throwsFormatException);
    expect(() => WaterEntry.fromJson({...entry.toJson(), 'amountMl': 1.5}), throwsFormatException);
  });

  test('same local day compares dates without requiring same instant', () {
    final morning = DateTime(2026, 11, 17, 8);
    final evening = DateTime(2026, 11, 17, 22);
    final tomorrow = DateTime(2026, 11, 18, 8);
    expect(isSameLocalDay(morning, evening), isTrue);
    expect(isSameLocalDay(morning, tomorrow), isFalse);
  });
}
