// login_screen.dart — refonte UI 2025 (corrected)
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ad_manager.dart';
import '../gradient_text.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/*───────────────────────────────────────────────────────────*/

class _LoginScreenState extends State<LoginScreen> {
  /* ------------- Instances ------------- */
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _secure = const FlutterSecureStorage();

  /* ------------- UI states ------------- */
  bool _obscure = true;
  bool _remember = false;
  bool _loginMode = true;

  /* ------------- Ad banner ------------- */
  late final BannerAd _banner;
  bool _bannerReady = false;

  /* ******************************************************* */
  /*  INIT / DISPOSE                                         */
  /* ******************************************************* */
  @override
  void initState() {
    super.initState();
    _requestATTIfNeeded();
    _loadInfo();
    _initBanner();
    if (_auth.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/chapter_menu');
      });
    }
  }

  Future<void> _requestATTIfNeeded() async {
    if (Platform.isIOS) {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    }
  }

  void _initBanner() {
    _banner = BannerAd(
      adUnitId: AdManager.bannerAdUnitId,
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _bannerReady = true),
        onAdFailedToLoad: (ad, err) => ad.dispose(),
      ),
      request: const AdRequest(),
    )
      ..load();
  }

  @override
  void dispose() {
    _banner.dispose();
    _email.dispose();
    _pass.dispose();
    _name.dispose();
    super.dispose();
  }

  /* ******************************************************* */
  /*  PREFERENCES & SECURE STORAGE                           */
  /* ******************************************************* */
  Future<void> _loadInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPass = await _secure.read(key: 'password');
    if (!mounted) return;
    setState(() {
      _email.text = prefs.getString('email') ?? '';
      _pass.text = storedPass ?? '';
      _remember = prefs.getBool('rememberMe') ?? false;
    });
  }

  Future<void> _saveInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (_remember) {
      await prefs.setString('email', _email.text);
      await prefs.setBool('rememberMe', true);
      await _secure.write(key: 'password', value: _pass.text);
    } else {
      await prefs.remove('email');
      await prefs.remove('rememberMe');
      await _secure.delete(key: 'password');
    }
  }

  /* ******************************************************* */
  /*  FIREBASE HELPERS                                       */
  /* ******************************************************* */
  Future<void> _ensureUserDoc(User u, {String? displayName}) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final snap = await ref.get();

    await ref.set({
      'name': displayName ?? u.displayName ?? 'Invité',
      'email': u.email ?? '',
      'photoURL': u.photoURL ?? '',
    }, SetOptions(merge: true));

    if (!snap.exists) {
      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
        'chapters': {},
        'totalScore': 0,
        'unlockedLevels': {},
        'unlockedModules': {},
        'lastChapterId': '',
        'scrollPositions': {},
      }, SetOptions(merge: true));
    }

    // Demande de permission notifications (iOS ≥ 10 / Android 13+)
    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await ref.set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  /* ******************************************************* */
  /*  AUTH FLOWS                                             */
  /* ******************************************************* */
  Future<void> _signInMail() async {
    if (_email.text.isEmpty || _pass.text.isEmpty) return;
    try {
      await _auth.signInWithEmailAndPassword(
          email: _email.text, password: _pass.text);
      await _saveInfo();
      await _ensureUserDoc(_auth.currentUser!);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Erreur');
    }
  }

  Future<void> _signUpMail() async {
    if ([_name.text, _email.text, _pass.text].any((e) => e.isEmpty)) return;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: _email.text, password: _pass.text);
      await _ensureUserDoc(cred.user!, displayName: _name.text);
      if (!mounted) return;
      _snack('Inscription réussie, connecte-toi 👍');
      setState(() {
        _loginMode = true;
        _pass.clear();
      });
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Erreur signup');
    }
  }

  Future<void> _google() async {
    try {
      final gUser = await _googleSignIn.signIn();
      if (gUser == null) return;
      final gAuth = await gUser.authentication;
      final cred = GoogleAuthProvider.credential(
          idToken: gAuth.idToken, accessToken: gAuth.accessToken);
      final res = await _auth.signInWithCredential(cred);
      await _ensureUserDoc(res.user!);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } catch (e) {
      _snack('Erreur Google : $e');
    }
  }

  Future<void> _apple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256OfString(rawNonce);

      final appleId = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName
        ],
        nonce: nonce,
      );

      final cred = OAuthProvider('apple.com').credential(
        idToken: appleId.identityToken,
        rawNonce: rawNonce,
      );

      final res = await _auth.signInWithCredential(cred);
      await _ensureUserDoc(res.user!,
          displayName:
          '${appleId.givenName ?? ''} ${appleId.familyName ?? ''}'.trim());
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } catch (e) {
      _snack('Erreur Apple : $e');
    }
  }

  Future<void> _guest() async {
    try {
      final res = await _auth.signInAnonymously();
      await _ensureUserDoc(res.user!, displayName: 'Invité');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } on FirebaseAuthException catch (e) {
      _snack('Invité: ${e.message}');
    }
  }

  /* ******************************************************* */
  /*  UI HELPERS                                             */
  /* ******************************************************* */
  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  InputDecoration _dec(String label, {Widget? icon}) =>
      InputDecoration(
        labelText: label,
        border: const UnderlineInputBorder(),
        suffixIcon: icon,
      );

  /* ******************************************************* */
  /*  NONCE HELPERS                                          */
  /* ******************************************************* */
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(
        length, (_) => charset[rand.nextInt(charset.length)]).join();
  }

  String _sha256OfString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /* ******************************************************* */
  /*  BUILD                                                  */
  /* ******************************************************* */
  @override
  Widget build(BuildContext context) {
    final colors = Theme
        .of(context)
        .colorScheme;
    final size = MediaQuery
        .of(context)
        .size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: _bannerReady
          ? SizedBox(
        height: _banner.size.height.toDouble(),
        child: AdWidget(ad: _banner),
      )
          : null,
      body: Stack(
        children: [
          // 1) Fond dégradé
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff002d74), Color(0xff4d75bc)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // 2) Blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.black.withOpacity(.2)),
          ),
          // 3) Contenu centré
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.05,
                  vertical: size.height * 0.05,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ─── TITRE
                    GradientText(
                      'BIENVENUE',
                      style: TextStyle(
                        fontSize: size.width * 0.10,
                        fontWeight: FontWeight.bold,
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade800,
                          Colors.blue.shade300,
                          Colors.blue.shade800,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),

                    SizedBox(height: size.height * 0.02),

                    GradientText(
                      'AI NEGI QUIZ VENTE PRO',
                      style: TextStyle(
                        fontSize: size.width * 0.05,
                        fontWeight: FontWeight.w600,
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade800,
                          Colors.blue.shade200,
                          Colors.blue.shade800,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),

                    SizedBox(height: size.height * 0.01),

                    // ─── CARTE DE LOGIN
                    Container(
                      width: size.width > 600 ? 500 : double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colors.surface.withOpacity(.75),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.25),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // … tout votre formulaire existant :
                          // SizedBox, TextFields, Checkbox, Buttons, etc.
                          const SizedBox(height: 12),
                          if (!_loginMode)
                            TextField(
                              controller: _name,
                              textCapitalization: TextCapitalization.words,
                              decoration: _dec('Nom'.tr()),
                            ),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _dec('Email'.tr()),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _pass,
                            obscureText: _obscure,
                            decoration: _dec(
                              'Mot de passe'.tr(),
                              icon: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility : Icons
                                      .visibility_off,
                                  color: colors.primary,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Checkbox(
                                value: _remember,
                                activeColor: colors.primary,
                                onChanged: (v) =>
                                    setState(() => _remember = v!),
                              ),
                              Text('Se souvenir de moi'.tr()),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(_loginMode ? Icons.login : Icons
                                .person_add_alt_1),
                            label: Text(
                                _loginMode ? 'Se connecter'.tr() : 'S’inscrire'
                                    .tr()),
                            onPressed: _loginMode ? _signInMail : _signUpMail,
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _loginMode = !_loginMode),
                            child: Text(_loginMode
                                ? 'Créer un compte'
                                : 'Déjà inscrit ? Connectez-vous').tr(),
                          ),
                          const Divider(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.black,
                              backgroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: SvgPicture.asset(
                                'assets/icons/Google.svg', height: 22),
                            label: const Text('Google'),
                            onPressed: _google,
                          ),
                          if (Platform.isIOS)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: SvgPicture.asset(
                                  'assets/icons/Apple-logo-icon.svg',
                                  height: 24,
                                  colorFilter: const ColorFilter.mode(
                                      Colors.white, BlendMode.srcIn),
                                ),
                                label: const Text('Apple',
                                    style: TextStyle(color: Colors.white)),
                                onPressed: _apple,
                              ),
                            ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.videogame_asset),
                            label: const Text('Continuer en invité'),
                            onPressed: _guest,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '© 2025 AI-Nego  •  RGPD ready',
                            style: Theme
                                .of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colors.outline),
                          ),
                        ],
                      ),
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
