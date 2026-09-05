import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 📊 Analytics dédiés aux paywalls.
///
/// 🎯 Objectif : mesurer le funnel de conversion :
///   shown → cta_clicked → converted
///   shown → dismissed (perdu)
///
/// 💡 Pourquoi pas EngagementService ?
/// EngagementService est centré sur la gamification (XP, streak, badges).
/// Mélanger tracking business + gamification finit toujours mal :
/// signatures qui divergent, événements pollués. Mieux vaut un service
/// dédié, simple, qu'on pourra étendre (autres paywalls, A/B tests…).
///
/// 💰 Stratégie de coût Firestore :
///   - Pas d'event-by-event (qui exploserait avec le volume).
///   - Un seul document par user (snapshot agrégé), updated avec
///     `FieldValue.increment(1)` → 1 write par track, atomique, pas cher.
///   - Lisible directement depuis Firebase Console pour stats globales
///     ou requêtable pour un dashboard admin.
///
/// 🔄 Comment l'utiliser :
///   PaywallAnalytics.trackShown('after_simulation');
///   PaywallAnalytics.trackCtaClicked('after_simulation');
///   PaywallAnalytics.trackDismissed('after_simulation');
///   PaywallAnalytics.trackConverted('after_simulation');
///
/// Le paramètre `source` permet de réutiliser le service pour tout type
/// de paywall ('after_simulation', 'sim_credits_exhausted', 'profile_cta'…).
class PaywallAnalytics {
  PaywallAnalytics._();

  // ─────────────────────────────────────── EVENT KEYS

  static const String eventShown      = 'shown';
  static const String eventCtaClicked = 'cta_clicked';
  static const String eventDismissed  = 'dismissed';
  static const String eventConverted  = 'converted';

  // ─────────────────────────────────────── SOURCES (helpers, pas obligatoires)

  /// Paywall affiché juste après la simulation orale gratuite, sur TERMINER.
  static const String sourceAfterSimulation = 'after_simulation';

  // ─────────────────────────────────────── PUBLIC API

  /// L'utilisateur a vu la sheet/paywall.
  static Future<void> trackShown(String source) =>
      _track(event: eventShown, source: source);

  /// L'utilisateur a cliqué sur le CTA principal (ex: "Passer Premium").
  /// → Il a quitté la sheet pour aller voir la page d'abonnement.
  static Future<void> trackCtaClicked(String source) =>
      _track(event: eventCtaClicked, source: source);

  /// L'utilisateur a fermé la sheet sans cliquer le CTA principal
  /// (bouton "Plus tard", swipe, tap sur backdrop, back system…).
  static Future<void> trackDismissed(String source) =>
      _track(event: eventDismissed, source: source);

  /// L'utilisateur est devenu Premium pendant le flow déclenché par
  /// cette sheet. C'est la métrique la plus importante.
  static Future<void> trackConverted(String source) =>
      _track(event: eventConverted, source: source, alsoSetTimestamp: true);

  // ─────────────────────────────────────── LECTURE LOCALE

  /// Compteurs locaux par event x source. Utile pour un futur écran
  /// debug/admin, ou pour afficher la stat directement dans l'app.
  ///
  /// Renvoie une Map { 'shown': 12, 'cta_clicked': 5, 'dismissed': 7,
  ///                   'converted': 2 } pour la source demandée.
  static Future<Map<String, int>> getLocalStats(String source) async {
    final prefs = await SharedPreferences.getInstance();
    final events = [eventShown, eventCtaClicked, eventDismissed, eventConverted];
    final out = <String, int>{};
    for (final e in events) {
      out[e] = prefs.getInt(_localKey(source, e)) ?? 0;
    }
    return out;
  }

  /// Petit utilitaire pratique : taux de conversion local (0..1) ou null
  /// si pas encore d'affichage. Pour un dashboard interne.
  static Future<double?> getLocalConversionRate(String source) async {
    final stats = await getLocalStats(source);
    final shown = stats[eventShown] ?? 0;
    final conv  = stats[eventConverted] ?? 0;
    if (shown <= 0) return null;
    return conv / shown;
  }

  // ─────────────────────────────────────── INTERNES

  static String _localKey(String source, String event) =>
      'paywall_${source}_$event';

  static Future<void> _track({
    required String event,
    required String source,
    bool alsoSetTimestamp = false,
  }) async {
    // 1) Local — compteur SharedPreferences (toujours, même offline).
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _localKey(source, event);
      final cur = prefs.getInt(key) ?? 0;
      await prefs.setInt(key, cur + 1);
    } catch (e) {
      debugPrint('PaywallAnalytics local error: $e');
    }

    // 2) Cloud — un seul doc agrégé par user, incrément atomique.
    //    On évite les events row-by-row pour ne pas exploser Firestore.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // anonymes : OK, on garde seulement le local.

    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);

      final payload = <String, dynamic>{
        'paywallStats': {
          source: {
            event: FieldValue.increment(1),
            'lastEventAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }
      };

      if (alsoSetTimestamp) {
        // Pour 'converted', on garde aussi le timestamp exact de la
        // dernière conversion (utile pour cohorte / analyse).
        (payload['paywallStats'] as Map)[source]['${event}At'] =
            FieldValue.serverTimestamp();
      }

      await ref.set(payload, SetOptions(merge: true));
    } catch (e) {
      debugPrint('PaywallAnalytics cloud error: $e');
      // Pas de rethrow : le tracking ne doit JAMAIS casser l'UX.
    }
  }
}
