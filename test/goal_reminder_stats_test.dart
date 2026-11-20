import 'package:flutter_test/flutter_test.dart';
import 'package:hydration_universe/goal.dart';
import 'package:hydration_universe/hydration.dart';
import 'package:hydration_universe/reminders.dart';
import 'package:hydration_universe/settings.dart';
import 'package:hydration_universe/stats.dart';
import 'package:hydration_universe/units.dart';

WaterEntry e(String id, int ml, DateTime at, {int percent = 100}) =>
    WaterEntry(id: id, amountMl: ml, at: at, hydrationPercent: percent);

void main() {
  group('goal', () {
    test('defaults to 2 L without weight', () {
      final g = calculateGoal(const HydrationSettings());
      expect(g.totalMl, 2000);
      expect(g.isManual, isFalse);
    });
    test('adds weight, exercise, heat and life stage transparently', () {
      final g = calculateGoal(const HydrationSettings(
          weightKg: 70, exerciseMinutes: 60, climate: Climate.hot, lifeStage: LifeStage.breastfeeding));
      expect(g.baseMl, 2300); // 70*33=2310 -> rounded to 50
      expect(g.activityMl, 700);
      expect(g.climateMl, 500);
      expect(g.lifeStageMl, 700);
      expect(g.totalMl, 4200);
    });
    test('is clamped to a safe range', () {
      expect(calculateGoal(const HydrationSettings(weightKg: 20)).totalMl, 1000);
      expect(calculateGoal(const HydrationSettings(weightKg: 300, exerciseMinutes: 600, climate: Climate.veryHot)).totalMl, 6000);
    });
    test('manual goal overrides profile', () {
      final g = calculateGoal(const HydrationSettings(weightKg: 90, manualGoalMl: 2500));
      expect(g.totalMl, 2500);
      expect(g.isManual, isTrue);
    });
  });

  group('settings json', () {
    test('round trip', () {
      const s = HydrationSettings(weightKg: 80, unit: VolumeUnit.usOz, mutedDateKey: '2026-11-21', quickAmountsMl: [200, 400]);
      final r = HydrationSettings.fromJson(s.toJson());
      expect(r.weightKg, 80);
      expect(r.unit, VolumeUnit.usOz);
      expect(r.mutedDateKey, '2026-11-21');
      expect(r.quickAmountsMl, [200, 400]);
    });
    test('invalid fields fall back to defaults individually', () {
      final r = HydrationSettings.fromJson({'weightKg': -5, 'unit': 'gallons', 'reminderIntervalMinutes': 1, 'quickAmountsMl': [0], 'caffeineLimitMg': 300});
      expect(r.weightKg, isNull);
      expect(r.unit, VolumeUnit.ml);
      expect(r.reminderIntervalMinutes, 90);
      expect(r.quickAmountsMl, const HydrationSettings().quickAmountsMl);
      expect(r.caffeineLimitMg, 300);
    });
  });

  group('units', () {
    test('converts between mL and ounces', () {
      expect(unitToMl(8, VolumeUnit.usOz), 237);
      expect(unitToMl(250, VolumeUnit.ml), 250);
      expect(mlToUnit(284, VolumeUnit.ukOz).round(), 10);
      expect(formatVolume(1250, VolumeUnit.ml, 'en'), '1,250 mL');
      expect(formatVolume(1250, VolumeUnit.ml, 'tr'), '1.250 mL');
    });
  });

  group('reminders', () {
    const s = HydrationSettings(wakeMinutes: 8 * 60, sleepMinutes: 12 * 60, reminderIntervalMinutes: 60);
    final day = DateTime(2026, 11, 21);
    test('schedules between wake and sleep', () {
      final times = reminderTimesFor(day, s);
      expect(times.map((t) => t.hour), [9, 10, 11]);
    });
    test('next reminder is the next slot today', () {
      final next = nextReminder(now: DateTime(2026, 11, 21, 9, 30), settings: s, hydrationTodayMl: 0, goalMl: 2000);
      expect(next, DateTime(2026, 11, 21, 10));
    });
    test('skips to tomorrow after goal or when muted', () {
      final afterGoal = nextReminder(now: DateTime(2026, 11, 21, 9, 30), settings: s, hydrationTodayMl: 2000, goalMl: 2000);
      expect(afterGoal, DateTime(2026, 11, 22, 9));
      final muted = nextReminder(
          now: DateTime(2026, 11, 21, 9, 30), settings: s.copyWith(mutedDateKey: () => '2026-11-21'), hydrationTodayMl: 0, goalMl: 2000);
      expect(muted, DateTime(2026, 11, 22, 9));
    });
    test('disabled reminders return null', () {
      expect(nextReminder(now: day, settings: s.copyWith(remindersEnabled: false), hydrationTodayMl: 0, goalMl: 1), isNull);
    });
    test('overnight schedules wrap past midnight', () {
      const night = HydrationSettings(wakeMinutes: 22 * 60, sleepMinutes: 2 * 60, reminderIntervalMinutes: 60);
      expect(reminderTimesFor(day, night).length, 3);
    });
    test('pace compares intake with an even schedule', () {
      final noon = DateTime(2026, 11, 21, 10); // half of 08:00-12:00
      expect(expectedByNow(noon, s, 2000), 1000);
      expect(paceStatus(noon, s, 2000, 300), PaceStatus.behind);
      expect(paceStatus(noon, s, 2000, 1000), PaceStatus.onTrack);
      expect(paceStatus(noon, s, 2000, 1600), PaceStatus.ahead);
      expect(paceStatus(noon, s, 2000, 2000), PaceStatus.done);
    });
  });

  group('stats', () {
    final today = DateTime(2026, 11, 21, 15);
    final entries = [
      e('a', 2000, DateTime(2026, 11, 21, 9)),
      e('b', 2000, DateTime(2026, 11, 20, 9)),
      e('c', 1000, DateTime(2026, 11, 19, 9)),
      e('d', 2000, DateTime(2026, 11, 18, 9)),
      e('e', 2000, DateTime(2026, 11, 17, 9)),
      e('f', 2000, DateTime(2026, 11, 16, 9)),
      e('g', 1000, DateTime(2026, 11, 16, 10), percent: 50),
    ];
    test('daily totals use hydration factor', () {
      final t = dailyHydration(entries);
      expect(t[DateTime(2026, 11, 16)], 2500);
      expect(lastDays(t, today, 3), [1000, 2000, 2000]);
    });
    test('streaks', () {
      final t = dailyHydration(entries);
      expect(currentStreak(t, 2000, today), 2);
      expect(bestStreak(t, 2000), 3);
      expect(currentStreak(t, 2000, DateTime(2026, 11, 22, 8)), 2, reason: 'today not finished yet');
    });
    test('achievements', () {
      final a = unlockedAchievements(entries, 2000, today);
      expect(a, containsAll([Achievement.firstDrink, Achievement.firstGoal, Achievement.streak3]));
      expect(a.contains(Achievement.streak7), isFalse);
    });
    test('beverage breakdown sorted by volume', () {
      final list = beverageBreakdown([
        WaterEntry(id: '1', amountMl: 100, at: today, beverageId: 'tea'),
        WaterEntry(id: '2', amountMl: 300, at: today),
      ]);
      expect(list.first.key, 'water');
    });
  });
}
