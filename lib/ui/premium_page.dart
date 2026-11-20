import 'package:flutter/material.dart';
import 'package:hydration_universe/l10n/app_localizations.dart';
import '../monetization/monetization.dart';

Future<void> openPremium(BuildContext context, MonetizationController money) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PremiumPage(money: money)));

class PremiumPage extends StatelessWidget {
  const PremiumPage({super.key, required this.money});
  final MonetizationController money;

  String _planName(AppLocalizations l, String id) => switch (id) {
        ProductIds.monthly => l.planMonthly,
        ProductIds.yearly => l.planYearly,
        ProductIds.lifetime => l.planLifetime,
        _ => id,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: money,
      builder: (context, _) {
        final pending = money.state == PurchaseState.pending;
        return Scaffold(
          appBar: AppBar(title: Text(l.premiumTitle)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Icon(Icons.workspace_premium, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(money.isPremium ? l.premiumActive : l.premiumSubtitle,
                  textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              for (final benefit in [l.benefitNoAds, l.benefitDrinks, l.benefitStats, l.benefitCsv, l.benefitSupport])
                ListTile(leading: const Icon(Icons.check_circle_outline), title: Text(benefit)),
              const SizedBox(height: 8),
              Text(l.freeForever, style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              if (money.isPremium)
                Card(child: ListTile(leading: const Icon(Icons.verified), title: Text(l.premiumThanks)))
              else if (!money.storeAvailable)
                Card(child: ListTile(leading: const Icon(Icons.cloud_off), title: Text(l.storeUnavailable)))
              else if (money.products.isEmpty)
                Card(child: ListTile(leading: const Icon(Icons.hourglass_empty), title: Text(l.productsUnavailable)))
              else
                for (final p in money.products)
                  Card(
                    child: ListTile(
                      title: Text(_planName(l, p.id)),
                      subtitle: p.id == ProductIds.yearly ? Text(l.bestValue) : null,
                      trailing: FilledButton(
                        onPressed: pending ? null : () => money.buy(p.id),
                        child: Text(p.price),
                      ),
                    ),
                  ),
              if (pending) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              if (money.state == PurchaseState.error)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(l.purchaseFailed, style: TextStyle(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: 8),
              TextButton(onPressed: pending ? null : money.restore, child: Text(l.restorePurchases)),
              const SizedBox(height: 8),
              Text(l.subscriptionTerms, style: theme.textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}
