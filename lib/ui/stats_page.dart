import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hydration_universe/l10n/app_localizations.dart';
import '../hydration_store.dart';
import '../monetization/monetization.dart';
import '../stats.dart';
import '../units.dart';
import 'common.dart';
import 'premium_page.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.store, required this.money});
  final HydrationStore store;
  final MonetizationController money;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  int days = 7;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = localeTag(context);
    final theme = Theme.of(context);
    final store = widget.store;
    final unit = store.settings.unit;
    final now = DateTime.now();
    final goal = store.goalMl;
    final totals = dailyHydration(store.entries);
    final values = lastDays(totals, now, days);
    final loggedDays = values.where((v) => v > 0).length;
    final average = loggedDays == 0 ? 0 : (values.fold<int>(0, (a, b) => a + b) / loggedDays).round();
    final goalDays = values.where((v) => v >= goal).length;
    final unlocked = unlockedAchievements(store.entries, goal, now);
    final fmt = NumberFormat.decimalPattern(locale);
    final rangeStart = now.subtract(Duration(days: days - 1));
    final rangeEntries = store.entries.where((e) => !e.at.toLocal().isBefore(DateTime(rangeStart.year, rangeStart.month, rangeStart.day)));
    final breakdown = beverageBreakdown(rangeEntries);
    final breakdownTotal = breakdown.fold<int>(0, (sum, e) => sum + e.value);

    Widget tile(String label, String value, IconData icon) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(value, style: theme.textTheme.titleLarge),
              Text(label, style: theme.textTheme.bodySmall),
            ]),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 7, label: Text(l.last7Days)),
              ButtonSegment(
                value: 30,
                label: Text(l.last30Days),
                icon: widget.money.has(PremiumFeature.longStats) ? null : const Icon(Icons.lock_outline, size: 16),
              ),
            ],
            selected: {days},
            onSelectionChanged: (v) {
              if (v.first > FreeLimits.statsDays && !widget.money.has(PremiumFeature.longStats)) {
                openPremium(context, widget.money);
                return;
              }
              setState(() => days = v.first);
            },
          ),
        ),
        const SizedBox(height: 16),
        GoalBarChart(
          values: values,
          goal: goal,
          semanticLabel: l.chartSemantics(fmt.format(goalDays), fmt.format(days)),
        ),
        const SizedBox(height: 4),
        Text(l.chartLegend(formatVolume(goal, unit, locale)), style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: [
            tile(l.dailyAverage, formatVolume(average, unit, locale), Icons.show_chart),
            tile(l.goalDays, '${fmt.format(goalDays)}/${fmt.format(days)}', Icons.flag),
            tile(l.currentStreak, l.daysCount(fmt.format(currentStreak(totals, goal, now))), Icons.local_fire_department),
            tile(l.bestStreak, l.daysCount(fmt.format(bestStreak(totals, goal))), Icons.emoji_events),
          ],
        ),
        const SizedBox(height: 16),
        Text(l.drinkBreakdown, style: theme.textTheme.titleMedium),
        if (breakdown.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(l.noData)),
        for (final item in breakdown)
          ListTile(
            leading: Icon(beverageIcon(item.key)),
            title: Text(entryBeverageName(l, store, item.key)),
            subtitle: LinearProgressIndicator(value: breakdownTotal == 0 ? 0 : item.value / breakdownTotal),
            trailing: Text(formatVolume(item.value, unit, locale)),
          ),
        const SizedBox(height: 16),
        Text(l.achievements, style: theme.textTheme.titleMedium),
        for (final a in Achievement.values)
          Builder(builder: (context) {
            final text = achievementText(l, a);
            final done = unlocked.contains(a);
            return ListTile(
              leading: Icon(done ? text.icon : Icons.lock_outline,
                  color: done ? theme.colorScheme.primary : theme.disabledColor),
              title: Text(text.title),
              subtitle: Text(text.body),
              trailing: done ? const Icon(Icons.check_circle) : null,
            );
          }),
      ],
    );
  }
}
