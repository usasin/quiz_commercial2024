// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

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

class _LoginScreenState extends State<LoginScreen> {
  /* ---------- controllers ---------- */
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  final _name  = TextEditingController();

  /* ---------- state ---------- */
  bool _obscure   = true;
  bool _loginMode = true; // true = connexion, false = inscription
  bool _loading   = false;

  /* ---------- helpers UI ---------- */
  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  InputDecoration _dec(String label, {Widget? icon}) =>
      InputDecoration(labelText: label, suffixIcon: icon);

  Future<void> _guarded(Future<void> Function() run) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await run();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /* ---------- Firestore user doc ---------- */
  Future<void> _createOrUpdateUserDoc(User u, {String? name}) async {
    final ref  = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final snap = await ref.get();

    await ref.set({
      'name'     : name ?? u.displayName ?? 'Invité',
      'email'    : u.email ?? '',
      'photoURL' : u.photoURL ?? '',
    }, SetOptions(merge: true));

    if (!snap.exists) {
      await ref.set({
        'createdAt'      : FieldValue.serverTimestamp(),
        'totalScore'     : 0,
        'chapters'       : {},
        'unlockedLevels' : {},
        'unlockedModules': {},
        'lastChapterId'  : '',
        'scrollPositions': {},
      }, SetOptions(merge: true));
    }
  }

  /* ---------- Email / Invité ---------- */
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
    if ([_name, _email, _pass].any((c) => c.text.isEmpty)) {
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
      setState(() { _loginMode = true; _pass.clear(); });
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

  /* ---------- Google Sign-In ---------- */
  Future<void> _signInWithGoogle() => _guarded(() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // annulé par l'utilisateur

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

  /* ---------- Apple Sign-In (iOS) ---------- */

  // Nonce aléatoire + SHA256 requis par Firebase pour Apple
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _signInWithApple() => _guarded(() async {
    try {
      // Apple Sign-In ne fonctionne nativement que sur iOS
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        _snack('Apple Sign-In indisponible sur cet appareil.');
        return;
      }

      final rawNonce = _generateNonce();
      final nonce    = _sha256ofString(rawNonce);

      final appleIdCred = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: nonce,
      );

      final oauthCred = OAuthProvider('apple.com').credential(
        idToken: appleIdCred.identityToken,
        rawNonce: rawNonce,
      );

      final userCred =
          await FirebaseAuth.instance.signInWithCredential(oauthCred);

      final fullName = [
        appleIdCred.givenName ?? '',
        appleIdCred.familyName ?? ''
      ].where((s) => s.isNotEmpty).join(' ').trim();

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

  /* ---------- build ---------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authentification')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loginMode ? 'Connexion' : 'Créer un compte',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),

              if (!_loginMode)
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec('Nom'),
                ),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('Email'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _pass,
                obscureText: _obscure,
                decoration: _dec(
                  'Mot de passe',
                  icon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(_loginMode ? Icons.login : Icons.person_add),
                  label: Text(_loginMode ? 'Se connecter' : 'S’inscrire'),
                  onPressed: _loading
                      ? null
                      : (_loginMode ? _signInEmail : _signUpEmail),
                ),
              ),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => setState(() => _loginMode = !_loginMode),
                child: Text(_loginMode ? 'Créer un compte' : 'Déjà inscrit ? Connexion'),
              ),

              const Divider(height: 32),

              // ——— Sign-in providers ———
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                  label: const Text('Continuer avec Google'),
                  onPressed: _loading ? null : _signInWithGoogle,
                ),
              ),
              const SizedBox(height: 8),
              if (Platform.isIOS)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.apple),
                    label: const Text('Continuer avec Apple'),
                    onPressed: _loading ? null : _signInWithApple,
                  ),
                ),

              const SizedBox(height: 16),
              const Divider(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                  icon: const Icon(Icons.videogame_asset),
                  label: const Text('Continuer en invité'),
                  onPressed: _loading ? null : _guest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
