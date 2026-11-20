import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:hydration_universe/l10n/app_localizations.dart';
import '../goal.dart';
import '../hydration_store.dart';
import '../localized_integer.dart';
import '../monetization/monetization.dart';
import '../privacy_export.dart';
import '../settings.dart';
import '../units.dart';
import 'common.dart';
import 'premium_page.dart';

/// Profile fields shared by onboarding and settings.
class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key, required this.settings, required this.onChanged});
  final HydrationSettings settings;
  final ValueChanged<HydrationSettings> onChanged;

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late final TextEditingController weight =
      TextEditingController(text: widget.settings.weightKg?.toString() ?? '');

  @override
  void dispose() {
    weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = widget.settings;
    final fmt = NumberFormat.decimalPattern(localeTag(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: weight,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: l.weightKg, helperText: l.weightHelp, border: const OutlineInputBorder()),
        onChanged: (text) {
          final value = parseLocalizedWholeNumber(text, min: 20, max: 300);
          if (text.trim().isEmpty || value != null) widget.onChanged(s.copyWith(weightKg: () => value));
        },
      ),
      const SizedBox(height: 16),
      Text(l.exercisePerDay(fmt.format(s.exerciseMinutes))),
      Slider(
        value: s.exerciseMinutes.toDouble().clamp(0, 180),
        min: 0,
        max: 180,
        divisions: 12,
        label: fmt.format(s.exerciseMinutes),
        onChanged: (v) => widget.onChanged(s.copyWith(exerciseMinutes: v.round())),
      ),
      Text(l.climate),
      const SizedBox(height: 8),
      SegmentedButton<Climate>(
        showSelectedIcon: false,
        segments: [for (final c in Climate.values) ButtonSegment(value: c, label: Text(climateLabel(l, c)))],
        selected: {s.climate},
        onSelectionChanged: (v) => widget.onChanged(s.copyWith(climate: v.first)),
      ),
      const SizedBox(height: 16),
      Text(l.lifeStage),
      const SizedBox(height: 8),
      SegmentedButton<LifeStage>(
        showSelectedIcon: false,
        segments: [for (final c in LifeStage.values) ButtonSegment(value: c, label: Text(lifeStageLabel(l, c)))],
        selected: {s.lifeStage},
        onSelectionChanged: (v) => widget.onChanged(s.copyWith(lifeStage: v.first)),
      ),
    ]);
  }
}

