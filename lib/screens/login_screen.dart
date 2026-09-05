// ignore_for_file: avoid_print

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../services/usage_meter.dart';
import '../services/app_language.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();
  final _secure = const FlutterSecureStorage();

  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();

  bool _isLogin = true;
  bool _obscure = true;
  bool _loading = false;
  bool _remember = false;

  static const _prefEmail = 'login_email';
  static const _prefRemember = 'login_remember';
  static const _securePassKey = 'login_password';

  @override
  void initState() {
    super.initState();
    _loadPrefs();

    // Si déjà connecté -> direct levels
    if (_auth.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/levels');
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _name.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _guarded(Future<void> Function() run) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await run();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPass = await _secure.read(key: _securePassKey);
      if (!mounted) return;
      setState(() {
        _remember = prefs.getBool(_prefRemember) ?? false;
        _email.text = prefs.getString(_prefEmail) ?? '';
        _pass.text = (_remember ? (savedPass ?? '') : '');
      });
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_remember) {
        await prefs.setBool(_prefRemember, true);
        await prefs.setString(_prefEmail, _email.text.trim());
        await _secure.write(key: _securePassKey, value: _pass.text);
      } else {
        await prefs.setBool(_prefRemember, false);
        await prefs.remove(_prefEmail);
        await _secure.delete(key: _securePassKey);
      }
    } catch (_) {}
  }

  Future<void> _ensureUserDoc(User u, {String? displayName}) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final snap = await ref.get();

    final name =
        (displayName ??
                u.displayName ??
                context.bilingual(fr: 'Utilisateur', en: 'User'))
            .trim();
    await ref.set({
      'name': name,
      'name_lower': name.toLowerCase(),
      'email': u.email ?? '',
      'photoURL': u.photoURL ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!snap.exists) {
      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
        'xp': 0,
        'streakDays': 0,
        'totalScore': 0,
        'levelsResults': {},
      }, SetOptions(merge: true));
    }

    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await ref.set({'fcmToken': token}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> _signInEmail() => _guarded(() async {
    final email = _email.text.trim();
    if (email.isEmpty || _pass.text.isEmpty) {
      _snack(
        context.bilingual(
          fr: 'Entre ton email et ton mot de passe.',
          en: 'Enter your email and password.',
        ),
      );
      return;
    }
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: _pass.text,
      );
      await _savePrefs();
      await _ensureUserDoc(_auth.currentUser!);
      final meter = UsageMeter();
      await meter.initIfNeeded();
      await meter.syncFromCloud();
      await meter.pushToCloud();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/levels');
    } on FirebaseAuthException catch (e) {
      _snack(
        e.message ??
            context.bilingual(fr: 'Erreur de connexion', en: 'Sign-in error'),
      );
    }
  });

  Future<void> _signUpEmail() => _guarded(() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty || email.isEmpty || _pass.text.isEmpty) {
      _snack(
        context.bilingual(
          fr: 'Complète nom, email et mot de passe.',
          en: 'Enter your name, email and password.',
        ),
      );
      return;
    }
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: _pass.text,
      );
      await _ensureUserDoc(cred.user!, displayName: name);
      final meter = UsageMeter();
      await meter.initIfNeeded();
      await meter.syncFromCloud();
      await meter.pushToCloud();
      await _savePrefs();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/levels');
    } on FirebaseAuthException catch (e) {
      _snack(
        e.message ??
            context.bilingual(
              fr: "Erreur d'inscription",
              en: 'Registration error',
            ),
      );
    }
  });

  Future<void> _google() => _guarded(() async {
    try {
      final gUser = await _googleSignIn.signIn();
      if (gUser == null) return;

      final gAuth = await gUser.authentication;
      final cred = GoogleAuthProvider.credential(
        idToken: gAuth.idToken,
        accessToken: gAuth.accessToken,
      );

      final res = await _auth.signInWithCredential(cred);
      await _ensureUserDoc(res.user!);
      final meter = UsageMeter();
      await meter.initIfNeeded();
      await meter.syncFromCloud();
      await meter.pushToCloud();
      await _savePrefs();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/levels');
    } catch (e) {
      _snack(
        '${context.bilingual(fr: 'Erreur Google', en: 'Google sign-in error')} : $e',
      );
    }
  });

  Future<void> _apple() => _guarded(() async {
    try {
      final appleId = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final cred = OAuthProvider('apple.com').credential(
        idToken: appleId.identityToken,
        accessToken: appleId.authorizationCode,
      );

      final res = await _auth.signInWithCredential(cred);

      final dn = '${appleId.givenName ?? ''} ${appleId.familyName ?? ''}'
          .trim();
      await _ensureUserDoc(res.user!, displayName: dn.isEmpty ? null : dn);
      final meter = UsageMeter();
      await meter.initIfNeeded();
      await meter.syncFromCloud();
      await meter.pushToCloud();

      await _savePrefs();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/levels');
    } catch (e) {
      _snack(
        '${context.bilingual(fr: 'Erreur Apple', en: 'Apple sign-in error')} : $e',
      );
    }
  });

  void _continueAsGuest() {
    Navigator.pushReplacementNamed(context, '/levels');
  }

  InputDecoration _dec(BuildContext context, String label, IconData icon) {
    final cs = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: cs.primary, size: 22),
      filled: true,
      fillColor: cs.surface,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _segmented(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segBtn(
              active: _isLogin,
              label: context.bilingual(fr: 'Connexion', en: 'Sign in'),
              onTap: () => setState(() => _isLogin = true),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _segBtn(
              active: !_isLogin,
              label: context.bilingual(fr: 'Inscription', en: 'Register'),
              onTap: () => setState(() => _isLogin = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segBtn({
    required bool active,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: active ? const Color(0xFF111827) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : onTap,
        icon: Icon(icon, size: 22),
        label: Text(label, textAlign: TextAlign.center),
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          alignment: Alignment.center,
          elevation: 0,
        ),
      ),
    );
  }

  Widget _socialButton({
    required String label,
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : onTap,
        icon: Icon(icon, size: 24),
        label: Text(label, textAlign: TextAlign.center),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          alignment: Alignment.center,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final shortest = MediaQuery.of(context).size.shortestSide;
    final isPad = shortest >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.bilingual(fr: 'Connexion', en: 'Sign in')),
        actions: [
          PopupMenuButton<String>(
            tooltip: context.bilingual(fr: 'Langue', en: 'Language'),
            initialValue: context.locale.languageCode,
            onSelected: (languageCode) {
              context.setLocale(Locale(languageCode));
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'fr', child: Text('🇫🇷  Français')),
              PopupMenuItem(value: 'en', child: Text('🇬🇧  English')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.language_rounded),
                  Text(
                    context.locale.languageCode.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isPad ? 24 : 16,
            vertical: 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isPad ? 520 : 420),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
                border: Border.all(color: cs.outline.withOpacity(0.7)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary.withOpacity(0.12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.school_rounded,
                          color: cs.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          context.bilingual(
                            fr: 'Prépa Boost',
                            en: 'Prep Boost',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _segmented(context),
                  const SizedBox(height: 14),

                  if (!_isLogin) ...[
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dec(
                        context,
                        context.bilingual(fr: 'Nom', en: 'Name'),
                        Icons.person_rounded,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _dec(context, "Email", Icons.email_rounded),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _pass,
                    obscureText: _obscure,
                    decoration:
                        _dec(
                          context,
                          context.bilingual(fr: 'Mot de passe', en: 'Password'),
                          Icons.lock_rounded,
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: cs.primary,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: _remember,
                        activeColor: cs.primary,
                        onChanged: _loading
                            ? null
                            : (v) => setState(() => _remember = v ?? false),
                      ),
                      Expanded(
                        child: Text(
                          context.bilingual(
                            fr: 'Se souvenir de moi',
                            en: 'Remember me',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  _primaryButton(
                    context: context,
                    label: _isLogin
                        ? context.bilingual(fr: 'Se connecter', en: 'Sign in')
                        : context.bilingual(
                            fr: 'Créer mon compte',
                            en: 'Create my account',
                          ),
                    icon: _isLogin
                        ? Icons.login_rounded
                        : Icons.person_add_alt_1_rounded,
                    onTap: _isLogin ? _signInEmail : _signUpEmail,
                  ),

                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: cs.outline.withOpacity(0.7)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          context.bilingual(fr: 'OU', en: 'OR'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: cs.outline.withOpacity(0.7)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _socialButton(
                    label: context.bilingual(
                      fr: 'Continuer avec Google',
                      en: 'Continue with Google',
                    ),
                    icon: Icons.g_mobiledata_rounded,
                    bg: Colors.white,
                    fg: const Color(0xFF111827),
                    onTap: _google,
                  ),

                  if (Platform.isIOS) ...[
                    const SizedBox(height: 10),
                    _socialButton(
                      label: context.bilingual(
                        fr: 'Continuer avec Apple',
                        en: 'Continue with Apple',
                      ),
                      icon: Icons.apple_rounded,
                      bg: Colors.black,
                      fg: Colors.white,
                      onTap: _apple,
                    ),
                  ],

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _continueAsGuest,
                      icon: const Icon(Icons.explore_rounded, size: 22),
                      label: Text(
                        context.bilingual(
                          fr: 'Continuer en invité',
                          en: 'Continue as guest',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.secondary,
                        side: BorderSide(color: cs.secondary.withOpacity(0.55)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Text(
                    context.bilingual(
                      fr: 'En te connectant, tu sauvegardes ta progression et débloques les chapitres.',
                      en: 'Sign in to save your progress and unlock chapters.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.55),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),

                  if (_loading) ...[
                    const SizedBox(height: 12),
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
