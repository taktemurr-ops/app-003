enum VolumeUnit { ml, usOz, ukOz }

enum Climate { cool, temperate, hot, veryHot }

enum LifeStage { standard, pregnant, breastfeeding }

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

int _intIn(Object? value, int min, int max, int fallback) =>
    value is int && value >= min && value <= max ? value : fallback;

/// User profile, goal and reminder preferences. Stored locally only.
class HydrationSettings {
  const HydrationSettings({
    this.onboarded = false,
    this.weightKg,
    this.exerciseMinutes = 0,
    this.climate = Climate.temperate,
    this.lifeStage = LifeStage.standard,
    this.manualGoalMl,
    this.unit = VolumeUnit.ml,
    this.remindersEnabled = true,
    this.wakeMinutes = 7 * 60,
    this.sleepMinutes = 23 * 60,
    this.reminderIntervalMinutes = 90,
    this.pauseAfterGoal = true,
    this.mutedDateKey,
    this.caffeineLimitMg = 400,
    this.quickAmountsMl = const [150, 250, 350, 500],
    this.selectedBeverageId = 'water',
  });

  final bool onboarded;
  final int? weightKg;
  final int exerciseMinutes;
  final Climate climate;
  final LifeStage lifeStage;
  final int? manualGoalMl;
  final VolumeUnit unit;
  final bool remindersEnabled;
  final int wakeMinutes;
  final int sleepMinutes;
  final int reminderIntervalMinutes;
  final bool pauseAfterGoal;
  final String? mutedDateKey;
  final int caffeineLimitMg;
  final List<int> quickAmountsMl;
  final String selectedBeverageId;

  HydrationSettings copyWith({
    bool? onboarded,
    int? Function()? weightKg,
    int? exerciseMinutes,
    Climate? climate,
    LifeStage? lifeStage,
    int? Function()? manualGoalMl,
    VolumeUnit? unit,
    bool? remindersEnabled,
    int? wakeMinutes,
    int? sleepMinutes,
    int? reminderIntervalMinutes,
    bool? pauseAfterGoal,
    String? Function()? mutedDateKey,
    int? caffeineLimitMg,
    List<int>? quickAmountsMl,
    String? selectedBeverageId,
  }) =>
      HydrationSettings(
        onboarded: onboarded ?? this.onboarded,
        weightKg: weightKg != null ? weightKg() : this.weightKg,
        exerciseMinutes: exerciseMinutes ?? this.exerciseMinutes,
        climate: climate ?? this.climate,
        lifeStage: lifeStage ?? this.lifeStage,
        manualGoalMl: manualGoalMl != null ? manualGoalMl() : this.manualGoalMl,
        unit: unit ?? this.unit,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        wakeMinutes: wakeMinutes ?? this.wakeMinutes,
        sleepMinutes: sleepMinutes ?? this.sleepMinutes,
        reminderIntervalMinutes: reminderIntervalMinutes ?? this.reminderIntervalMinutes,
        pauseAfterGoal: pauseAfterGoal ?? this.pauseAfterGoal,
        mutedDateKey: mutedDateKey != null ? mutedDateKey() : this.mutedDateKey,
        caffeineLimitMg: caffeineLimitMg ?? this.caffeineLimitMg,
        quickAmountsMl: quickAmountsMl ?? this.quickAmountsMl,
        selectedBeverageId: selectedBeverageId ?? this.selectedBeverageId,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'onboarded': onboarded,
        'weightKg': weightKg,
        'exerciseMinutes': exerciseMinutes,
        'climate': climate.name,
        'lifeStage': lifeStage.name,
        'manualGoalMl': manualGoalMl,
        'unit': unit.name,
        'remindersEnabled': remindersEnabled,
        'wakeMinutes': wakeMinutes,
        'sleepMinutes': sleepMinutes,
        'reminderIntervalMinutes': reminderIntervalMinutes,
        'pauseAfterGoal': pauseAfterGoal,
        'mutedDateKey': mutedDateKey,
        'caffeineLimitMg': caffeineLimitMg,
        'quickAmountsMl': quickAmountsMl,
        'selectedBeverageId': selectedBeverageId,
      };

  /// Tolerant parser: invalid individual values fall back to defaults so a
  /// single corrupt field never wipes the whole profile.
  factory HydrationSettings.fromJson(Map<String, dynamic> json) {
    const d = HydrationSettings();
    final quick = json['quickAmountsMl'];
    final quickAmounts = quick is List && quick.isNotEmpty && quick.length <= 6 &&
            quick.every((v) => v is int && v >= 1 && v <= 2000)
        ? List<int>.unmodifiable(quick.cast<int>())
        : d.quickAmountsMl;
    final weight = json['weightKg'];
    final manual = json['manualGoalMl'];
    final muted = json['mutedDateKey'];
    final selected = json['selectedBeverageId'];
    return HydrationSettings(
      onboarded: json['onboarded'] == true,
      weightKg: weight is int && weight >= 20 && weight <= 300 ? weight : null,
      exerciseMinutes: _intIn(json['exerciseMinutes'], 0, 600, d.exerciseMinutes),
      climate: _enumByName(Climate.values, json['climate'], d.climate),
      lifeStage: _enumByName(LifeStage.values, json['lifeStage'], d.lifeStage),
      manualGoalMl: manual is int && manual >= 500 && manual <= 8000 ? manual : null,
      unit: _enumByName(VolumeUnit.values, json['unit'], d.unit),
      remindersEnabled: json['remindersEnabled'] is bool ? json['remindersEnabled'] as bool : d.remindersEnabled,
      wakeMinutes: _intIn(json['wakeMinutes'], 0, 1439, d.wakeMinutes),
      sleepMinutes: _intIn(json['sleepMinutes'], 0, 1439, d.sleepMinutes),
      reminderIntervalMinutes: _intIn(json['reminderIntervalMinutes'], 15, 480, d.reminderIntervalMinutes),
      pauseAfterGoal: json['pauseAfterGoal'] is bool ? json['pauseAfterGoal'] as bool : d.pauseAfterGoal,
      mutedDateKey: muted is String ? muted : null,
      caffeineLimitMg: _intIn(json['caffeineLimitMg'], 0, 2000, d.caffeineLimitMg),
      quickAmountsMl: quickAmounts,
      selectedBeverageId: selected is String && selected.isNotEmpty ? selected : d.selectedBeverageId,
    );
  }
}
