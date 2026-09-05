import 'dart:async';

import 'in_app_purchase_service.dart';
import 'purchase_delivery.dart';
import 'usage_meter.dart';

/// Runs a silent restore at app start (UX pro).
///
/// - Does NOT show UI.
/// - Restores Premium automatically if the Store account has an active sub.
/// - Only restores Premium subscriptions silently.
class PurchaseBootstrapper {
  static bool _didRun = false;

  static Future<void> runOnce() async {
    if (_didRun) return;
    _didRun = true;

    final meter = UsageMeter();
    await meter.initIfNeeded();
    await meter.syncFromCloud();

    final iap = InAppPurchaseService(
      onDeliverPurchase: (p) async {
        final result = await PurchaseDelivery.deliver(p, meter: meter);
        return result.delivered || result.ignored;
      },
    );

    await iap.init();

    // Restore in background; purchases will come through the stream.
    try {
      await iap.restore();
      // Give a moment for the stream events to arrive, then dispose.
      await Future<void>.delayed(const Duration(seconds: 2));
    } catch (_) {
      // Silent: device not available / store issue
    } finally {
      iap.dispose();
    }
  }
}
