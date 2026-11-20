/// Drink catalogue with hydration and caffeine factors.
///
/// Factors are general approximations for habit tracking, not medical or
/// nutritional advice. Users can create their own drinks with custom values.
class Beverage {
  const Beverage({
    required this.id,
    required this.hydrationPercent,
    required this.caffeinePer100Ml,
    this.customName,
  });

  final String id;
  final int hydrationPercent;
  final int caffeinePer100Ml;

  /// Set only for user-created drinks; built-in drinks are localized by id.
  final String? customName;

  bool get isCustom => customName != null;

  int caffeineFor(int volumeMl) => (volumeMl * caffeinePer100Ml / 100).round();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': customName,
        'hydrationPercent': hydrationPercent,
        'caffeinePer100Ml': caffeinePer100Ml,
      };

  factory Beverage.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final percent = json['hydrationPercent'];
    final caffeine = json['caffeinePer100Ml'];
    if (id is! String || !id.startsWith('custom-') || name is! String || name.trim().isEmpty ||
        name.length > 40 || percent is! int || percent < 0 || percent > 150 ||
        caffeine is! int || caffeine < 0 || caffeine > 500) {
      throw const FormatException('Invalid beverage');
    }
    return Beverage(id: id, customName: name.trim(), hydrationPercent: percent, caffeinePer100Ml: caffeine);
  }
}

const builtInBeverages = <Beverage>[
  Beverage(id: 'water', hydrationPercent: 100, caffeinePer100Ml: 0),
  Beverage(id: 'sparkling', hydrationPercent: 100, caffeinePer100Ml: 0),
  Beverage(id: 'herbalTea', hydrationPercent: 100, caffeinePer100Ml: 0),
  Beverage(id: 'tea', hydrationPercent: 90, caffeinePer100Ml: 20),
  Beverage(id: 'coffee', hydrationPercent: 80, caffeinePer100Ml: 40),
  Beverage(id: 'milk', hydrationPercent: 90, caffeinePer100Ml: 0),
  Beverage(id: 'juice', hydrationPercent: 85, caffeinePer100Ml: 0),
  Beverage(id: 'sportsDrink', hydrationPercent: 100, caffeinePer100Ml: 0),
  Beverage(id: 'smoothie', hydrationPercent: 80, caffeinePer100Ml: 0),
  Beverage(id: 'soup', hydrationPercent: 80, caffeinePer100Ml: 0),
];

Beverage? builtInBeverage(String id) {
  for (final b in builtInBeverages) {
    if (b.id == id) return b;
  }
  return null;
}
