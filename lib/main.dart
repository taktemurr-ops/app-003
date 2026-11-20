import 'package:flutter/material.dart';
import 'package:hydration_universe/l10n/app_localizations.dart';
import 'hydration_store.dart';
import 'monetization/monetization.dart';
import 'monetization/store_services.dart';
import 'ui/premium_page.dart';
import 'ui/history_page.dart';
import 'ui/settings_page.dart';
import 'ui/stats_page.dart';
import 'ui/today_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(HydrationUniverseApp(
    store: HydrationStore(),
    money: MonetizationController(purchases: StorePurchaseService(), ads: GoogleAdsService()),
  ));
}

class HydrationUniverseApp extends StatefulWidget {
  const HydrationUniverseApp({super.key, required this.store, required this.money});
  final HydrationStore store;
  final MonetizationController money;

  @override
  State<HydrationUniverseApp> createState() => _HydrationUniverseAppState();
}

class _HydrationUniverseAppState extends State<HydrationUniverseApp> {
  @override
  void initState() {
    super.initState();
    widget.store.load();
    widget.money.initialize();
  }

  @override
  void dispose() {
    widget.store.dispose();
    widget.money.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF087EA4);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seed), useMaterial3: true),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: ListenableBuilder(
        listenable: Listenable.merge([widget.store, widget.money]),
        builder: (context, _) {
          if (!widget.store.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (!widget.store.settings.onboarded) return OnboardingPage(store: widget.store);
          return HydrationHome(store: widget.store, money: widget.money);
        },
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.store});
  final HydrationStore store;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = store.settings;
    return Scaffold(
      appBar: AppBar(title: Text(l.welcomeTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.welcomeBody),
          const SizedBox(height: 16),
          ProfileEditor(settings: s, onChanged: store.updateSettings),
          const SizedBox(height: 16),
          GoalBreakdownCard(settings: s),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => store.updateSettings(store.settings.copyWith(onboarded: true)),
            child: Text(l.start),
          ),
          TextButton(
            onPressed: () => store.updateSettings(store.settings.copyWith(onboarded: true)),
            child: Text(l.skip),
          ),
        ],
      ),
    );
  }
}

class HydrationHome extends StatefulWidget {
  const HydrationHome({super.key, required this.store, required this.money});
  final HydrationStore store;
  final MonetizationController money;

  @override
  State<HydrationHome> createState() => _HydrationHomeState();
}

class _HydrationHomeState extends State<HydrationHome> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final store = widget.store;
    final money = widget.money;
    final titles = [l.appTitle, l.tabHistory, l.tabStats, l.tabSettings];
    final pages = [
      TodayPage(store: store),
      HistoryPage(store: store),
      StatsPage(store: store, money: money),
      SettingsPage(store: store, money: money),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(titles[tab]), actions: [
        if (!money.isPremium)
          IconButton(
            tooltip: l.premiumTitle,
            icon: const Icon(Icons.workspace_premium_outlined),
            onPressed: () => openPremium(context, money),
          ),
      ]),
      body: SafeArea(
        child: Column(children: [
          Expanded(child: pages[tab]),
          if (money.showAds) money.ads.banner(),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.water_drop_outlined), selectedIcon: const Icon(Icons.water_drop), label: l.tabToday),
          NavigationDestination(icon: const Icon(Icons.calendar_month_outlined), selectedIcon: const Icon(Icons.calendar_month), label: l.tabHistory),
          NavigationDestination(icon: const Icon(Icons.insights_outlined), selectedIcon: const Icon(Icons.insights), label: l.tabStats),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: l.tabSettings),
        ],
      ),
    );
  }
}
