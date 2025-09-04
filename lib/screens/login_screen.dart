// lib/login_screen.dart
// Page d'authentification moderne (même nom: LoginScreen)
// Email + mot de passe + Invité + création/connexion
// UI responsive (mobile & iPad), carte verre + micro-animations

import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();

  // State
  bool _obscure = true;
  bool _loginMode = true; // true = connexion, false = inscription
  bool _loading = false;

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
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _pass.text.isEmpty) {
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
      setState(() {
        _loginMode = true;
        _pass.clear();
      });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final maxCardWidth = size.width < 600 ? size.width - 32 : 520.0; // iPad ok

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fond dégradé animé
          TweenAnimationBuilder<double>(
            duration: const Duration(seconds: 6),
            tween: Tween(begin: 0, end: 1),
            curve: Curves.easeInOut,
            onEnd: () => setState(() {}),
            builder: (context, t, _) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.6 + 1.2 * t, -0.4),
                    radius: 1.2,
                    colors: const [
                      Color(0xFF3A0CA3),
                      Color(0xFF4361EE),
                      Color(0xFF4CC9F0),
                    ],
                    stops: const [0.1, 0.55, 1.0],
                  ),
                ),
              );
            },
          ),

          // Motif doux
          IgnorePointer(
            child: CustomPaint(
              painter: _GridPainter(opacity: 0.08),
            ),
          ),

          // Formulaire (carte verre)
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxCardWidth),
              child: _FrostedCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _loginMode ? 'Connexion' : 'Créer un compte',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (!_loginMode)
                      _LabeledField(
                        label: 'Nom',
                        child: TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'Votre nom',
                          ),
                        ),
                      ),

                    _LabeledField(
                      label: 'Email',
                      child: TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'exemple@email.com',
                        ),
                      ),
                    ),

                    _LabeledField(
                      label: 'Mot de passe',
                      child: TextField(
                        controller: _pass,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Bouton principal
                    _GradientButton(
                      loading: _loading,
                      label: _loginMode ? 'Se connecter' : 'S\'inscrire',
                      icon: _loginMode ? Icons.login : Icons.person_add,
                      onPressed: _loading
                          ? null
                          : (_loginMode ? _signInEmail : _signUpEmail),
                    ),

                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() => _loginMode = !_loginMode),
                      child: Text(
                        _loginMode
                            ? 'Créer un compte'
                            : 'Déjà inscrit ? Connexion',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),

                    const SizedBox(height: 8),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),

                    // Invité
                    _GlassButton(
                      loading: _loading,
                      icon: Icons.videogame_asset_rounded,
                      label: 'Continuer en invité',
                      onPressed: _loading ? null : _guest,
                    ),

                    const SizedBox(height: 14),
                    const Text(
                      '© @AI NEGO · RGPD',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Widgets UI ---
class _FrostedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _FrostedCard({required this.child, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white.withOpacity(0.10),
                hintStyle: const TextStyle(color: Colors.white54),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
        ),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: btn,
    );
  }
}

class _GlassButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  const _GlassButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.10),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: Colors.white.withOpacity(0.28)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double opacity;
  const _GridPainter({this.opacity = 0.06});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 1;
    const step = 28.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
