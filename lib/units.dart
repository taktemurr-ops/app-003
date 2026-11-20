import 'package:intl/intl.dart';
import 'settings.dart';

const mlPerUsOz = 29.5735;
const mlPerUkOz = 28.4131;

double mlToUnit(int ml, VolumeUnit unit) => switch (unit) {
      VolumeUnit.ml => ml.toDouble(),
      VolumeUnit.usOz => ml / mlPerUsOz,
      VolumeUnit.ukOz => ml / mlPerUkOz,
    };

int unitToMl(num value, VolumeUnit unit) => switch (unit) {
      VolumeUnit.ml => value.round(),
      VolumeUnit.usOz => (value * mlPerUsOz).round(),
      VolumeUnit.ukOz => (value * mlPerUkOz).round(),
    };

String unitSuffix(VolumeUnit unit) => switch (unit) {
      VolumeUnit.ml => 'mL',
      VolumeUnit.usOz => 'fl oz',
      VolumeUnit.ukOz => 'fl oz (UK)',
    };

/// Locale-aware volume label, e.g. "1.250 mL" (tr) or "8.5 fl oz" (en).
String formatVolume(int ml, VolumeUnit unit, String locale) {
  final value = mlToUnit(ml, unit);
  final pattern = unit == VolumeUnit.ml ? NumberFormat.decimalPattern(locale) : (NumberFormat.decimalPattern(locale)..maximumFractionDigits = 1);
  final number = unit == VolumeUnit.ml ? pattern.format(value.round()) : pattern.format(value);
  return '$number ${unitSuffix(unit)}';
}
