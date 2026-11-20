/// Core hydration domain models.
///
/// A [WaterEntry] stores the raw drink volume ([amountMl]) together with the
/// beverage it came from. Older v1 records only contain id/amountMl/at and are
/// read as plain water, so existing users keep their history.
class WaterEntry {
  const WaterEntry({
    required this.id,
    required this.amountMl,
    required this.at,
    this.beverageId = 'water',
    this.hydrationPercent = 100,
    this.caffeineMg = 0,
  });

  final String id;

  /// Drink volume in millilitres (1–2000).
  final int amountMl;
  final DateTime at;
  final String beverageId;

  /// How much of the volume counts toward the hydration goal (0–150 %).
  final int hydrationPercent;
  final int caffeineMg;

  int get hydrationMl => (amountMl * hydrationPercent / 100).round();

  WaterEntry copyWith({int? amountMl, DateTime? at, String? beverageId, int? hydrationPercent, int? caffeineMg}) =>
      WaterEntry(
        id: id,
        amountMl: amountMl ?? this.amountMl,
        at: at ?? this.at,
        beverageId: beverageId ?? this.beverageId,
        hydrationPercent: hydrationPercent ?? this.hydrationPercent,
        caffeineMg: caffeineMg ?? this.caffeineMg,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'amountMl': amountMl,
        'at': at.toIso8601String(),
        'beverageId': beverageId,
        'hydrationPercent': hydrationPercent,
        'caffeineMg': caffeineMg,
      };

  factory WaterEntry.fromJson(Map<String, dynamic> json) {
    final amount = json['amountMl'];
    if (amount is! int || amount < 1 || amount > 2000) {
      throw const FormatException('Invalid water entry');
    }
    final id = json['id'];
    final at = json['at'];
    if (id is! String || id.isEmpty || at is! String) {
      throw const FormatException('Invalid water entry');
    }
    final beverage = json['beverageId'] ?? 'water';
    final percent = json['hydrationPercent'] ?? 100;
    final caffeine = json['caffeineMg'] ?? 0;
    if (beverage is! String || percent is! int || percent < 0 || percent > 150 ||
        caffeine is! int || caffeine < 0 || caffeine > 2000) {
      throw const FormatException('Invalid water entry');
    }
    return WaterEntry(
      id: id,
      amountMl: amount,
      at: DateTime.parse(at),
      beverageId: beverage,
      hydrationPercent: percent,
      caffeineMg: caffeine,
    );
  }
}

bool isSameLocalDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// Local calendar date (midnight) for grouping.
DateTime localDate(DateTime value) {
  final v = value.toLocal();
  return DateTime(v.year, v.month, v.day);
}

String dateKey(DateTime value) {
  final d = localDate(value);
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
