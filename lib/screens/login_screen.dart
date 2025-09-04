// ignore_for_file: avoid_print
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // Controllers
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  final _name  = TextEditingController();

  // State
  bool _isLogin = true; // true = connexion, false = inscription
  bool _obscure = true;
  bool _loading = false;

  // Animations
  late final AnimationController _bgCtrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))
        ..repeat();
  late final AnimationController _shimmerCtrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);

  // Helpers
  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _guarded(Future<void> Function() run) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await run();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white.withOpacity(0.85),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  Future<void> _createOrUpdateUserDoc(User u, {String? name}) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final snap = await ref.get();

    await ref.set({
      'name': name ?? u.displayName ?? 'Invité',
      'email': u.email ?? '',
      'photoURL': u.photoURL ?? '',
    }, SetOptions(merge: true));

    if (!snap.exists) {
      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
        'totalScore': 0,
        'chapters': {},
        'unlockedLevels': {},
        'unlockedModules': {},
        'lastChapterId': '',
        'scrollPositions': {},
      }, SetOptions(merge: true));
    }
  }

  // Email / Password
  Future<void> _signInEmail() => _guarded(() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
      await _createOrUpdateUserDoc(FirebaseAuth.instance.currentUser!);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Erreur de connexion');
    }
  });

  Future<void> _signUpEmail() => _guarded(() async {
    if ([_name, _email, _pass].any((c) => c.text.trim().isEmpty)) {
      _snack('Complète nom, email et mot de passe.');
      return;
    }
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
      await _createOrUpdateUserDoc(cred.user!, name: _name.text.trim());
      _snack('Inscription réussie, connecte-toi 👍');
      setState(() { _isLogin = true; _pass.clear(); });
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Erreur inscription');
    }
  });

  Future<void> _guest() => _guarded(() async {
    try {
      final res = await FirebaseAuth.instance.signInAnonymously();
      await _createOrUpdateUserDoc(res.user!, name: 'Invité');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } on FirebaseAuthException catch (e) {
      _snack('Invité : ${e.message}');
    }
  });

  // UI pieces
  Widget _gradientButton({
    required String label,
    required VoidCallback? onTap,
    IconData? icon,
    List<Color>? colors,
  }) {
    final gradient = colors ??
        [const Color(0xff7F5AF0), const Color(0xff2CB67D)]; // violet -> vert

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        onTap: _loading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleShimmer(String text) {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, _) {
        final t = _shimmerCtrl.value; // 0..1
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: const Alignment(1, 0),
              colors: const [
                Color(0xff2CB67D), // green
                Color(0xff7F5AF0), // purple
                Color(0xff00C2FF), // cyan
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
          },
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _shimmerCtrl.dispose();
    _email.dispose();
    _pass.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPad = size.shortestSide >= 600;

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, __) {
                final t = _bgCtrl.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-0.8 + t, -1),
                      end: Alignment(1, 0.8 - t),
                      colors: const [
                        Color(0xff0F1020),
                        Color(0xff121629),
                        Color(0xff1F2544),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Soft blobs for depth
          Positioned(
            left: -80,
            top: -40,
            child: _blob(const Color(0xFF7F5AF0)),
          ),
          Positioned(
            right: -60,
            bottom: -60,
            child: _blob(const Color(0xFF2CB67D)),
          ),

          // Glass card
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isPad ? 520 : 420),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: isPad ? 24 : 16, vertical: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.20),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Image.asset(
                                'assets/images/logo.png',
                                height: isPad ? 100 : 80,
                                fit: BoxFit.contain,
                              ),
                            ),
                            _titleShimmer(
                                _isLogin ? 'Connexion' : 'Créer un compte'),
                            const SizedBox(height: 18),

                            if (!_isLogin)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TextField(
                                  controller: _name,
                                  textCapitalization:
                                      TextCapitalization.words,
                                  decoration: _dec('Nom', Icons.person),
                                ),
                              ),
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _dec('Email', Icons.email),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _pass,
                              obscureText: _obscure,
                              decoration: _dec('Mot de passe', Icons.lock)
                                  .copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            _gradientButton(
                              label:
                                  _isLogin ? 'Se connecter' : 'Créer le compte',
                              icon: _isLogin ? Icons.login : Icons.person_add,
                              onTap: _isLogin ? _signInEmail : _signUpEmail,
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => setState(() => _isLogin = !_isLogin),
                              child: Text(_isLogin
                                  ? 'Créer un compte'
                                  : 'Déjà un compte ? Se connecter'),
                            ),

                            const SizedBox(height: 10),
                            Row(
                              children: const [
                                Expanded(child: Divider(color: Colors.white38)),
                                Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text('ou',
                                      style:
                                          TextStyle(color: Colors.white70)),
                                ),
                                Expanded(child: Divider(color: Colors.white38)),
                              ],
                            ),
                            const SizedBox(height: 10),

                            _gradientButton(
                              label: 'Continuer en invité',
                              icon: Icons.gamepad_outlined,
                              colors: const [
                                Color(0xff00C2FF),
                                Color(0xff7F5AF0),
                              ],
                              onTap: _guest,
                            ),

                            const SizedBox(height: 14),
                            Text(
                              '© AI NEGO — RGPD / grpd',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Soft colored blob
  Widget _blob(Color color) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(seconds: 8),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeInOut,
      builder: (_, t, __) {
        return Container(
          width: 220 + 20 * t,
          height: 220 + 20 * (1 - t),
          decoration: BoxDecoration(
            color: color.withOpacity(0.22),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.25),
                blurRadius: 80,
                spreadRadius: 40,
              ),
            ],
          ),
        );
      },
    );
  }
}
