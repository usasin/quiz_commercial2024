// lib/login_screen.dart – refonte 2025
// ignore_for_file: use_build_context_synchronously, avoid_print
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../ad_manager.dart';

/*───────────────────────────────────────────────────────────*/
/*                       STATE FULL WIDGET                   */
/*───────────────────────────────────────────────────────────*/
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/*───────────────────────────────────────────────────────────*/
class _LoginScreenState extends State<LoginScreen> {
  // ---------- Firebase & Controllers ----------
  final _auth   = FirebaseAuth.instance;
  final _google = GoogleSignIn();
  final _cMail  = TextEditingController();
  final _cPass  = TextEditingController();
  final _cName  = TextEditingController();

  // ---------- UI states ----------
  bool _obscure = true;
  bool _remember = false;
  bool _loginMode = true;

  // ---------- BannerAd ----------
  late final BannerAd _banner;
  bool _bannerReady = false;

  /*==========================================================
   *                         INIT / DISPOSE
   *=========================================================*/
  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _initBanner();
    if (_auth.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback(
              (_) => Navigator.pushReplacementNamed(context, '/chapter_menu'));
    }
  }

  void _initBanner() {
    _banner = BannerAd(
      adUnitId: AdManager.bannerAdUnitId,
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _bannerReady = true),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
      request: const AdRequest(),
    )..load();
  }

  @override
  void dispose() {
    _banner.dispose();
    _cMail.dispose();
    _cPass.dispose();
    _cName.dispose();
    super.dispose();
  }

  /*==========================================================
   *                         PREFERENCES
   *=========================================================*/
  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _cMail.text = p.getString('email') ?? '';
      _cPass.text = p.getString('password') ?? '';
      _remember   = p.getBool  ('rememberMe') ?? false;
    });
  }

  Future<void> _savePrefs() async {
    if (!_remember) return;
    final p = await SharedPreferences.getInstance();
    p
      ..setString('email', _cMail.text)
      ..setString('password', _cPass.text)
      ..setBool  ('rememberMe', true);
  }

  /*==========================================================
   *                   FIREBASE HELPERS
   *=========================================================*/
  Future<void> _ensureUserDoc(User u, {String? displayName}) async {
    final ref  = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final snap = await ref.get();

    await ref.set({
      'name'     : displayName ?? u.displayName ?? 'User',
      'email'    : u.email ?? '',
      'photoURL' : u.photoURL ?? '',
    }, SetOptions(merge: true));

    if (!snap.exists) {
      await ref.set({
        'createdAt'       : FieldValue.serverTimestamp(),
        'totalScore'      : 0,
        'unlockedLevels'  : {},
        'unlockedModules' : {},
        'chapters'        : {},
      }, SetOptions(merge: true));
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      ref.set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  /*==========================================================
   *                       AUTH FLOWS
   *=========================================================*/
  Future<void> _signInMail() async {
    if (_cMail.text.isEmpty || _cPass.text.isEmpty) return;
    try {
      await _auth.signInWithEmailAndPassword(
          email: _cMail.text, password: _cPass.text);
      await _savePrefs();
      await _ensureUserDoc(_auth.currentUser!);
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Erreur');
    }
  }

  Future<void> _signUpMail() async {
    if ([_cName.text, _cMail.text, _cPass.text].any((e) => e.isEmpty)) return;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: _cMail.text, password: _cPass.text);
      await _ensureUserDoc(cred.user!, displayName: _cName.text);
      _snack('Inscription réussie, connecte-toi 👍');
      setState(() {
        _loginMode = true;
        _cPass.clear();
      });
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Erreur signup');
    }
  }

  Future<void> _googleSignIn() async {
    try {
      final gUser = await _google.signIn();
      if (gUser == null) return;
      final gAuth = await gUser.authentication;
      final cred  = GoogleAuthProvider.credential(
          idToken: gAuth.idToken, accessToken: gAuth.accessToken);
      final res = await _auth.signInWithCredential(cred);
      await _ensureUserDoc(res.user!);
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } catch (e) {
      _snack('Erreur Google : $e');
    }
  }

  // ---- Helpers nonce Apple
  String _randomNonce([int len = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(len, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _sha256ofString(String input) =>
      sha256.convert(Uri.encodeFull(input).codeUnits).toString();

  Future<void> _appleSignIn() async {
    try {
      final rawNonce = _randomNonce();
      final nonce    = _sha256ofString(rawNonce);

      final appleId = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName],
        nonce : nonce,
      );

      final cred = OAuthProvider('apple.com').credential(
        idToken     : appleId.identityToken,
        rawNonce    : rawNonce,
        accessToken : appleId.authorizationCode,
      );

      final res = await _auth.signInWithCredential(cred);
      await _ensureUserDoc(res.user!,
          displayName: '${appleId.givenName ?? ''} ${appleId.familyName ?? ''}'
              .trim());
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } catch (e) {
      _snack('Erreur Apple : $e');
    }
  }

  Future<void> _guest() async {
    try {
      final res = await _auth.signInAnonymously();
      await _ensureUserDoc(res.user!, displayName: 'Invité');
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } catch (e) {
      _snack('Invité: $e');
    }
  }

  /*==========================================================
   *                       UI HELPERS
   *=========================================================*/
  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  InputDecoration _dec(String label, {Widget? icon}) => InputDecoration(
    labelText: label,
    border: const UnderlineInputBorder(),
    suffixIcon: icon,
  );

  /*==========================================================
   *                         BUILD
   *=========================================================*/
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final btnGrad = [
      Colors.blue.shade800,
      Colors.white,
      Colors.blue.shade800,
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: _bannerReady
          ? SizedBox(height: _banner.size.height.toDouble(),
          child: AdWidget(ad: _banner))
          : null,
      body: Stack(
        children: [
          // --- gradient flou derrière la carte
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xff002d74), Color(0xff005ee0)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
          BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withOpacity(.25))),
          // --- CARD
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.background.withOpacity(.75),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(.3),
                      blurRadius: 30,
                      offset: const Offset(0, 14))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // Titre
                    Text(
                      _loginMode ? 'Bienvenue'.tr() : 'Créer un compte'.tr(),
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),

                    // --- Form ---
                    if (!_loginMode)
                      TextField(controller: _cName,
                          textCapitalization: TextCapitalization.words,
                          decoration: _dec('Nom'.tr())),
                    TextField(controller: _cMail,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _dec('Email'.tr())),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _cPass,
                      obscureText: _obscure,
                      decoration: _dec('Mot de passe'.tr(),
                          icon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                                  color: cs.primary),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure))),
                    ),

                    // --- remember ---
                    const SizedBox(height: 6),
                    Row(children: [
                      Checkbox(
                          value: _remember,
                          activeColor: cs.primary,
                          onChanged: (v) => setState(() => _remember = v!)),
                      Text('Se souvenir de moi'.tr())
                    ]),

                    // --- Action btn ---
                    const SizedBox(height: 4),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          backgroundColor: Colors.blue.shade800),
                      icon: Icon(_loginMode
                          ? Icons.login
                          : Icons.person_add_alt_1),
                      label: Text(_loginMode
                          ? 'Se connecter'.tr()
                          : 'S’inscrire'.tr()),
                      onPressed: _loginMode ? _signInMail : _signUpMail,
                    ),
                    TextButton(
                        onPressed: () => setState(() => _loginMode = !_loginMode),
                        child: Text(_loginMode
                            ? 'Créer un compte'
                            : 'Déjà inscrit ? Connectez-vous')
                            .tr()),

                    const Divider(height: 26),

                    // -------- SSO AREA --------
                    // Apple d’abord (obligatoire) puis Google (iOS),
                    // Google seul sur Android
                    if (Platform.isIOS) ...[
                      SignInWithAppleButton(
                        borderRadius: BorderRadius.circular(12),
                        height: 48,
                        onPressed: _appleSignIn,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        icon: SvgPicture.asset('assets/icons/Google.svg',
                            height: 22),
                        label: const Text('Google'),
                        onPressed: _googleSignIn,
                      ),
                    ] else
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        icon: SvgPicture.asset('assets/icons/Google.svg',
                            height: 22),
                        label: const Text('Google'),
                        onPressed: _googleSignIn,
                      ),

                    const SizedBox(height: 16),

                    // Invité
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.videogame_asset),
                      label: const Text('Continuer en invité'),
                      onPressed: _guest,
                    ),

                    const SizedBox(height: 20),
                    Text('© 2025 AI-Nego • RGPD ready',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: cs.outline)),
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
