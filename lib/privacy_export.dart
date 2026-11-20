import 'dart:convert';
import 'hydration.dart';

/// Generates a portable JSON snapshot entirely on-device.
///
/// Call only after an explicit user export action. This function does not
/// transmit, upload, log or persist personal records.
String exportHydrationEntries(Iterable<WaterEntry> entries) {
  return jsonEncode({
    'schemaVersion': 1,
    'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'hydrationEntries': entries.map((entry) => entry.toJson()).toList(),
  });
}

String _csvField(String value) {
  // Neutralise spreadsheet formula injection and quote special characters.
  var v = value;
  if (v.isNotEmpty && '=+-@\t\r'.contains(v[0])) v = "'$v";
  if (v.contains(RegExp('[",\n\r]'))) v = '"${v.replaceAll('"', '""')}"';
  return v;
}

/// CSV export (UTF-8, comma separated, one row per drink, oldest first).
String exportHydrationCsv(Iterable<WaterEntry> entries) {
  final rows = entries.toList()..sort((a, b) => a.at.compareTo(b.at));
  final buffer = StringBuffer('time_utc,beverage,volume_ml,hydration_ml,caffeine_mg\n');
  for (final e in rows) {
    buffer
      ..write(_csvField(e.at.toUtc().toIso8601String()))
      ..write(',')
      ..write(_csvField(e.beverageId))
      ..write(',${e.amountMl},${e.hydrationMl},${e.caffeineMg}\n');
  }
  return buffer.toString();
}
