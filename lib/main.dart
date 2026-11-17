import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hydration_universe/l10n/app_localizations.dart';
import 'hydration_store.dart';

void main() => runApp(const HydrationUniverseApp());

class HydrationUniverseApp extends StatelessWidget {
  const HydrationUniverseApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087EA4)), useMaterial3: true),
    home: const HydrationHome(),
  );
}

class HydrationHome extends StatefulWidget {
  const HydrationHome({super.key});

  @override
  State<HydrationHome> createState() => _HydrationHomeState();
}

class _HydrationHomeState extends State<HydrationHome> {
  final store = HydrationStore();
  final amount = TextEditingController(text: '250');

  @override
  void initState() {
    super.initState();
    store.addListener(_refresh);
    store.load();
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    store.removeListener(_refresh);
    store.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> _add(AppLocalizations l) async {
    final value = int.tryParse(amount.text.trim());
    if (value == null || value < 1 || value > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.invalid)));
      return;
    }
    await store.add(value);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final today = DateTime.now();
    final entries = store.entriesFor(today);
    final total = NumberFormat.decimalPattern(locale).format(store.totalFor(today));
    return Scaffold(
      appBar: AppBar(title: Text(l.appTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(l.today, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(l.total(total), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(l.privacy),
        const SizedBox(height: 16),
        TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l.amount, border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: () => _add(l), icon: const Icon(Icons.water_drop), label: Text(l.addWater)),
        const SizedBox(height: 24),
        Text(l.history, style: Theme.of(context).textTheme.titleMedium),
        if (entries.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(l.empty)),
        ...entries.map((entry) => ListTile(
          leading: const Icon(Icons.water_drop_outlined),
          title: Text('${NumberFormat.decimalPattern(locale).format(entry.amountMl)} mL'),
          subtitle: Text(DateFormat.Hm(locale).format(entry.at.toLocal())),
          trailing: IconButton(
            tooltip: l.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => store.remove(entry.id),
          ),
        )),
      ]),
    );
  }
}
