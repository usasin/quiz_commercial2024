import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'in_app_purchase_service.dart';
import 'usage_meter.dart';

class DeliveryResult {
  final bool delivered;
  final bool ignored;
  final bool isRestore;
  final String? message;

  const DeliveryResult({
    required this.delivered,
    required this.ignored,
    required this.isRestore,
    this.message,
  });
}

class PurchaseDelivery {
  static String purchaseToken(PurchaseDetails p) {
    final t = (p.purchaseID ?? '').trim();
    if (t.isNotEmpty) return t;
    final v = (p.verificationData.serverVerificationData).trim();
    if (v.isNotEmpty) return v;
    final d = (p.transactionDate ?? '').trim();
    if (d.isNotEmpty) return '${p.productID}:$d';
    return p.productID;
  }

  static bool _isPremium(String id) =>
      id == InAppPurchaseService.premiumMonthly ||
      id == InAppPurchaseService.premiumYearly;

  static bool _isCredits(String id) =>
      id == InAppPurchaseService.creditsPackS ||
      id == InAppPurchaseService.creditsPackM ||
      id == InAppPurchaseService.creditsPackL ||
      id == InAppPurchaseService.intensiveExamPass;

  static bool _isIntensiveExamPass(String id) =>
      id == InAppPurchaseService.intensiveExamPass;

  /// Professional delivery rules:
  /// - Premium: delivered on purchased AND restored
  /// - Credits packs: delivered ONLY on purchased (consumables should not be "restored")
  /// - Idempotent: same token => no double delivery
  static Future<DeliveryResult> deliver(
    PurchaseDetails p, {
    required UsageMeter meter,
  }) async {
    if (p.status != PurchaseStatus.purchased &&
        p.status != PurchaseStatus.restored) {
      return const DeliveryResult(
          delivered: false, ignored: true, isRestore: false);
    }

    final id = p.productID;

    // Ignore restores for consumables (credits)
    if (_isCredits(id) && p.status == PurchaseStatus.restored) {
      await meter.syncFromCloud(); // keep UI consistent if premium was restored elsewhere
      return const DeliveryResult(
        delivered: false,
        ignored: true,
        isRestore: true,
        message: 'Restauration effectuée (abonnements uniquement).',
      );
    }

    // Idempotence
    final token = purchaseToken(p);
    final already = await meter.wasPurchaseDelivered(token);
    // Les abonnements sont toujours revérifiés côté serveur : cela permet de
    // récupérer les anciens abonnés dans l'Admin et de suivre leur statut.
    // Seuls les packs consommables doivent être bloqués par l'idempotence locale.
    if (already && _isCredits(id)) {
      return DeliveryResult(
        delivered: false,
        ignored: true,
        isRestore: p.status == PurchaseStatus.restored,
      );
    }
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('verifyAndroidPurchase')
          .call({
        'productId': id,
        'verificationData': p.verificationData.serverVerificationData,
      });
      final raw = result.data;
      final data = raw is Map
          ? raw.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      if (data['verified'] != true) {
        return const DeliveryResult(
          delivered: false,
          ignored: false,
          isRestore: false,
          message: 'Achat reçu, vérification en attente.',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      await meter.syncFromCloud(takeMaxCredits: false);
      return DeliveryResult(
        delivered: false,
        ignored: false,
        isRestore: p.status == PurchaseStatus.restored,
        message: e.message ?? 'Vérification Google Play indisponible.',
      );
    } catch (_) {
      await meter.syncFromCloud(takeMaxCredits: false);
      return DeliveryResult(
        delivered: false,
        ignored: false,
        isRestore: p.status == PurchaseStatus.restored,
        message: 'Vérification temporairement indisponible. L’achat sera réessayé.',
      );
    }

    await meter.markPurchaseDelivered(token);

    if (_isPremium(id)) {
      await meter.setPremium(true);
      await meter.setActivePlan(id == InAppPurchaseService.premiumMonthly
          ? 'PREMIUM_MONTHLY'
          : 'PREMIUM_YEARLY');
    } else if (_isCredits(id)) {
      await meter.syncFromCloud(takeMaxCredits: false);
    }

    // Le serveur a déjà écrit les droits vérifiés. On rafraîchit le cache local.
    await meter.syncFromCloud(takeMaxCredits: false);

    return DeliveryResult(
      delivered: true,
      ignored: false,
      isRestore: p.status == PurchaseStatus.restored,
      message: p.status == PurchaseStatus.restored
          ? 'Achats restaurés.'
          : _isIntensiveExamPass(id)
              ? 'Pass intensif activé. Ton examen est prêt.'
              : 'Achat réussi !',
    );
  }
}
