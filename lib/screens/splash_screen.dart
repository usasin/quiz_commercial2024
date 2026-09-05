import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_language.dart';

/// SplashScreen EmploiBoost — logo + anneau centrés
/// Intégration dans main.dart :
///   initialRoute: '/splash'
///   '/splash': (_) => const SplashScreen(nextRoute: '/levels')
class SplashScreen extends StatefulWidget {
  final String nextRoute;
  const SplashScreen({super.key, this.nextRoute = '/levels'});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _masterCtrl;
  late final AnimationController _ringCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _exitCtrl;

  late final Animation<double> _bgFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _exitFade;

  final _particles = <_Particle>[];
  final _rng = math.Random(42);

  static const _blue  = Color(0xFF5AACDB);
  static const _green = Color(0xFF3CC398);
  static const _peach = Color(0xFFFBA49B);
  static const _dark  = Color(0xFF0D1B2A);
  static const _dark2 = Color(0xFF112033);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _buildParticles();
    _initAnimations();
    _runSequence();
  }

  void _buildParticles() {
    for (int i = 0; i < 28; i++) {
      _particles.add(_Particle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        size: 2.0 + _rng.nextDouble() * 5.0,
        speed: 0.25 + _rng.nextDouble() * 0.6,
        color: [_blue, _green, _peach][_rng.nextInt(3)],
        phase: _rng.nextDouble(),
      ));
    }
  }

  void _initAnimations() {
    _masterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _bgFade = CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );

    _logoOpacity = CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.15, 0.6, curve: Curves.elasticOut),
      ),
    );

    _titleOpacity = CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.5, 0.78, curve: Curves.easeOut),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.5, 0.78, curve: Curves.easeOutCubic),
    ));

    _taglineOpacity = CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.72, 1.0, curve: Curves.easeOut),
    );

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
    );
  }

  Future<void> _runSequence() async {
    await _masterCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 900));
    await _exitCtrl.forward();
    if (mounted) Navigator.of(context).pushReplacementNamed(widget.nextRoute);
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitFade,
      builder: (_, child) => Opacity(opacity: _exitFade.value, child: child),
      child: Scaffold(
        backgroundColor: _dark,
        body: AnimatedBuilder(
          animation: Listenable.merge([_masterCtrl, _ringCtrl, _pulseCtrl]),
          builder: (_, __) => _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Fond radial ───────────────────────────────────────────────────
        Opacity(
          opacity: _bgFade.value,
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.4,
                colors: [Color(0xFF1A3A5C), _dark2, _dark],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // ── Particules ────────────────────────────────────────────────────
        CustomPaint(
          painter: _ParticlesPainter(
            particles: _particles,
            progress: _ringCtrl.value,
            opacity: _bgFade.value,
          ),
        ),

        // ── Tout le contenu centré verticalement ─────────────────────────
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ─── Logo + Anneau dans UN SEUL SizedBox aligné center ────
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  // ↓ Tous les enfants centrés au pixel près
                  alignment: Alignment.center,
                  children: [

                    // 1. Halo pulsant (le plus grand, en arrière)
                    Opacity(
                      opacity: _logoOpacity.value * 0.35,
                      child: Container(
                        width: 155 + _pulseCtrl.value * 18,
                        height: 155 + _pulseCtrl.value * 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _blue.withOpacity(0.28),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 2. Anneau tournant (taille fixe = SizedBox parent)
                    CustomPaint(
                      painter: _RingPainter(
                        progress: _ringCtrl.value,
                        glowOpacity: _logoOpacity.value,
                        pulseValue: _pulseCtrl.value,
                      ),
                      size: const Size(180, 180),
                    ),

                    // 3. Cercle logo (centré automatiquement par Stack)
                    Transform.scale(
                      scale: _logoScale.value,
                      child: Opacity(
                        opacity: _logoOpacity.value,
                        child: Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.07),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.13),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _blue.withOpacity(
                                    0.35 * _logoOpacity.value),
                                blurRadius: 32,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.school_rounded,
                                  color: Colors.white.withOpacity(0.9),
                                  size: 46,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ─── Titre dégradé ────────────────────────────────────────
              FadeTransition(
                opacity: _titleOpacity,
                child: SlideTransition(
                  position: _titleSlide,
                  child: Column(
                    children: [
                      // Ligne 1 : "Prépa Commercial"
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [_blue, _green],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds),
                        blendMode: BlendMode.srcIn,
                        child: const Text(
                          'Prépa Boost',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.8,
                            height: 1.15,
                          ),
                        ),
                      ),

                      const SizedBox(height: 2),

                      // Ligne 2 : "IA" espacé, plus petit, peach
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [_green, _peach],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds),
                        blendMode: BlendMode.srcIn,
                        child: Text(
                          context.bilingual(fr: 'MÉTIERS', en: 'CAREERS'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 4,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ─── Tagline ──────────────────────────────────────────────
              FadeTransition(
                opacity: _taglineOpacity,
                child: Text(
                  context.bilingual(
                    fr: 'Révise  ·  Simule  ·  Réussis',
                    en: 'Learn  ·  Practice  ·  Succeed',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.38),
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Barre en bas ──────────────────────────────────────────────────
        Positioned(
          bottom: 50,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: _bgFade.value,
            child: _LoadingBar(progress: _ringCtrl.value),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Anneau tournant
// ─────────────────────────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  final double glowOpacity;
  final double pulseValue;

  _RingPainter({
    required this.progress,
    required this.glowOpacity,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: r);

    final gradient = SweepGradient(
      colors: const [
        Color(0xFF5AACDB),
        Color(0xFF3CC398),
        Color(0xFFFBA49B),
        Color(0xFF5AACDB),
      ],
      stops: const [0.0, 0.33, 0.66, 1.0],
      transform: GradientRotation(progress * math.pi * 2),
    );

    // Glow
    if (glowOpacity > 0.05) {
      canvas.drawCircle(
        center, r,
        Paint()
          ..shader = gradient.createShader(rect)
          ..strokeWidth = 10 + pulseValue * 5
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // Trait principal
    canvas.drawCircle(
      center, r,
      Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Point lumineux
    final angle = progress * math.pi * 2 - math.pi / 2;
    final dotPos = Offset(
      center.dx + r * math.cos(angle),
      center.dy + r * math.sin(angle),
    );

    canvas.drawCircle(
      dotPos, 10,
      Paint()
        ..color = Colors.white.withOpacity(0.12 * glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(
      dotPos, 4.5,
      Paint()..color = Colors.white.withOpacity(glowOpacity),
    );
    canvas.drawCircle(dotPos, 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
          old.glowOpacity != glowOpacity ||
          old.pulseValue != pulseValue;
}

// ─────────────────────────────────────────────────────────────────────────────
// Particules
// ─────────────────────────────────────────────────────────────────────────────
class _Particle {
  final double x, y, size, speed, phase;
  final Color color;
  const _Particle({
    required this.x, required this.y, required this.size,
    required this.speed, required this.phase, required this.color,
  });
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final double opacity;
  const _ParticlesPainter({
    required this.particles, required this.progress, required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (progress * p.speed + p.phase) % 1.0;
      final alpha = (math.sin(t * math.pi) * 0.5 * opacity).clamp(0.0, 0.5);
      final pos = Offset(p.x * size.width, (p.y - t * 0.3) * size.height);
      canvas.drawCircle(pos, p.size,
          Paint()..color = p.color.withOpacity(alpha * 0.4)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size));
      canvas.drawCircle(pos, p.size * 0.35,
          Paint()..color = p.color.withOpacity(alpha));
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) =>
      old.progress != progress || old.opacity != opacity;
}

// ─────────────────────────────────────────────────────────────────────────────
// Barre de chargement
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingBar extends StatelessWidget {
  final double progress;
  const _LoadingBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final t = (math.sin(progress * math.pi * 2) + 1) / 2;
    return Center(
      child: SizedBox(
        width: 100,
        height: 2.5,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Stack(children: [
            Container(color: Colors.white.withOpacity(0.07)),
            FractionallySizedBox(
              widthFactor: t,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Color(0xFF5AACDB),
                    Color(0xFF3CC398),
                    Color(0xFFFBA49B),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
