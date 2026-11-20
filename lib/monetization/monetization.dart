import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Store product identifiers. Create products with exactly these ids in
/// App Store Connect and Google Play Console.
class ProductIds {
  static const monthly = 'hydration_premium_monthly';
  static const yearly = 'hydration_premium_yearly';
  static const lifetime = 'hydration_premium_lifetime';
  static const all = {monthly, yearly, lifetime};
  static const subscriptions = {monthly, yearly};
}

/// What free users get vs. premium. Core tracking, reminders, JSON backup and
/// data deletion always stay free (users' data rights and the most common
/// complaint about competitors charging for basics).
class FreeLimits {
  static const customDrinks = 3;
  static const statsDays = 7;
}

enum PremiumFeature { removeAds, unlimitedDrinks, longStats, csvExport }

/// A product as shown in the paywall (price comes from the store, localized).
class StoreProduct {
  const StoreProduct({required this.id, required this.title, required this.price});
  final String id;
  final String title;
  final String price;
}

enum PurchaseState { idle, pending, success, error, canceled, restored }

/// Store abstraction so UI and tests never depend on platform channels.
abstract class PurchaseService {
  Future<bool> isAvailable();
  Future<List<StoreProduct>> loadProducts();
  Future<void> buy(String productId);
  Future<void> restore();

  /// Emits product ids that the store confirmed as owned (purchased/restored),
  /// plus state changes for UI feedback.
  Stream<({PurchaseState state, String? productId, String? message})> get updates;
  void dispose();
}

/// Ads abstraction (banner + consent).
abstract class AdsService {
  Future<void> initialize();
  bool get canRequestAds;
  bool get privacyOptionsRequired;
  Future<void> showPrivacyOptions();
  Widget banner();
}

class NoAdsService implements AdsService {
  @override
  Future<void> initialize() async {}
  @override
  bool get canRequestAds => false;
  @override
  bool get privacyOptionsRequired => false;
  @override
  Future<void> showPrivacyOptions() async {}
  @override
  Widget banner() => const SizedBox.shrink();
}

class UnavailablePurchaseService implements PurchaseService {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<List<StoreProduct>> loadProducts() async => const [];
  @override
  Future<void> buy(String productId) async {}
  @override
  Future<void> restore() async {}
  @override
  Stream<({PurchaseState state, String? productId, String? message})> get updates => const Stream.empty();
  @override
  void dispose() {}
}

/// Holds premium entitlement and wires the store + ads together.
///
/// Entitlement is cached locally after the store confirms a purchase. For
/// production, subscription expiry should additionally be verified on a
/// server (App Store Server API / Google Play Developer API).
class MonetizationController extends ChangeNotifier {
  MonetizationController({required this.purchases, required this.ads});

  static const entitlementKey = 'premium_entitlement_v1';

  final PurchaseService purchases;
  final AdsService ads;

  bool _premium = false;
  String? _productId;
  bool _storeAvailable = false;
  List<StoreProduct> _products = const [];
  PurchaseState _state = PurchaseState.idle;
  String? _message;
  bool _initialized = false;

  bool get isPremium => _premium;
  String? get ownedProductId => _productId;
  bool get storeAvailable => _storeAvailable;
  List<StoreProduct> get products => _products;
  PurchaseState get state => _state;
  String? get message => _message;
  bool get showAds => !_premium && ads.canRequestAds;

  bool has(PremiumFeature feature) => _premium;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(entitlementKey);
    if (raw != null) {
      try {
        final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final id = json['productId'];
        if (json['active'] == true && id is String && ProductIds.all.contains(id)) {
          _premium = true;
          _productId = id;
        }
      } catch (_) {
        // Ignore a corrupt cache; a store restore will rebuild it.
      }
    }
    notifyListeners();
    purchases.updates.listen(_onUpdate);
    try {
      _storeAvailable = await purchases.isAvailable();
      if (_storeAvailable) _products = await purchases.loadProducts();
    } catch (_) {
      _storeAvailable = false;
    }
    notifyListeners();
    if (!_premium) {
      try {
        await ads.initialize();
      } catch (_) {
        // Ads are optional; the app must work without them.
      }
      notifyListeners();
    }
  }

  Future<void> _onUpdate(({PurchaseState state, String? productId, String? message}) u) async {
    _state = u.state;
    _message = u.message;
    final id = u.productId;
    if ((u.state == PurchaseState.success || u.state == PurchaseState.restored) && id != null && ProductIds.all.contains(id)) {
      await grant(id);
    }
    notifyListeners();
  }

  Future<void> grant(String productId) async {
    if (!ProductIds.all.contains(productId)) throw ArgumentError.value(productId, 'productId');
    _premium = true;
    _productId = productId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      entitlementKey,
      jsonEncode({'active': true, 'productId': productId, 'grantedAtUtc': DateTime.now().toUtc().toIso8601String()}),
    );
    notifyListeners();
  }

  /// Clears the cached entitlement (e.g. after a refund or expired restore).
  Future<void> revoke() async {
    _premium = false;
    _productId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(entitlementKey);
    notifyListeners();
  }

  Future<void> buy(String productId) async {
    _state = PurchaseState.pending;
    _message = null;
    notifyListeners();
    try {
      await purchases.buy(productId);
    } catch (e) {
      _state = PurchaseState.error;
      _message = e.toString();
      notifyListeners();
    }
  }

  Future<void> restore() async {
    _state = PurchaseState.pending;
    notifyListeners();
    try {
      await purchases.restore();
    } catch (e) {
      _state = PurchaseState.error;
      _message = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    purchases.dispose();
    super.dispose();
  }
}
