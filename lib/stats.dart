import 'hydration.dart';

/// Hydration (goal-credited) total per local calendar day.
Map<DateTime, int> dailyHydration(Iterable<WaterEntry> entries) {
  final map = <DateTime, int>{};
  for (final e in entries) {
    final d = localDate(e.at);
    map[d] = (map[d] ?? 0) + e.hydrationMl;
  }
  return map;
}

/// Totals for the last [days] days ending at [today], oldest first.
List<int> lastDays(Map<DateTime, int> totals, DateTime today, int days) {
  final end = localDate(today);
  return List.generate(days, (i) => totals[DateTime(end.year, end.month, end.day - (days - 1 - i))] ?? 0);
}

/// Consecutive goal days ending today (or yesterday if today is not done yet).
int currentStreak(Map<DateTime, int> totals, int goalMl, DateTime today) {
  var day = localDate(today);
  if ((totals[day] ?? 0) < goalMl) day = DateTime(day.year, day.month, day.day - 1);
  var streak = 0;
  while ((totals[day] ?? 0) >= goalMl) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}

int bestStreak(Map<DateTime, int> totals, int goalMl) {
  final days = totals.entries.where((e) => e.value >= goalMl).map((e) => e.key).toList()..sort();
  var best = 0;
  var run = 0;
  DateTime? previous;
  for (final d in days) {
    final expected = previous == null ? null : DateTime(previous.year, previous.month, previous.day + 1);
    run = expected != null && expected == d ? run + 1 : 1;
    if (run > best) best = run;
    previous = d;
  }
  return best;
}

enum Achievement { firstDrink, firstGoal, streak3, streak7, streak30, days30, liters100 }

Set<Achievement> unlockedAchievements(Iterable<WaterEntry> entries, int goalMl, DateTime today) {
  final list = entries.toList();
  final totals = dailyHydration(list);
  final best = bestStreak(totals, goalMl);
  final totalMl = list.fold<int>(0, (sum, e) => sum + e.hydrationMl);
  return {
    if (list.isNotEmpty) Achievement.firstDrink,
    if (totals.values.any((v) => v >= goalMl)) Achievement.firstGoal,
    if (best >= 3) Achievement.streak3,
    if (best >= 7) Achievement.streak7,
    if (best >= 30) Achievement.streak30,
    if (totals.length >= 30) Achievement.days30,
    if (totalMl >= 100000) Achievement.liters100,
  };
}

/// Share of hydration volume per beverage id, largest first.
List<MapEntry<String, int>> beverageBreakdown(Iterable<WaterEntry> entries) {
  final map = <String, int>{};
  for (final e in entries) {
    map[e.beverageId] = (map[e.beverageId] ?? 0) + e.amountMl;
  }
  return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}
