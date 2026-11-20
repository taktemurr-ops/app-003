import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hydration_universe/monetization/monetization.dart';

class FakePurchases implements PurchaseService {
  final controller = StreamController<({PurchaseState state, String? productId, String? message})>.broadcast();
  final bought = <String>[];
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<StoreProduct>> loadProducts() async =>
      const [StoreProduct(id: ProductIds.yearly, title: 'Yearly', price: '₺199,99')];
  @override
  Future<void> buy(String productId) async {
    bought.add(productId);
    controller.add((state: PurchaseState.success, productId: productId, message: null));
  }
  @override
  Future<void> restore() async =>
      controller.add((state: PurchaseState.restored, productId: ProductIds.lifetime, message: null));
  @override
  Stream<({PurchaseState state, String? productId, String? message})> get updates => controller.stream;
  @override
  void dispose() => controller.close();
}

class FakeAds extends NoAdsService {
  @override
  bool get canRequestAds => true;
}

Future<void> flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('free users see ads only after consent allows it', () async {
    final m = MonetizationController(purchases: FakePurchases(), ads: FakeAds());
    await m.initialize();
    expect(m.isPremium, isFalse);
    expect(m.showAds, isTrue);
    final noConsent = MonetizationController(purchases: FakePurchases(), ads: NoAdsService());
    await noConsent.initialize();
    expect(noConsent.showAds, isFalse);
  });

  test('purchase grants premium, removes ads and persists', () async {
    final m = MonetizationController(purchases: FakePurchases(), ads: FakeAds());
    await m.initialize();
    expect(m.products.single.price, '₺199,99');
    await m.buy(ProductIds.yearly);
    await flush();
    expect(m.isPremium, isTrue);
    expect(m.showAds, isFalse);
    expect(m.has(PremiumFeature.csvExport), isTrue);
    final again = MonetizationController(purchases: FakePurchases(), ads: FakeAds());
    await again.initialize();
    expect(again.isPremium, isTrue);
    expect(again.ownedProductId, ProductIds.yearly);
  });

  test('restore grants premium; revoke clears it', () async {
    final m = MonetizationController(purchases: FakePurchases(), ads: FakeAds());
    await m.initialize();
    await m.restore();
    await flush();
    expect(m.ownedProductId, ProductIds.lifetime);
    await m.revoke();
    expect(m.isPremium, isFalse);
  });

  test('unknown product ids are never granted', () async {
    final m = MonetizationController(purchases: FakePurchases(), ads: FakeAds());
    await expectLater(m.grant('free_money'), throwsArgumentError);
    SharedPreferences.setMockInitialValues({
      MonetizationController.entitlementKey: '{"active":true,"productId":"hacked"}',
    });
    final cached = MonetizationController(purchases: UnavailablePurchaseService(), ads: NoAdsService());
    await cached.initialize();
    expect(cached.isPremium, isFalse);
    expect(cached.storeAvailable, isFalse);
  });
}
