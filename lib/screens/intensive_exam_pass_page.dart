import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/in_app_purchase_service.dart';
import '../services/purchase_delivery.dart';
import '../services/usage_meter.dart';

class IntensiveExamPassPage extends StatefulWidget {
  const IntensiveExamPassPage({super.key});

  @override
  State<IntensiveExamPassPage> createState() =>
      _IntensiveExamPassPageState();
}

class _IntensiveExamPassPageState extends State<IntensiveExamPassPage> {
  final _meter = UsageMeter();
  late final InAppPurchaseService _iap;
  ProductDetails? _product;
  bool _loading = true;
  bool _buying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _iap = InAppPurchaseService(onDeliverPurchase: _deliver);
    _boot();
  }

  Future<void> _boot() async {
    await _meter.initIfNeeded();
    await _iap.init();
    final loaded = await _iap.loadProducts();
    if (!mounted) return;
    setState(() {
      _product = _iap.getProduct(InAppPurchaseService.intensiveExamPass);
      _loading = false;
      if (!loaded || _product == null) {
        _error = 'Le Pass intensif n’est pas encore disponible sur le Store.';
      }
    });
  }

  Future<bool> _deliver(PurchaseDetails purchase) async {
    if (purchase.productID != InAppPurchaseService.intensiveExamPass) {
      final other = await PurchaseDelivery.deliver(purchase, meter: _meter);
      return other.delivered || other.ignored;
    }
    final result = await PurchaseDelivery.deliver(purchase, meter: _meter);
    if (!mounted) return result.delivered || result.ignored;
    setState(() => _buying = false);
    if (result.delivered || result.ignored) {
      Navigator.pop(context, true);
    } else if (result.message != null) {
      _snack(result.message!);
    }
    return result.delivered || result.ignored;
  }

  Future<void> _buy() async {
    final product = _product;
    if (product == null || _buying) return;
    setState(() => _buying = true);
    try {
      await _iap.buy(product);
    } catch (error) {
      if (mounted) setState(() => _buying = false);
      _snack('Achat impossible pour le moment. Réessaie depuis Google Play.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _iap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pass entraînement intensif')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.tertiary],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                children: [
                  Icon(Icons.school_rounded, color: Colors.white, size: 54),
                  SizedBox(height: 14),
                  Text(
                    'Un examen blanc complet, maintenant',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sujet professionnel, mises en situation, corrections et bilan personnalisé.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _PassBenefit(
              icon: Icons.assignment_turned_in_rounded,
              title: '1 examen supplémentaire',
              subtitle: 'Le pass est consommé uniquement au démarrage du sujet.',
            ),
            const _PassBenefit(
              icon: Icons.auto_awesome_rounded,
              title: 'Coach et bilan inclus',
              subtitle: 'Des retours concrets pour préparer le prochain essai.',
            ),
            const _PassBenefit(
              icon: Icons.replay_rounded,
              title: 'Sans abonnement supplémentaire',
              subtitle: 'Achat unique, sans renouvellement automatique.',
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null) ...[
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.error, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _boot();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ] else
              FilledButton.icon(
                onPressed: _buying ? null : _buy,
                icon: _buying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bolt_rounded),
                label: Text(
                  _buying
                      ? 'Validation par Google Play…'
                      : 'Débloquer cet examen • ${_product?.price ?? '0,99 €'}',
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Le prix final et la devise sont ceux affichés par Google Play. '
              'Le droit est ajouté après vérification sécurisée de l’achat.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassBenefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PassBenefit({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
    );
  }
}
