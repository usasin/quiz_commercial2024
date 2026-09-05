import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InAppPurchaseService {
  // ---- Product IDs (DOIVENT être EXACTEMENT ceux de Play Console)
  static const String premiumMonthly = 'premium_monthly';
  static const String premiumYearly = 'premium_yearly';

  static const String creditsPackS = 'credits_pack_s';
  static const String creditsPackM = 'credits_pack_m';
  static const String creditsPackL = 'credits_pack_l';
  static const String intensiveExamPass = 'intensive_exam_pass';

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _sub;

  final Map<String, ProductDetails> _products = {};
  bool _available = false;

  bool get isAvailable => _available;

  ProductDetails? getProduct(String id) => _products[id];

  List<ProductDetails> get allProducts => _products.values.toList();

  // Purchase callback
  /// Retourne true uniquement si l'achat est livré ou avait déjà été livré.
  /// En cas d'échec de vérification, l'achat reste en attente afin de pouvoir
  /// être retraité au prochain démarrage/restauration.
  final Future<bool> Function(PurchaseDetails purchase) onDeliverPurchase;

  InAppPurchaseService({required this.onDeliverPurchase});

  Future<void> init() async {
    _available = await _iap.isAvailable();
    if (!_available) return;

    _sub?.cancel();
    _sub = _iap.purchaseStream.listen(
          (purchases) async {
        for (final p in purchases) {
          await _handlePurchase(p);
        }
      },
      onError: (_) {},
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  Future<bool> loadProducts({Duration timeout = const Duration(seconds: 25)}) async {
    if (!_available) {
      _available = await _iap.isAvailable();
      if (!_available) return false;
    }

    // Le Pass intensif est un produit ponctuel consommable. Les anciens packs
    // restent reconnus pour compatibilité, mais ne sont plus affichés.
    final ids = <String>{
      premiumMonthly,
      premiumYearly,
      intensiveExamPass,
    };

    try {
      final resp = await _iap
          .queryProductDetails(ids)
          .timeout(timeout);

      _products.clear();
      for (final p in resp.productDetails) {
        _products[p.id] = p;
      }

      // Si notFoundIDs n'est pas vide => souci config Play Console / install / test
      return _products.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> buy(ProductDetails product) async {
    final param = PurchaseParam(
      productDetails: product,
      applicationUserName: FirebaseAuth.instance.currentUser?.uid,
    );

    final id = product.id;
    final isCreditsPack =
        id == creditsPackS ||
        id == creditsPackM ||
        id == creditsPackL ||
        id == intensiveExamPass;

    if (isCreditsPack) {
      await _iap.buyConsumable(
        purchaseParam: param,
        autoConsume: true, // Android: permet de racheter le même pack
      );
    } else {
      await _iap.buyNonConsumable(purchaseParam: param);
    }
  }

  Future<void> restore() async {
    await _iap.restorePurchases();
  }

  /// Compat: certains écrans appellent encore restorePurchases().
  /// On garde un alias pour éviter des erreurs de compilation.
  Future<void> restorePurchases() => restore();


  Future<void> _handlePurchase(PurchaseDetails p) async {
    if (p.status == PurchaseStatus.pending) {
      return;
    }

    if (p.status == PurchaseStatus.error) {
      // tu peux logger p.error
      return;
    }

    if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
      // livraison (crédits/premium)
      final canComplete = await onDeliverPurchase(p);
      if (p.pendingCompletePurchase && canComplete) {
        await _iap.completePurchase(p);
      }
      return;
    }

    if (p.pendingCompletePurchase) {
      await _iap.completePurchase(p);
    }
  }
}
