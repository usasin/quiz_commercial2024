import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'usage_meter.dart';
import 'paywall_analytics.dart';
import 'admin_service.dart';

/// 🛠️ Service mode Admin / Debug.
///
/// 🎯 Objectif : pouvoir tester le flow complet (Premium, paywall, simulations)
/// SANS payer en vrai sur le Play Store. Indispensable en dev, en QA, et pour
/// démontrer l'app à des partenaires.
///
/// 🔐 Le rôle est lu dans Firestore (`isAdmin: true` ou `admin: true`).
///
/// ⚠️ Sécurité :
///   - Tous les changements sont LOCAUX (SharedPreferences). Ne déclenche
///     PAS de vrai achat in-app, ne contacte PAS le store.
///   - La sync cloud (`UsageMeter.scheduleCloudSync`) peut quand même
///     écrire ces valeurs dans Firestore si tu utilises `setDevPremium`.
///     Pour un test "propre", reset Premium quand tu as fini.
///   - Ne jamais commit des emails de prod (utilisateurs réels) dans la
///     whitelist. Met seulement TES emails et ceux de ton équipe QA.
class DebugAdminService {
  DebugAdminService._();

  // ─────────────────────────────────────────────────────────────
  // DÉTECTION ADMIN
  // ───────────────────────
  // ──────────────────────────────────────

  /// Renvoie true si l'utilisateur courant est admin/debug.
  ///
  /// Valeur en cache pour les anciens widgets synchrones.
  static bool isAdmin() {
    return AdminService.instance.cachedIsAdmin;
  }

  static Future<bool> isAdminAsync() => AdminService.instance.isAdmin();

  // ─────────────────────────────────────────────────────────────
  // ACTIONS DEBUG (locales uniquement)
  // ─────────────────────────────────────────────────────────────

  /// Active ou désactive Premium SANS achat in-app.
  /// Utile pour passer du flow free → premium et inversement sans payer.
  static Future<void> setDevPremium(bool value) async {
    final meter = UsageMeter();
    await meter.initIfNeeded();
    if (await AdminService.instance.isAdmin()) {
      await meter.setAdminPreviewFree(!value);
    }
    await meter.setPremium(value);
  }

  /// Renvoie les crédits de simulation à `n` (par défaut 1).
  /// → permet de re-tester le flow "1ère simu gratuite" autant de fois
  ///   que tu veux pendant tes tests.
  static Future<void> resetSimCredits([int n = 1]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sim_credits', n);
  }

  /// Reset les compteurs locaux du paywall pour une source donnée
  /// (par défaut le paywall "after_simulation").
  /// Le cloud (Firestore) n'est PAS touché ici — c'est volontaire,
  /// car ces stats agrégées doivent rester fiables sur la durée.
  static Future<void> resetLocalPaywallStats({
    String source = PaywallAnalytics.sourceAfterSimulation,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final events = [
      PaywallAnalytics.eventShown,
      PaywallAnalytics.eventCtaClicked,
      PaywallAnalytics.eventDismissed,
      PaywallAnalytics.eventConverted,
    ];
    for (final e in events) {
      await prefs.remove('paywall_${source}_$e');
    }
  }

  /// Reset les quotas journaliers (text tokens + audio secondes).
  /// → permet de re-tester les limites quand tu as déjà tout consommé.
  static Future<void> resetDailyQuota() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('text_credits');
    await prefs.remove('audio_seconds');
    await prefs.remove('last_reset_day');
    // Re-init pour repeupler les défauts journaliers.
    await UsageMeter().initIfNeeded();
  }

  /// Tout remettre à plat : Premium off, crédits sim = 1,
  /// paywall stats reset, quota journalier reset.
  /// Idéal pour repartir d'un état "nouvel utilisateur".
  static Future<void> resetAllToFresh() async {
    await setDevPremium(false);
    await resetSimCredits(1);
    await resetLocalPaywallStats();
    await resetDailyQuota();
  }

  // ─────────────────────────────────────────────────────────────
  // RAPPORT D'ÉTAT (pour la page UI)
  // ─────────────────────────────────────────────────────────────

  /// Récupère un snapshot complet de l'état local actuel.
  /// Pratique pour afficher dans la page debug.
  static Future<DebugReport> getDebugReport() async {
    final meter = UsageMeter();
    await meter.initIfNeeded();

    final isPremium     = await meter.isPremium();
    final activePlan    = await meter.getActivePlan();
    final simCredits    = await meter.getSimCredits();
    final textCredits   = await meter.getTextCredits();
    final audioSeconds  = await meter.getAudioSeconds();

    final paywallStats = await PaywallAnalytics.getLocalStats(
      PaywallAnalytics.sourceAfterSimulation,
    );
    final conversionRate = await PaywallAnalytics.getLocalConversionRate(
      PaywallAnalytics.sourceAfterSimulation,
    );

    final user = FirebaseAuth.instance.currentUser;

    return DebugReport(
      email: user?.email,
      uid: user?.uid,
      isPremium: isPremium,
      activePlan: activePlan,
      simCredits: simCredits,
      textCredits: textCredits,
      audioSeconds: audioSeconds,
      paywallShown: paywallStats[PaywallAnalytics.eventShown] ?? 0,
      paywallCtaClicked: paywallStats[PaywallAnalytics.eventCtaClicked] ?? 0,
      paywallDismissed: paywallStats[PaywallAnalytics.eventDismissed] ?? 0,
      paywallConverted: paywallStats[PaywallAnalytics.eventConverted] ?? 0,
      paywallConversionRate: conversionRate,
    );
  }
}

/// Snapshot d'état pour l'UI debug. Tout est lecture seule.
class DebugReport {
  final String? email;
  final String? uid;
  final bool isPremium;
  final String activePlan;
  final int simCredits;
  final int textCredits;
  final int audioSeconds;
  final int paywallShown;
  final int paywallCtaClicked;
  final int paywallDismissed;
  final int paywallConverted;
  final double? paywallConversionRate;

  DebugReport({
    required this.email,
    required this.uid,
    required this.isPremium,
    required this.activePlan,
    required this.simCredits,
    required this.textCredits,
    required this.audioSeconds,
    required this.paywallShown,
    required this.paywallCtaClicked,
    required this.paywallDismissed,
    required this.paywallConverted,
    required this.paywallConversionRate,
  });
}