class GoalBreakdownCard extends StatelessWidget {
  const GoalBreakdownCard({super.key, required this.settings});
  final HydrationSettings settings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = localeTag(context);
    final g = calculateGoal(settings);
    final u = settings.unit;
    String v(int ml) => formatVolume(ml, u, locale);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.dailyGoal(v(g.totalMl)), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (g.isManual)
            Text(l.goalManualNote)
          else ...[
            Text(settings.weightKg == null ? l.goalBaseDefault(v(g.baseMl)) : l.goalBaseWeight(v(g.baseMl))),
            if (g.activityMl > 0) Text(l.goalActivity(v(g.activityMl))),
            if (g.climateMl > 0) Text(l.goalClimate(v(g.climateMl))),
            if (g.lifeStageMl > 0) Text(l.goalLifeStage(v(g.lifeStageMl))),
          ],
          const SizedBox(height: 8),
          Text(l.notMedical, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.store, required this.money});
  final HydrationStore store;
  final MonetizationController money;

  Future<void> _pickTime(BuildContext context, int minutes, ValueChanged<int> onPicked) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
    if (picked != null) onPicked(picked.hour * 60 + picked.minute);
  }

  Future<void> _manualGoal(BuildContext context, AppLocalizations l) async {
    final s = store.settings;
    final controller = TextEditingController(text: (s.manualGoalMl ?? store.goalMl).toString());
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.manualGoal),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l.amountIn('mL'), helperText: l.manualGoalRange, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, parseLocalizedWholeNumber(controller.text, min: 500, max: 8000)),
            child: Text(l.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) await store.updateSettings(s.copyWith(manualGoalMl: () => value));
  }

  Future<void> _quickAmounts(BuildContext context, AppLocalizations l) async {
    final s = store.settings;
    final controller = TextEditingController(text: s.quickAmountsMl.join(' '));
    final value = await showDialog<List<int>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.quickAmounts),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(helperText: l.quickAmountsHelp, helperMaxLines: 3, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
          FilledButton(
            onPressed: () {
              final parts = controller.text.trim().split(RegExp(r'\s+'));
              final values = [for (final p in parts) parseLocalizedWholeNumber(p, min: 1, max: 2000)];
              final valid = values.isNotEmpty && values.length <= 6 && values.every((v) => v != null);
              Navigator.pop(context, valid ? values.cast<int>() : null);
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) await store.updateSettings(s.copyWith(quickAmountsMl: value));
  }

  Future<void> _addDrink(BuildContext context, AppLocalizations l) async {
    if (!money.has(PremiumFeature.unlimitedDrinks) && store.customBeverages.length >= FreeLimits.customDrinks) {
      await openPremium(context, money);
      return;
    }
    final name = TextEditingController();
    final hydration = TextEditingController(text: '100');
    final caffeine = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.newDrink),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, maxLength: 40, decoration: InputDecoration(labelText: l.drinkName)),
            TextField(
              controller: hydration,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.hydrationPercent, helperText: '0–150'),
            ),
            TextField(
              controller: caffeine,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.caffeinePer100, helperText: '0–500'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.save)),
        ],
      ),
    );
    final h = parseLocalizedWholeNumber(hydration.text, min: 0, max: 150);
    final c = parseLocalizedWholeNumber(caffeine.text, min: 0, max: 500);
    final n = name.text.trim();
    name.dispose();
    hydration.dispose();
    caffeine.dispose();
    if (ok != true) return;
    if (n.isEmpty || h == null || c == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.invalidDrink)));
      }
      return;
    }
    try {
      await store.addCustomBeverage(n, h, c);
    } on StateError {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.tooManyDrinks)));
      }
    }
  }

  Future<void> _copy(BuildContext context, AppLocalizations l, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.copied)));
    }
  }

  Future<void> _deleteAll(BuildContext context, AppLocalizations l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteAllTitle),
        content: Text(l.deleteAllBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.deleteAllConfirm),
          ),
        ],
      ),
    );
    if (ok == true) await store.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = localeTag(context);
    final theme = Theme.of(context);
    final s = store.settings;
    final fmt = NumberFormat.decimalPattern(locale);
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
          child: Text(text, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        header(l.sectionGoal),
        GoalBreakdownCard(settings: s),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.manualGoal),
          subtitle: Text(s.manualGoalMl == null ? l.manualGoalOff : formatVolume(s.manualGoalMl!, s.unit, locale)),
          value: s.manualGoalMl != null,
          onChanged: (on) => on ? _manualGoal(context, l) : store.updateSettings(s.copyWith(manualGoalMl: () => null)),
        ),
        if (s.manualGoalMl == null) ProfileEditor(settings: s, onChanged: store.updateSettings),
        header(l.sectionUnits),
        SegmentedButton<VolumeUnit>(
          showSelectedIcon: false,
          segments: [for (final u in VolumeUnit.values) ButtonSegment(value: u, label: Text(unitLabel(l, u)))],
          selected: {s.unit},
          onSelectionChanged: (v) => store.updateSettings(s.copyWith(unit: v.first)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.quickAmounts),
          subtitle: Text(s.quickAmountsMl.map((ml) => formatVolume(ml, s.unit, locale)).join(' · ')),
          trailing: const Icon(Icons.edit),
          onTap: () => _quickAmounts(context, l),
        ),
        header(l.sectionReminders),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.remindersEnabled),
          value: s.remindersEnabled,
          onChanged: (v) => store.updateSettings(s.copyWith(remindersEnabled: v)),
        ),
        if (s.remindersEnabled) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.wb_sunny_outlined),
            title: Text(l.wakeTime),
            trailing: Text(minutesToTime(context, s.wakeMinutes)),
            onTap: () => _pickTime(context, s.wakeMinutes, (m) => store.updateSettings(s.copyWith(wakeMinutes: m))),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bedtime_outlined),
            title: Text(l.sleepTime),
            trailing: Text(minutesToTime(context, s.sleepMinutes)),
            onTap: () => _pickTime(context, s.sleepMinutes, (m) => store.updateSettings(s.copyWith(sleepMinutes: m))),
          ),
          Text(l.reminderInterval(fmt.format(s.reminderIntervalMinutes))),
          Slider(
            value: s.reminderIntervalMinutes.toDouble().clamp(30, 240),
            min: 30,
            max: 240,
            divisions: 14,
            label: fmt.format(s.reminderIntervalMinutes),
            onChanged: (v) => store.updateSettings(s.copyWith(reminderIntervalMinutes: v.round())),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.pauseAfterGoal),
            value: s.pauseAfterGoal,
            onChanged: (v) => store.updateSettings(s.copyWith(pauseAfterGoal: v)),
          ),
          Text(l.remindersInAppNote, style: theme.textTheme.bodySmall),
        ],
        header(l.sectionCaffeine),
        Text(l.caffeineLimit(fmt.format(s.caffeineLimitMg))),
        Slider(
          value: s.caffeineLimitMg.toDouble().clamp(0, 600),
          min: 0,
          max: 600,
          divisions: 12,
          label: fmt.format(s.caffeineLimitMg),
          onChanged: (v) => store.updateSettings(s.copyWith(caffeineLimitMg: v.round())),
        ),
        header(l.sectionDrinks),
        for (final b in store.customBeverages)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(beverageIcon(b.id)),
            title: Text(beverageName(l, b)),
            subtitle: Text(l.beverageFactors(fmt.format(b.hydrationPercent), fmt.format(b.caffeinePer100Ml))),
            trailing: IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => store.removeCustomBeverage(b.id),
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(onPressed: () => _addDrink(context, l), icon: const Icon(Icons.add), label: Text(l.newDrink)),
        ),
        header(l.premiumTitle),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.workspace_premium),
          title: Text(money.isPremium ? l.premiumActive : l.premiumTitle),
          subtitle: Text(money.isPremium ? l.premiumThanks : l.premiumSubtitle),
          onTap: () => openPremium(context, money),
        ),
        if (money.ads.privacyOptionsRequired)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l.adPrivacyOptions),
            onTap: () => money.ads.showPrivacyOptions(),
          ),
        header(l.sectionData),
        Text(l.privacy),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.table_chart_outlined),
          title: Text(l.copyCsv),
          trailing: money.has(PremiumFeature.csvExport) ? null : const Icon(Icons.lock_outline),
          onTap: () => money.has(PremiumFeature.csvExport)
              ? _copy(context, l, exportHydrationCsv(store.entries))
              : openPremium(context, money),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.data_object),
          title: Text(l.copyJson),
          onTap: () => _copy(context, l, exportHydrationEntries(store.entries)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
          title: Text(l.deleteAllTitle, style: TextStyle(color: theme.colorScheme.error)),
          onTap: () => _deleteAll(context, l),
        ),
        const SizedBox(height: 16),
        Text(l.notMedical, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
