import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hydration_universe/l10n/app_localizations.dart';
import '../hydration.dart';
import '../hydration_store.dart';
import '../localized_integer.dart';
import '../stats.dart';
import '../units.dart';
import 'common.dart';

/// Month calendar showing goal days, with per-day entries and back-filling.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.store});
  final HydrationStore store;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late DateTime month;
  late DateTime selected;

  HydrationStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    month = DateTime(now.year, now.month);
    selected = localDate(now);
  }

  Future<void> _addForDay(AppLocalizations l) async {
    final unit = store.settings.unit;
    final maxInUnit = mlToUnit(2000, unit).floor();
    final controller = TextEditingController();
    var time = const TimeOfDay(hour: 12, minute: 0);
    final result = await showDialog<({int value, TimeOfDay time})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l.addForDay(DateFormat.yMMMd(localeTag(context)).format(selected))),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(beverageName(l, store.selectedBeverage)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.amountIn(unitSuffix(unit)), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(time.format(context)),
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: time);
                if (picked != null) setDialogState(() => time = picked);
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
            FilledButton(
              onPressed: () {
                final value = parseLocalizedWholeNumber(controller.text, min: 1, max: maxInUnit);
                Navigator.pop(context, value == null ? null : (value: value, time: time));
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    final at = DateTime(selected.year, selected.month, selected.day, result.time.hour, result.time.minute);
    if (at.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.futureNotAllowed)));
      return;
    }
    await store.add(unitToMl(result.value, unit).clamp(1, 2000).toInt(), beverage: store.selectedBeverage, at: at);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = localeTag(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final goal = store.goalMl;
    final totals = dailyHydration(store.entries);
    final firstWeekday = MaterialLocalizations.of(context).firstDayOfWeekIndex; // 0 = Sunday
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = (DateTime(month.year, month.month, 1).weekday % 7 - firstWeekday + 7) % 7;
    final today = localDate(DateTime.now());
    final weekdayNames = List.generate(7, (i) {
      // 2023-01-01 was a Sunday.
      final d = DateTime(2023, 1, 1 + (firstWeekday + i) % 7);
      return DateFormat.E(locale).format(d);
    });
    final dayEntries = store.entriesFor(selected);
    final s = store.settings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(children: [
          IconButton(
            tooltip: l.previousMonth,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)),
          ),
          Expanded(
            child: Text(DateFormat.yMMMM(locale).format(month),
                textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          ),
          IconButton(
            tooltip: l.nextMonth,
            icon: const Icon(Icons.chevron_right),
            onPressed: DateTime(month.year, month.month + 1).isAfter(today)
                ? null
                : () => setState(() => month = DateTime(month.year, month.month + 1)),
          ),
        ]),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final name in weekdayNames)
              Center(child: Text(name, style: theme.textTheme.labelSmall)),
            for (var i = 0; i < leading; i++) const SizedBox.shrink(),
            for (var day = 1; day <= daysInMonth; day++)
              Builder(builder: (context) {
                final date = DateTime(month.year, month.month, day);
                final value = totals[date] ?? 0;
                final ratio = goal == 0 ? 0.0 : (value / goal).clamp(0.0, 1.0);
                final isSelected = date == selected;
                final isFuture = date.isAfter(today);
                return Padding(
                  padding: const EdgeInsets.all(2),
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label: '${DateFormat.yMMMd(locale).format(date)}, ${formatVolume(value, s.unit, locale)}',
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: isFuture ? null : () => setState(() => selected = date),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: value == 0 ? null : scheme.primary.withValues(alpha: 0.15 + 0.6 * ratio),
                          border: Border.all(
                            color: isSelected ? scheme.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('$day',
                              style: TextStyle(
                                color: isFuture ? theme.disabledColor : null,
                                fontWeight: date == today ? FontWeight.bold : null,
                              )),
                          if (value >= goal && goal > 0) const Icon(Icons.check, size: 12),
                        ]),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
        const Divider(height: 32),
        Row(children: [
          Expanded(
            child: Text(
              '${DateFormat.yMMMMEEEEd(locale).format(selected)}\n'
              '${formatVolume(store.hydrationFor(selected), s.unit, locale)} / ${formatVolume(goal, s.unit, locale)}',
              style: theme.textTheme.titleSmall,
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _addForDay(l),
            icon: const Icon(Icons.add),
            label: Text(l.add),
          ),
        ]),
        if (dayEntries.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(l.emptyDay)),
        for (final entry in dayEntries)
          ListTile(
            leading: Icon(beverageIcon(entry.beverageId)),
            title: Text('${entryBeverageName(l, store, entry.beverageId)} · ${formatVolume(entry.amountMl, s.unit, locale)}'),
            subtitle: Text(DateFormat.Hm(locale).format(entry.at.toLocal())),
            trailing: IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => store.remove(entry.id),
            ),
          ),
      ],
    );
  }
}
