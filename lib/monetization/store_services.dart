import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'monetization.dart';

/// Ad unit ids. Defaults are Google's public TEST ids, so development builds
/// never serve real ads. Release builds pass real ids with
/// `--dart-define=ADMOB_BANNER_ANDROID=... --dart-define=ADMOB_BANNER_IOS=...`.
class AdUnits {
  static const _androidTest = 'ca-app-pub-3940256099942544/9214589741';
  static const _iosTest = 'ca-app-pub-3940256099942544/2435281174';
  static const _android = String.fromEnvironment('ADMOB_BANNER_ANDROID', defaultValue: _androidTest);
  static const _ios = String.fromEnvironment('ADMOB_BANNER_IOS', defaultValue: _iosTest);

  static String get banner => Platform.isIOS ? _ios : _android;
}

/// Google Mobile Ads with UMP consent (GDPR/UK/Swiss and US state privacy).
class GoogleAdsService implements AdsService {
  bool _canRequest = false;
  bool _privacyRequired = false;

  @override
  bool get canRequestAds => _canRequest;

  @override
  bool get privacyOptionsRequired => _privacyRequired;

  @override
  Future<void> initialize() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        if (!done.isCompleted) done.complete();
      },
      (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future.timeout(const Duration(seconds: 20), onTimeout: () {});
    _canRequest = await ConsentInformation.instance.canRequestAds();
    _privacyRequired = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
    if (_canRequest) await MobileAds.instance.initialize();
  }

  @override
  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((_) => done.complete());
    await done.future;
    _canRequest = await ConsentInformation.instance.canRequestAds();
  }

  @override
  Widget banner() => const _AdaptiveBanner();
}

class _AdaptiveBanner extends StatefulWidget {
  const _AdaptiveBanner();

  @override
  State<_AdaptiveBanner> createState() => _AdaptiveBannerState();
}

class _AdaptiveBannerState extends State<_AdaptiveBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _width;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width != _width) {
      _width = width;
      _load(width);
    }
  }

  Future<void> _load(int width) async {
    await _ad?.dispose();
    _ad = null;
    _loaded = false;
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;
    final ad = BannerAd(
      adUnitId: AdUnits.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(width: ad.size.width.toDouble(), height: ad.size.height.toDouble(), child: AdWidget(ad: ad)),
    );
  }
}

/// App Store / Google Play purchases through the official in_app_purchase plugin.
class StorePurchaseService implements PurchaseService {
  final _iap = InAppPurchase.instance;
  final _controller = StreamController<({PurchaseState state, String? productId, String? message})>.broadcast();
  final Map<String, ProductDetails> _details = {};
  StreamSubscription<List<PurchaseDetails>>? _sub;

  StorePurchaseService() {
    _sub = _iap.purchaseStream.listen(_handle, onError: (Object e) {
      _controller.add((state: PurchaseState.error, productId: null, message: e.toString()));
    });
  }

  Future<void> _handle(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _controller.add((state: PurchaseState.pending, productId: p.productID, message: null));
        case PurchaseStatus.purchased:
          _controller.add((state: PurchaseState.success, productId: p.productID, message: null));
        case PurchaseStatus.restored:
          _controller.add((state: PurchaseState.restored, productId: p.productID, message: null));
        case PurchaseStatus.error:
          _controller.add((state: PurchaseState.error, productId: p.productID, message: p.error?.message));
        case PurchaseStatus.canceled:
          _controller.add((state: PurchaseState.canceled, productId: p.productID, message: null));
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<List<StoreProduct>> loadProducts() async {
    final response = await _iap.queryProductDetails(ProductIds.all);
    _details
      ..clear()
      ..addEntries(response.productDetails.map((d) => MapEntry(d.id, d)));
    final order = [ProductIds.yearly, ProductIds.monthly, ProductIds.lifetime];
    return [
      for (final id in order)
        if (_details[id] != null) StoreProduct(id: id, title: _details[id]!.title, price: _details[id]!.price),
    ];
  }

  @override
  Future<void> buy(String productId) async {
    final details = _details[productId];
    if (details == null) throw StateError('Product not loaded: $productId');
    // Subscriptions and the lifetime unlock are all non-consumables here.
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: details));
  }

  @override
  Future<void> restore() => _iap.restorePurchases();

  @override
  Stream<({PurchaseState state, String? productId, String? message})> get updates => _controller.stream;

  @override
  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
