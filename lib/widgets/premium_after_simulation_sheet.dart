import 'package:flutter/material.dart';

import '../theme/cip_colors.dart' as c;
import '../screens/credits_paywall_page.dart';
import '../services/usage_meter.dart';
import '../services/paywall_analytics.dart';

/// 🔥 Paywall "moment chaud" — affiché juste après la simulation gratuite,
/// quand l'utilisateur clique sur TERMINER, AVANT d'appeler le coach GPT.
///
/// 🎯 Objectif business :
///   - Économise GPT : on ne génère JAMAIS le compte rendu coach +
///     les corrections d'écrit en tier gratuit.
///   - Convertit : l'utilisateur est dans son pic d'engagement (il vient
///     de finir SA simulation, il veut son feedback).
///
/// 🔄 Comportement attendu côté appelant :
///   - Si `show()` renvoie `true`  → l'utilisateur est passé Premium
///                                   pendant le flow → on continue
///                                   (appeler coachFeedback puis naviguer).
///   - Si `show()` renvoie `false` → l'utilisateur a fermé la sheet ou
///                                   cliqué "Plus tard" → on n'appelle
///                                   PAS le coach (pas de coût GPT).
class PremiumAfterSimulationSheet {
  PremiumAfterSimulationSheet._();

  /// Ouvre la sheet et retourne `true` si l'utilisateur est devenu Premium
  /// pendant le flow (l'appelant peut alors poursuivre vers le compte rendu).
  static Future<bool> show(BuildContext context) async {
    // 📊 Track : l'utilisateur a VU la sheet (1x par appel de show).
    PaywallAnalytics.trackShown(PaywallAnalytics.sourceAfterSimulation);

    // Petit flag partagé avec le body pour savoir si l'user a cliqué
    // le CTA principal ou non (utile pour distinguer "dismiss" de "cta_clicked").
    final state = _SheetState();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => _PremiumAfterSimulationSheetBody(state: state),
    );

    // À la fermeture, on calcule le résultat.
    final meter = UsageMeter();
    await meter.initIfNeeded();
    final becamePremium = await meter.isPremium();

    // 📊 Track : conversion ou dismiss.
    if (becamePremium) {
      // Le ticket d'or : l'user a souscrit pendant le flow.
      PaywallAnalytics.trackConverted(
        PaywallAnalytics.sourceAfterSimulation,
      );
    } else if (!state.ctaClicked) {
      // Ni converti, ni n'a cliqué le CTA → dismiss "froid".
      // (Si ctaClicked && !becamePremium, l'event cta_clicked a déjà été
      //  traqué au moment du clic, pas besoin d'ajouter dismissed.)
      PaywallAnalytics.trackDismissed(
        PaywallAnalytics.sourceAfterSimulation,
      );
    }

    return becamePremium;
  }
}

/// État léger partagé entre `show()` et le body de la sheet, pour
/// distinguer un dismiss "froid" d'un click sur le CTA principal.
class _SheetState {
  bool ctaClicked = false;
}

class _PremiumAfterSimulationSheetBody extends StatelessWidget {
  final _SheetState state;
  const _PremiumAfterSimulationSheetBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        constraints: BoxConstraints(
          maxHeight: mq.size.height * 0.88,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(),
                _buildHeader(),
                _buildBody(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────── HANDLE (la petite barre du haut)

  Widget _buildHandle() => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Container(
      width: 44,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.12),
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );

  // ─────────────────────────────────────── HEADER (célébration)

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.CipColors.blue, c.CipColors.green, c.CipColors.peach],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: Colors.white, size: 38),
          ),
          const SizedBox(height: 14),
          const Text(
            "Bravo, simulation terminée !",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Vous êtes en phase découverte",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.92),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────── BODY (valeur + CTA)

  Widget _buildBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Débloquez votre compte rendu complet",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: c.CipColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Pour progresser et préparer votre certificat, "
                "passez Premium et débloquez :",
            style: TextStyle(
              fontSize: 13.5,
              color: c.CipColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // Liste des features débloquées par le Premium
          _featureRow(
            icon: Icons.assessment_rounded,
            color: c.CipColors.blue,
            title: "Compte rendu détaillé de la simulation",
            subtitle: "Score, points forts, axes d'amélioration, "
                "questions manquées.",
          ),
          const SizedBox(height: 12),
          _featureRow(
            icon: Icons.edit_note_rounded,
            color: c.CipColors.green,
            title: "Synthèse écrite + Analyse de pratique",
            subtitle: "Vos écrits corrigés et notés /100 par l'IA.",
          ),
          const SizedBox(height: 12),
          _featureRow(
            icon: Icons.all_inclusive_rounded,
            color: c.CipColors.peach,
            title: "2 simulations guidées par jour",
            subtitle: "Progressez avec un rythme régulier sur tous les "
                "scénarios.",
          ),
          const SizedBox(height: 12),
          _featureRow(
            icon: Icons.workspace_premium_rounded,
            color: c.CipColors.pinkSoft,
            title: "Progression complète vers le certificat",
            subtitle: "Suivi, modules avancés, badges et tableau de bord.",
          ),

          const SizedBox(height: 24),

          // CTA principal : passer Premium
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () async {
                // 📊 Track : l'user a cliqué le CTA principal.
                //    On marque aussi le state pour que show() sache que
                //    ce n'est pas un dismiss "froid".
                state.ctaClicked = true;
                PaywallAnalytics.trackCtaClicked(
                  PaywallAnalytics.sourceAfterSimulation,
                );

                // Ferme la sheet puis ouvre le paywall.
                Navigator.of(context).pop();
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CreditsPaywallPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: c.CipColors.dark,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt_rounded, size: 22),
                  SizedBox(width: 8),
                  Text(
                    "Passer Premium",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // CTA secondaire : plus tard
          SizedBox(
            width: double.infinity,
            height: 46,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: c.CipColors.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "Plus tard",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          Center(
            child: Text(
              "Sans abonnement, le compte rendu n'est pas généré.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: c.CipColors.textSecondary.withOpacity(0.85),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.13),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: c.CipColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: c.CipColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
