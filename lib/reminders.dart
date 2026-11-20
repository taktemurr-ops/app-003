import 'hydration.dart';
import 'settings.dart';

/// Pure reminder planning logic (no platform code), so it is fully testable.

({DateTime start, DateTime end}) activeWindow(DateTime day, HydrationSettings s) {
  final d = localDate(day);
  final start = d.add(Duration(minutes: s.wakeMinutes));
  var endMinutes = s.sleepMinutes;
  if (endMinutes <= s.wakeMinutes) endMinutes += 24 * 60; // overnight / shift schedules
  return (start: start, end: d.add(Duration(minutes: endMinutes)));
}

/// Reminder times for [day]: every interval after waking, before sleeping.
List<DateTime> reminderTimesFor(DateTime day, HydrationSettings s) {
  final w = activeWindow(day, s);
  final times = <DateTime>[];
  var t = w.start.add(Duration(minutes: s.reminderIntervalMinutes));
  while (t.isBefore(w.end) && times.length < 96) {
    times.add(t);
    t = t.add(Duration(minutes: s.reminderIntervalMinutes));
  }
  return times;
}

bool isMutedOn(DateTime day, HydrationSettings s) => s.mutedDateKey == dateKey(day);

/// Next reminder from [now], or null when reminders are off for now.
///
/// Today's remaining reminders are skipped if today is muted or the goal is
/// already reached (with pause-after-goal on); the first one tomorrow is
/// returned instead.
DateTime? nextReminder({
  required DateTime now,
  required HydrationSettings settings,
  required int hydrationTodayMl,
  required int goalMl,
}) {
  if (!settings.remindersEnabled) return null;
  final skipToday = isMutedOn(now, settings) || (settings.pauseAfterGoal && hydrationTodayMl >= goalMl);
  if (!skipToday) {
    for (final t in reminderTimesFor(now, settings)) {
      if (t.isAfter(now)) return t;
    }
  }
  final tomorrow = reminderTimesFor(localDate(now).add(const Duration(days: 1, hours: 2)), settings);
  return tomorrow.isEmpty ? null : tomorrow.first;
}

/// Amount that should have been drunk by [now] to stay on an even pace.
int expectedByNow(DateTime now, HydrationSettings s, int goalMl) {
  final w = activeWindow(now, s);
  if (!now.isAfter(w.start)) return 0;
  if (!now.isBefore(w.end)) return goalMl;
  final fraction = now.difference(w.start).inMinutes / w.end.difference(w.start).inMinutes;
  return (goalMl * fraction).round();
}

enum PaceStatus { done, ahead, onTrack, behind }

PaceStatus paceStatus(DateTime now, HydrationSettings s, int goalMl, int hydrationMl) {
  if (hydrationMl >= goalMl) return PaceStatus.done;
  final expected = expectedByNow(now, s, goalMl);
  final tolerance = (goalMl * 0.1).round();
  if (hydrationMl >= expected + tolerance) return PaceStatus.ahead;
  if (hydrationMl >= expected - tolerance) return PaceStatus.onTrack;
  return PaceStatus.behind;
}
