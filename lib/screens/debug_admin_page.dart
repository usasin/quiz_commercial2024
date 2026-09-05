import 'package:flutter/material.dart';

import '../theme/cip_colors.dart' as c;
import '../services/debug_admin_service.dart';

/// 🛠️ Page debug réservée admin.
///
/// Accessible via :
///   - Route nommée `/debug` (ajoutée dans main.dart)
///   - Tuile "Mode Admin" dans la page Profil, visible si `DebugAdminService.isAdmin()`
///
/// Si un user non-admin atterrit ici par erreur, on bloque l'accès et on
/// le renvoie en arrière (défense en profondeur).
class DebugAdminPage extends StatefulWidget {
  const DebugAdminPage({super.key});

  @override
  State<DebugAdminPage> createState() => _DebugAdminPageState();
}

class _DebugAdminPageState extends State<DebugAdminPage> {
  DebugReport? _report;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Garde-fou : si non-admin, on ferme immédiatement.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!DebugAdminService.isAdmin()) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      _refresh();
    });
  }

  Future<void> _refresh() async {
    final r = await DebugAdminService.getDebugReport();
    if (!mounted) return;
    setState(() => _report = r);
  }

  Future<void> _withBusy(Future<void> Function() action, {String? toast}) async {
    setState(() => _busy = true);
    try {
      await action();
      await _refresh();
      if (toast != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(toast), duration: const Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c.CipColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          "Mode Admin",
          style: TextStyle(fontWeight: FontWeight.w800, color: c.CipColors.dark),
        ),
        iconTheme: const IconThemeData(color: c.CipColors.dark),
        actions: [
          IconButton(
            tooltip: "Rafraîchir",
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _busy ? null : _refresh,
          ),
        ],
      ),
      body: _report == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _warningBanner(),
                  const SizedBox(height: 14),
                  _statusCard(_report!),
                  const SizedBox(height: 14),
                  _premiumToggleCard(_report!),
                  const SizedBox(height: 14),
                  _resetActionsCard(),
                  const SizedBox(height: 14),
                  _paywallFunnelCard(_report!),
                  const SizedBox(height: 18),
                  _dangerCard(),
                ],
              ),
            ),
    );
  }

  // ─────────────────────────────────────── BANNER

  Widget _warningBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Mode admin actif — toutes les modifications sont locales "
              "(aucun achat réel n'est déclenché).",
              style: TextStyle(
                color: c.CipColors.dark,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────── STATUS

  Widget _statusCard(DebugReport r) {
    return _card(
      title: "État actuel",
      icon: Icons.dashboard_rounded,
      iconColor: c.CipColors.blue,
      child: Column(
        children: [
          _kv("Email", r.email ?? "(non connecté)"),
          _kv("UID", r.uid ?? "—"),
          _kv("Premium", r.isPremium ? "✅ OUI" : "❌ NON"),
          _kv("Plan actif", r.activePlan),
          _kv("Crédits simulation", "${r.simCredits}"),
          _kv("Crédits texte (jour)", "${r.textCredits} tokens"),
          _kv("Audio restant (jour)", "${r.audioSeconds} sec"),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              k,
              style: const TextStyle(
                fontSize: 13,
                color: c.CipColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                fontSize: 13,
                color: c.CipColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────── PREMIUM TOGGLE

  Widget _premiumToggleCard(DebugReport r) {
    return _card(
      title: "Premium (sans achat réel)",
      icon: Icons.workspace_premium_rounded,
      iconColor: c.CipColors.peach,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.isPremium
                      ? "Le mode Premium est activé localement."
                      : "Active Premium pour tester les flows réservés abonnés.",
                  style: const TextStyle(
                    fontSize: 13,
                    color: c.CipColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: r.isPremium,
                activeColor: c.CipColors.green,
                onChanged: _busy
                    ? null
                    : (v) => _withBusy(
                          () => DebugAdminService.setDevPremium(v),
                          toast: v
                              ? "Premium DEV activé"
                              : "Premium DEV désactivé",
                        ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────── RESET ACTIONS

  Widget _resetActionsCard() {
    return _card(
      title: "Actions de reset",
      icon: Icons.restart_alt_rounded,
      iconColor: c.CipColors.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _actionBtn(
            label: "Redonner 1 crédit simulation",
            icon: Icons.replay_rounded,
            onTap: () => _withBusy(
              () => DebugAdminService.resetSimCredits(1),
              toast: "Crédit simulation = 1",
            ),
          ),
          const SizedBox(height: 8),
          _actionBtn(
            label: "Reset quotas texte + audio (journaliers)",
            icon: Icons.cleaning_services_rounded,
            onTap: () => _withBusy(
              () => DebugAdminService.resetDailyQuota(),
              toast: "Quotas journaliers réinitialisés",
            ),
          ),
          const SizedBox(height: 8),
          _actionBtn(
            label: "Reset compteurs paywall (local)",
            icon: Icons.bar_chart_rounded,
            onTap: () => _withBusy(
              () => DebugAdminService.resetLocalPaywallStats(),
              toast: "Compteurs paywall local remis à 0",
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────── PAYWALL FUNNEL

  Widget _paywallFunnelCard(DebugReport r) {
    final rate = r.paywallConversionRate;
    final rateLabel = (rate == null)
        ? "—"
        : "${(rate * 100).toStringAsFixed(1)} %";

    return _card(
      title: "Funnel paywall (local, after_simulation)",
      icon: Icons.insights_rounded,
      iconColor: c.CipColors.green,
      child: Column(
        children: [
          _funnelRow("Affichages",     r.paywallShown,      c.CipColors.blue),
          _funnelRow("CTA cliqués",    r.paywallCtaClicked, c.CipColors.peach),
          _funnelRow("Abandons",       r.paywallDismissed,  c.CipColors.textSecondary),
          _funnelRow("Conversions",    r.paywallConverted,  c.CipColors.green),
          const Divider(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Taux de conversion",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: c.CipColors.dark,
                  ),
                ),
              ),
              Text(
                rateLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: c.CipColors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _funnelRow(String label, int value, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: c.CipColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            "$value",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: c.CipColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────── DANGER ZONE

  Widget _dangerCard() {
    return _card(
      title: "Zone dangereuse",
      icon: Icons.warning_rounded,
      iconColor: Colors.red.shade400,
      child: Column(
        children: [
          const Text(
            "Repart d'un état \"nouvel utilisateur\" : Premium OFF, "
            "1 crédit simulation, quotas remis, paywall stats locales effacées.",
            style: TextStyle(
              fontSize: 12.5,
              color: c.CipColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Tout réinitialiser ?"),
                          content: const Text(
                            "Cette action remet l'app en état \"première "
                            "ouverture\" pour CET appareil. Continue ?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text("Annuler"),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade500,
                              ),
                              child: const Text("Confirmer"),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await _withBusy(
                          () => DebugAdminService.resetAllToFresh(),
                          toast: "État remis à zéro",
                        );
                      }
                    },
              icon: const Icon(Icons.delete_forever_rounded),
              label: const Text(
                "Tout réinitialiser",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────── HELPERS UI

  Widget _card({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: c.CipColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: c.CipColors.dark,
        side: const BorderSide(color: c.CipColors.border),
        minimumSize: const Size.fromHeight(44),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
      ),
    );
  }
}
