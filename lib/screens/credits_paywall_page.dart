import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/in_app_purchase_service.dart';
import '../services/purchase_delivery.dart';
import '../services/usage_meter.dart';

class CreditsPaywallPage extends StatefulWidget {
  const CreditsPaywallPage({super.key});

  @override
  State<CreditsPaywallPage> createState() => _CreditsPaywallPageState();
}

class _CreditsPaywallPageState extends State<CreditsPaywallPage>
    with SingleTickerProviderStateMixin {
  final _meter = UsageMeter();
  late final InAppPurchaseService _iap;
  late final AnimationController _shimmerCtrl;

  bool _loading = true;
  bool _loadingProducts = true;
  bool _isPurchasing = false;
  String? _productsError;
  bool _isPremium = false;
  bool _restoreRequestedByUser = false;

  // Yearly selected by default (best value)
  String _selectedPlan = InAppPurchaseService.premiumYearly;

  static const _dark = Color(0xFF0D1B2A);
  static const _blue = Color(0xFF5AACDB);
  static const _green = Color(0xFF3CC398);
  static const _peach = Color(0xFFFBA49B);

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _iap = InAppPurchaseService(
      onDeliverPurchase: (PurchaseDetails p) => _deliver(p),
    );
    _boot();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _iap.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    await _meter.initIfNeeded();
    await _meter.syncFromCloud();
    await _iap.init();
    try { await _iap.restore(); } catch (_) {}
    await _refreshUsage();
    await _loadProductsWithRetry();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshUsage() async {
    final prem = await _meter.isPremium();
    if (!mounted) return;
    setState(() => _isPremium = prem);
  }

  Future<void> _loadProductsWithRetry() async {
    if (!mounted) return;
    setState(() { _loadingProducts = true; _productsError = null; });
    bool ok = await _iap.loadProducts(timeout: const Duration(seconds: 20));
    if (!ok) ok = await _iap.loadProducts(timeout: const Duration(seconds: 35));
    if (!mounted) return;
    setState(() {
      _loadingProducts = false;
      if (!ok) _productsError = "Impossible de récupérer les offres.\nVérifie ta connexion et réessaie.";
    });
  }

  Future<bool> _deliver(PurchaseDetails p) async {
    final res = await PurchaseDelivery.deliver(p, meter: _meter);
    await _refreshUsage();
    if (!mounted) return res.delivered || res.ignored;
    setState(() => _isPurchasing = false);
    if (_restoreRequestedByUser && p.status == PurchaseStatus.restored) {
      _snack(res.message ?? "✅ Achats restaurés.");
      return res.delivered || res.ignored;
    }
    if (res.delivered && p.status == PurchaseStatus.purchased) {
      _snack(res.message ?? "✅ Abonnement activé !");
      Navigator.pop(context);
    }
    if (!res.delivered && !res.ignored && res.message != null) {
      _snack(res.message!);
    }
    return res.delivered || res.ignored;
  }

  Future<void> _buy(String productId) async {
    if (_isPurchasing) return;
    final product = _iap.getProduct(productId);
    if (product == null) { _snack("Produit non disponible."); return; }
    setState(() => _isPurchasing = true);
    try {
      await _iap.buy(product);
    } catch (e) {
      if (mounted) setState(() => _isPurchasing = false);
      _snack("Erreur : $e");
    }
  }

  Future<void> _restore() async {
    if (_isPurchasing) return;
    setState(() { _restoreRequestedByUser = true; _isPurchasing = true; });
    try {
      await _iap.restore();
      await _meter.syncFromCloud();
      await _refreshUsage();
      _snack("Restauration ✅");
    } finally {
      _restoreRequestedByUser = false;
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  // ── Prix affiché depuis les produits IAP ──────────────────────────────
  String _price(String id) {
    final p = _iap.getProduct(id);
    return p?.price ?? (id == InAppPurchaseService.premiumYearly ? '29,99 €/an' : '7,99 €/mois');
  }

  String _monthlyEquiv() {
    // Essaie d'extraire le prix yearly / 12
    final p = _iap.getProduct(InAppPurchaseService.premiumYearly);
    if (p == null) return '≈ 2,50 €/mois';
    final raw = p.rawPrice;
    if (raw > 0) {
      final currency = switch (p.currencyCode.toUpperCase()) {
        'EUR' => '€',
        'USD' => r'$',
        'GBP' => '£',
        _ => p.currencyCode,
      };
      return '≈ ${(raw / 12).toStringAsFixed(2).replaceAll('.', ',')} $currency/mois';
    }
    return '≈ 2,50 €/mois';
  }

  String _yearlySavingBadge() {
    final monthly = _iap.getProduct(InAppPurchaseService.premiumMonthly)?.rawPrice ?? 7.99;
    final yearly = _iap.getProduct(InAppPurchaseService.premiumYearly)?.rawPrice ?? 29.99;
    if (monthly <= 0 || yearly <= 0) return '-69%';
    final saving = ((1 - yearly / (monthly * 12)) * 100).round().clamp(0, 99);
    return '-$saving%';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _dark,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(children: [
        // ── Fond décoratif ─────────────────────────────────────────
        Positioned.fill(
          child: CustomPaint(painter: _BgPainter()),
        ),

        // ── Contenu ────────────────────────────────────────────────
        SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      // Avantages
                      _buildPerks(),
                      const SizedBox(height: 24),
                      // Cartes d'abonnement
                      if (_loadingProducts)
                        _buildLoadingCards()
                      else if (_productsError != null)
                        _buildError()
                      else ...[
                          _PlanCard(
                            label: 'Annuel',
                            badge: _yearlySavingBadge(),
                            price: _price(InAppPurchaseService.premiumYearly),
                            sub: _monthlyEquiv(),
                            selected: _selectedPlan == InAppPurchaseService.premiumYearly,
                            colors: [_blue, _green],
                            onTap: () => setState(() => _selectedPlan = InAppPurchaseService.premiumYearly),
                          ),
                          const SizedBox(height: 12),
                          _PlanCard(
                            label: 'Mensuel',
                            badge: null,
                            price: _price(InAppPurchaseService.premiumMonthly),
                            sub: 'Résiliation à tout moment',
                            selected: _selectedPlan == InAppPurchaseService.premiumMonthly,
                            colors: [_green, _peach],
                            onTap: () => setState(() => _selectedPlan = InAppPurchaseService.premiumMonthly),
                          ),
                        ],
                      const SizedBox(height: 28),
                      // CTA
                      if (!_loadingProducts && _productsError == null)
                        _buildCTA(),
                      const SizedBox(height: 16),
                      // Restore
                      GestureDetector(
                        onTap: _isPurchasing ? null : _restore,
                        child: Text(
                          'Restaurer mes achats',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Abonnement géré par l\'App Store / Play Store.\nPrix TTC. Renouvellement automatique.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.28),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Close button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),

        // Overlay achat en cours
        if (_isPurchasing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text('Communication avec le Store…',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        children: [
          // Crown icon
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [_blue, _green]),
              boxShadow: [
                BoxShadow(color: _blue.withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_blue, _green, _peach],
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: const Text(
              'Passe en Pro\navec un rythme efficace',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Parcours complet, séances guidées et feedback IA',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerks() {
    final perks = [
      (Icons.mic_rounded, '2 simulations guidées par jour', 'Un rythme régulier pour mieux progresser'),
      (Icons.psychology_rounded, 'Feedback IA personnalisé', 'Retours clairs après chaque session'),
      (Icons.school_rounded, 'Examen blanc inclus', 'Un examen complet tous les 7 jours'),
      (Icons.trending_up_rounded, 'Progression suivie', 'Classement, badges et progression'),
      (Icons.lock_open_rounded, 'Accès complet Pro', 'Modules, quiz et outils accessibles'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: perks.map((p) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_blue, _green]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(p.$1, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.$2, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(p.$3, style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ],
              )),
              Icon(Icons.check_circle_rounded, color: _green, size: 20),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildLoadingCards() {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, __) => Column(children: [
        _ShimmerBox(height: 90, ctrl: _shimmerCtrl),
        const SizedBox(height: 12),
        _ShimmerBox(height: 90, ctrl: _shimmerCtrl),
      ]),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade700.withOpacity(0.5)),
      ),
      child: Column(children: [
        Text(_productsError!,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _loadProductsWithRetry,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          label: const Text('Réessayer', style: TextStyle(color: Colors.white)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white38)),
        ),
      ]),
    );
  }

  Widget _buildCTA() {
    final isYearly = _selectedPlan == InAppPurchaseService.premiumYearly;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_blue, _green]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: _blue.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isPurchasing ? null : () => _buy(_selectedPlan),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: Text(
            isYearly ? "S'abonner (${_price(InAppPurchaseService.premiumYearly)})" : "S'abonner (${_price(InAppPurchaseService.premiumMonthly)})",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Carte plan ──────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final String label;
  final String? badge;
  final String price;
  final String sub;
  final bool selected;
  final List<Color> colors;
  final VoidCallback onTap;

  const _PlanCard({
    required this.label,
    required this.badge,
    required this.price,
    required this.sub,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? colors[0].withOpacity(0.8)
                : Colors.white.withOpacity(0.12),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: colors[0].withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))]
              : [],
        ),
        child: Row(
          children: [
            // Radio
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected
                    ? LinearGradient(colors: colors)
                    : null,
                color: selected ? null : Colors.transparent,
                border: Border.all(
                  color: selected ? Colors.transparent : Colors.white38,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 14),
            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(label, style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: colors),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(badge!, style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(sub, style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ],
              ),
            ),
            // Prix
            Text(price, style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer loader ─────────────────────────────────────────────────────────
class _ShimmerBox extends StatelessWidget {
  final double height;
  final AnimationController ctrl;
  const _ShimmerBox({required this.height, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment(-1 + ctrl.value * 2, 0),
            end: Alignment(ctrl.value * 2, 0),
            colors: const [Color(0xFF1A2E45), Color(0xFF253D58), Color(0xFF1A2E45)],
          ),
        ),
      ),
    );
  }
}

// ── Fond décoratif ─────────────────────────────────────────────────────────
class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = const Color(0xFF5AACDB).withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.1), 200, p1);

    final p2 = Paint()
      ..color = const Color(0xFF3CC398).withOpacity(0.07)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.6), 180, p2);
  }

  @override
  bool shouldRepaint(_) => false;
}
