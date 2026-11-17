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
