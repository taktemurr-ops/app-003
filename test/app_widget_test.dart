import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hydration_universe/hydration_store.dart';
import 'package:hydration_universe/main.dart';
import 'package:hydration_universe/monetization/monetization.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<HydrationStore> pumpApp(WidgetTester tester) async {
    final store = HydrationStore();
    await tester.pumpWidget(HydrationUniverseApp(
      key: UniqueKey(),
      store: store,
      money: MonetizationController(purchases: UnavailablePurchaseService(), ads: NoAdsService()),
    ));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('onboarding, quick add, undo and navigation', (tester) async {
    final store = await pumpApp(tester);
    expect(find.text('Welcome'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Hydration Universe'), findsWidgets);
    expect(find.text('2,000 mL to go'), findsOneWidget);

    await tester.tap(find.text('+250 mL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(store.totalFor(DateTime.now()), 250);
    expect(find.text('1,750 mL to go'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(store.totalFor(DateTime.now()), 0);

    for (final tab in ['History', 'Statistics', 'Settings', 'Today']) {
      await tester.tap(find.widgetWithText(NavigationDestination, tab));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked premium features open the paywall', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Skip, use 2 L'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Statistics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 days'));
    await tester.pumpAndSettle();
    expect(find.text('No ads'), findsOneWidget);
    expect(find.text('The store is not available on this device right now.'), findsOneWidget);
  });

  testWidgets('renders in Turkish and Arabic (RTL)', (tester) async {
    for (final locale in const [Locale('tr'), Locale('ar')]) {
      tester.platformDispatcher.localesTestValue = [locale];
      await pumpApp(tester);
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (locale.languageCode == 'ar') {
        expect(Directionality.of(tester.element(find.byType(NavigationBar))), TextDirection.rtl);
      }
      SharedPreferences.setMockInitialValues({});
    }
    tester.platformDispatcher.clearLocalesTestValue();
  });
}
