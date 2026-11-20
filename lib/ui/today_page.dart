import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hydration_universe/l10n/app_localizations.dart';
import '../beverages.dart';
import '../hydration.dart';
import '../hydration_store.dart';
import '../localized_integer.dart';
import '../reminders.dart';
import '../units.dart';
import 'common.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key, required this.store});
  final HydrationStore store;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final amount = TextEditingController();

  HydrationStore get store => widget.store;

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> _log(AppLocalizations l, int ml, Beverage beverage) async {
    final messenger = ScaffoldMessenger.of(context);
    final locale = localeTag(context);
    final entry = await store.add(ml, beverage: beverage);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l.addedDrink(formatVolume(ml, store.settings.unit, locale), beverageName(l, beverage))),
        action: SnackBarAction(label: l.undo, onPressed: () => store.remove(entry.id)),
      ));
  }

  Future<void> _logCustom(AppLocalizations l) async {
    final unit = store.settings.unit;
    final maxInUnit = mlToUnit(2000, unit).floor();
    final value = parseLocalizedWholeNumber(amount.text, min: 1, max: maxInUnit);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.invalidAmount(maxInUnit.toString()))));
      return;
    }
    final ml = unitToMl(value, unit).clamp(1, 2000).toInt();
    amount.clear();
    FocusScope.of(context).unfocus();
    await _log(l, ml, store.selectedBeverage);
  }

  Future<void> _edit(AppLocalizations l, WaterEntry entry) async {
    final unit = store.settings.unit;
    final controller = TextEditingController(text: mlToUnit(entry.amountMl, unit).round().toString());
    final maxInUnit = mlToUnit(2000, unit).floor();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.editEntry),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l.amountIn(unitSuffix(unit)), border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, parseLocalizedWholeNumber(controller.text, min: 1, max: maxInUnit)),
            child: Text(l.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    await store.updateAmount(entry.id, unitToMl(result, unit).clamp(1, 2000).toInt());
  }

  Future<void> _delete(AppLocalizations l, WaterEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    await store.remove(entry.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l.entryDeleted),
        action: SnackBarAction(label: l.undo, onPressed: () => store.restore(entry)),
      ));
  }

  String _paceText(AppLocalizations l, PaceStatus status) => switch (status) {
        PaceStatus.done => l.paceDone,
        PaceStatus.ahead => l.paceAhead,
        PaceStatus.onTrack => l.paceOnTrack,
        PaceStatus.behind => l.paceBehind,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = localeTag(context);
    final theme = Theme.of(context);
    final s = store.settings;
    final now = DateTime.now();
    final goal = store.goalMl;
    final hydration = store.hydrationFor(now);
    final caffeine = store.caffeineFor(now);
    final entries = store.entriesFor(now);
    final remaining = (goal - hydration).clamp(0, goal).toInt();
    final percent = goal == 0 ? 0 : (hydration * 100 / goal).round();
    final pace = paceStatus(now, s, goal, hydration);
    final next = nextReminder(now: now, settings: s, hydrationTodayMl: hydration, goalMl: goal);
    final muted = isMutedOn(now, s);
    final selected = store.selectedBeverage;
    final fmt = NumberFormat.decimalPattern(locale);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: ProgressRing(
            progress: goal == 0 ? 0 : hydration / goal,
            child: Semantics(
              label: l.progressSemantics(formatVolume(hydration, s.unit, locale), formatVolume(goal, s.unit, locale)),
              excludeSemantics: true,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${fmt.format(percent)}%', style: theme.textTheme.displaySmall),
                Text(formatVolume(hydration, s.unit, locale), style: theme.textTheme.titleMedium),
                Text(l.ofGoal(formatVolume(goal, s.unit, locale)), style: theme.textTheme.bodySmall),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            remaining == 0 ? l.goalReached : l.remaining(formatVolume(remaining, s.unit, locale)),
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 4),
        Center(child: Text(_paceText(l, pace), textAlign: TextAlign.center)),
        const SizedBox(height: 12),
        Card(
          child: Column(children: [
            ListTile(
              leading: Icon(Icons.coffee, color: caffeine > s.caffeineLimitMg ? theme.colorScheme.error : null),
              title: Text(l.caffeineToday(fmt.format(caffeine), fmt.format(s.caffeineLimitMg))),
              subtitle: caffeine > s.caffeineLimitMg ? Text(l.caffeineOver) : null,
            ),
            ListTile(
              leading: Icon(muted ? Icons.notifications_off : Icons.notifications_active),
              title: Text(!s.remindersEnabled
                  ? l.remindersOff
                  : next == null
                      ? l.noReminder
                      : l.nextReminder(isSameLocalDay(next, now)
                          ? DateFormat.Hm(locale).format(next)
                          : '${l.tomorrow} ${DateFormat.Hm(locale).format(next)}')),
              trailing: s.remindersEnabled
                  ? TextButton(
                      onPressed: () => store.updateSettings(
                          s.copyWith(mutedDateKey: () => muted ? null : dateKey(now))),
                      child: Text(muted ? l.unmuteToday : l.muteToday),
                    )
                  : null,
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Text(l.drink, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final b in store.allBeverages)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    avatar: Icon(beverageIcon(b.id), size: 18),
                    label: Text(beverageName(l, b)),
                    selected: b.id == selected.id,
                    onSelected: (_) => store.updateSettings(s.copyWith(selectedBeverageId: b.id)),
                  ),
                ),
            ],
          ),
        ),
        if (selected.hydrationPercent != 100 || selected.caffeinePer100Ml > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.beverageFactors(fmt.format(selected.hydrationPercent), fmt.format(selected.caffeinePer100Ml)),
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final ml in s.quickAmountsMl)
              FilledButton.tonalIcon(
                onPressed: () => _log(l, ml, selected),
                icon: Icon(beverageIcon(selected.id)),
                label: Text('+${formatVolume(ml, s.unit, locale)}'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _logCustom(l),
              decoration: InputDecoration(
                labelText: l.amountIn(unitSuffix(s.unit)),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: () => _logCustom(l), child: Text(l.add)),
        ]),
        const SizedBox(height: 24),
        Text(l.history, style: theme.textTheme.titleMedium),
        if (entries.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(l.empty)),
        for (final entry in entries)
          ListTile(
            leading: Icon(beverageIcon(entry.beverageId)),
            title: Text('${entryBeverageName(l, store, entry.beverageId)} · ${formatVolume(entry.amountMl, s.unit, locale)}'),
            subtitle: Text(DateFormat.Hm(locale).format(entry.at.toLocal())),
            onTap: () => _edit(l, entry),
            trailing: IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(l, entry),
            ),
          ),
        const SizedBox(height: 16),
        Text(l.privacy, style: theme.textTheme.bodySmall),
        Text(l.notMedical, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
