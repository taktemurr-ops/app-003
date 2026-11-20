import 'settings.dart';

/// Transparent daily goal: every part of the total is shown to the user.
///
/// Based on widely used general guidance (about 33 mL per kg body weight,
/// extra fluid for exercise, heat, pregnancy and breastfeeding). This is a
/// habit target, not a medical recommendation.
class GoalBreakdown {
  const GoalBreakdown({
    required this.baseMl,
    required this.activityMl,
    required this.climateMl,
    required this.lifeStageMl,
    required this.totalMl,
    required this.isManual,
  });

  final int baseMl;
  final int activityMl;
  final int climateMl;
  final int lifeStageMl;
  final int totalMl;
  final bool isManual;
}

const minGoalMl = 1000;
const maxGoalMl = 6000;
const defaultBaseMl = 2000;

int roundTo50(num value) => ((value / 50).round() * 50).toInt();

GoalBreakdown calculateGoal(HydrationSettings s) {
  final manual = s.manualGoalMl;
  if (manual != null) {
    return GoalBreakdown(baseMl: manual, activityMl: 0, climateMl: 0, lifeStageMl: 0, totalMl: manual, isManual: true);
  }
  final weight = s.weightKg;
  final base = weight == null ? defaultBaseMl : roundTo50(weight * 33);
  final activity = roundTo50(s.exerciseMinutes / 30 * 350);
  final climate = switch (s.climate) {
    Climate.cool => 0,
    Climate.temperate => 0,
    Climate.hot => 500,
    Climate.veryHot => 750,
  };
  final lifeStage = switch (s.lifeStage) {
    LifeStage.standard => 0,
    LifeStage.pregnant => 300,
    LifeStage.breastfeeding => 700,
  };
  final total = (base + activity + climate + lifeStage).clamp(minGoalMl, maxGoalMl).toInt();
  return GoalBreakdown(
    baseMl: base,
    activityMl: activity,
    climateMl: climate,
    lifeStageMl: lifeStage,
    totalMl: total,
    isManual: false,
  );
}
