class WaterEntry {
  const WaterEntry({required this.id, required this.amountMl, required this.at});
  final String id;
  final int amountMl;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'id': id, 'amountMl': amountMl, 'at': at.toIso8601String(),
  };

  factory WaterEntry.fromJson(Map<String, dynamic> json) {
    final amount = json['amountMl'];
    if (amount is! int || amount < 1 || amount > 2000) {
      throw const FormatException('Invalid water entry');
    }
    return WaterEntry(
      id: json['id'] as String,
      amountMl: amount,
      at: DateTime.parse(json['at'] as String),
    );
  }
}

bool isSameLocalDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}
