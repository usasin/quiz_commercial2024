// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // Controllers
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();

  // State
  bool _obscure = true;
  bool _isLogin = true;
  bool _loading = false;

  // Animated background
  late final AnimationController _bgCtrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 10))
        ..repeat();

  // Utils
  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  InputDecoration _dec(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );

  Future<void> _guarded(Future<void> Function() run) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await run();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Firestore user
  Future<void> _createOrUpdateUserDoc(User u, {String? name}) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final existed = (await ref.get()).exists;

    await ref.set({
      'name': name ?? u.displayName ?? 'Invité',
      'email': u.email ?? '',
      'photoURL': u.photoURL ?? '',
    }, SetOptions(merge: true));

    if (!existed) {
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

  // Email / MDP
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
      final c = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
      await _createOrUpdateUserDoc(c.user!, name: _name.text.trim());
      _snack('Inscription réussie, connecte-toi 👍');
      setState(() {
        _isLogin = true;
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

  // Google
  Future<void> _signInWithGoogle() => _guarded(() async {
    try {
      final googleUser = await GoogleSignIn(
        // Sur iOS, pas besoin de clientId si GoogleService-Info.plist est correct.
        scopes: <String>['email', 'profile'],
      ).signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);

      await _createOrUpdateUserDoc(userCred.user!);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Connexion Google impossible');
    } catch (e) {
      _snack('Erreur Google : $e');
    }
  });

  // Apple
  String _nonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();

  Future<void> _signInWithApple() => _guarded(() async {
    try {
      if (!await SignInWithApple.isAvailable()) {
        _snack('Apple Sign-In indisponible sur cet appareil.');
        return;
      }
      final raw = _nonce();
      final hashed = _sha256(raw);

      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: hashed,
      );

      final oauth = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        rawNonce: raw,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(oauth);
      final fullName = [
        apple.givenName ?? '',
        apple.familyName ?? '',
      ].where((e) => e.isNotEmpty).join(' ').trim();

      await _createOrUpdateUserDoc(
        userCred.user!,
        name: fullName.isEmpty ? null : fullName,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        _snack('Apple : ${e.message}');
      }
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Connexion Apple impossible');
    } catch (e) {
      _snack('Erreur Apple : $e');
    }
  });

  // UI helpers
  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
  }) {
    final btn = ElevatedButton(
      onPressed: _loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon),
            const SizedBox(width: 8),
          ],
          Text(label),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.25),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
        borderRadius: BorderRadius.circular(16),
      ),
      child: btn,
    );
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _email.dispose();
    _pass.dispose();
    _name.dispose();
    super.dispose();
    }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPad = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, __) {
                final t = _bgCtrl.value;
                final colors = [
                  Color.lerp(Colors.deepPurple, Colors.indigo, t)!,
                  Color.lerp(Colors.blue, Colors.teal, t)!,
                  Color.lerp(Colors.purple, Colors.pink, t)!,
                ];
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.6 + t, -0.4 + t),
                      radius: 1.2,
                      colors: colors,
                    ),
                  ),
                );
              },
            ),
          ),
          // Glass card
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isPad ? 520 : 420),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isPad ? 32 : 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isLogin ? 'Connexion' : 'Créer un compte',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 18),

                          if (!_isLogin)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextField(
                                controller: _name,
                                textCapitalization: TextCapitalization.words,
                                decoration: _dec('Nom', icon: Icons.person),
                              ),
                            ),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _dec('Email', icon: Icons.email),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pass,
                            obscureText: _obscure,
                            decoration: _dec('Mot de passe', icon: Icons.lock).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          _primaryButton(
                            label: _isLogin ? 'Se connecter' : 'S’inscrire',
                            icon: _isLogin ? Icons.login : Icons.person_add,
                            onPressed: _isLogin ? _signInEmail : _signUpEmail,
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => setState(() => _isLogin = !_isLogin),
                            child: Text(
                              _isLogin
                                  ? 'Créer un compte'
                                  : 'Déjà un compte ? Se connecter',
                            ),
                          ),

                          const SizedBox(height: 8),
                          Row(
                            children: const [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text('ou'),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Providers
                          _primaryButton(
                            label: 'Continuer avec Google',
                            icon: Icons.g_mobiledata_rounded,
                            onPressed: _signInWithGoogle,
                          ),
                          if (Platform.isIOS) ...[
                            const SizedBox(height: 10),
                            _primaryButton(
                              label: 'Continuer avec Apple',
                              icon: Icons.apple,
                              onPressed: _signInWithApple,
                            ),
                          ],

                          const SizedBox(height: 16),
                          _primaryButton(
                            label: 'Continuer en invité',
                            icon: Icons.videogame_asset,
                            onPressed: _guest,
                          ),

                          const SizedBox(height: 14),
                          Text(
                            '© AI NEGO — RGPD / grpd',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
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
}
