import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewService {
  static const _kAskedReview = 'asked_review_v1';

  // ---------------------------------------------------------------------------
  // ✅ NOUVEAU (utilisé par ResultPage / SynthesisPage)
  // ---------------------------------------------------------------------------

  /// Vrai si on a déjà demandé un avis (sert aussi de "déblocage partage")
  static Future<bool> hasAskedForReview() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAskedReview) ?? false;
  }

  /// Demande l'avis Google Play (1 seule fois).
  /// Retourne true si (après l'appel) on considère l'avis "déjà demandé".
  static Future<bool> maybeAskForReview() async {
    final prefs = await SharedPreferences.getInstance();
    final already = prefs.getBool(_kAskedReview) ?? false;
    if (already) return true;

    final review = InAppReview.instance;

    // Si dispo => on tente requestReview()
    if (await review.isAvailable()) {
      try {
        await review.requestReview();
        await prefs.setBool(_kAskedReview, true);
        return true;
      } catch (_) {
        // si requestReview échoue, on ne bloque pas
        return false;
      }
    }

    return false;
  }

  /// Ouvre la page Play Store (fallback si besoin)
  static Future<void> openStoreListing() async {
    final review = InAppReview.instance;
    await review.openStoreListing();
  }

  // ---------------------------------------------------------------------------
  // ✅ ANCIENNE API (compatibilité avec tes anciennes pages)
  // ---------------------------------------------------------------------------

  /// ✅ Ancien nom : utilisé dans QuizScreen => ReviewService().maybeAskReview();
  /// On redirige vers la nouvelle logique.
  Future<void> maybeAskReview() async {
    await ReviewService.maybeAskForReview();
  }

  /// (Optionnel) si tu avais un autre ancien nom dans d'autres pages
  Future<bool> hasAlreadyAsked() async {
    return ReviewService.hasAskedForReview();
  }
}
