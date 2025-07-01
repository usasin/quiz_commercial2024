// login_screen.dart — 2025, e-mail + mode invité uniquement
// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ad_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /* Firebase & contrôleurs */
  final _auth = FirebaseAuth.instance;
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  final _name  = TextEditingController();

  /* UI state */
  bool _obscure = true;
  bool _remember = false;
  bool _loginMode = true;

  /* Publicité */
  late final BannerAd _banner;
  bool _bannerReady = false;

  /* ─────────────────── INIT / DISPOSE ─────────────────── */
  @override
  void initState() {
    super.initState();
    _loadSavedCreds();
    _initBanner();
    if (_auth.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.pushReplacementNamed(context, '/chapter_menu'));
    }
  }

  void _initBanner() {
    _banner = BannerAd(
      adUnitId: AdManager.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _bannerReady = true),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  @override
  void dispose() {
    _banner.dispose();
    _email.dispose();
    _pass.dispose();
    _name.dispose();
    super.dispose();
  }

  /* ─────────────────── PREFERENCES ─────────────────── */
  Future<void> _loadSavedCreds() async {
    final p = await SharedPreferences.getInstance();
    _email.text   = p.getString('email') ?? '';
    _pass.text    = p.getString('password') ?? '';
    _remember     = p.getBool('rememberMe') ?? false;
    setState(() {});
  }

  Future<void> _saveCreds() async {
    if (!_remember) return;
    final p = await SharedPreferences.getInstance();
    p
      ..setString('email', _email.text)
      ..setString('password', _pass.text)
      ..setBool('rememberMe', true);
  }

  /* ─────────────────── FIRESTORE helper ─────────────────── */
  Future<void> _ensureUserDoc(User u, {String? displayName}) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final snap = await ref.get();

    await ref.set({
      'name' : displayName ?? u.displayName ?? 'Invité',
      'email': u.email ?? '',
      'photoURL': u.photoURL ?? '',
    }, SetOptions(merge: true));

    if (!snap.exists) {
      await ref.set({
        'createdAt'       : FieldValue.serverTimestamp(),
        'totalScore'      : 0,
        'unlockedLevels'  : {},
        'unlockedModules' : {},
        'chapters'        : {},
        'scrollPositions' : {},
        'lastChapterId'   : '',
      }, SetOptions(merge: true));
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      ref.set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  /* ─────────────────── AUTH  ─────────────────── */
  Future<void> _signInMail() async {
    if (_email.text.isEmpty || _pass.text.isEmpty) return;
    try {
      await _auth.signInWithEmailAndPassword(
          email: _email.text, password: _pass.text);
      await _saveCreds();
      await _ensureUserDoc(_auth.currentUser!);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/chapter_menu');
      }
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
      _snack('Inscription réussie 👍');
      setState(() {
        _loginMode = true;
        _pass.clear();
      });
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Erreur signup');
    }
  }

  Future<void> _guest() async {
    try {
      final res = await _auth.signInAnonymously();
      await _ensureUserDoc(res.user!, displayName: 'Invité');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/chapter_menu');
      }
    } on FirebaseAuthException catch (e) {
      _snack('Invité : ${e.message}');
    }
  }

  /* ─────────────────── UI HELPERS ─────────────────── */
  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  InputDecoration _dec(String label, {Widget? icon}) => InputDecoration(
        labelText: label,
        border: const UnderlineInputBorder(),
        suffixIcon: icon,
      );

  /* ─────────────────── BUILD ─────────────────── */
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: _bannerReady
          ? SizedBox(height: _banner.size.height.toDouble(),
              child: AdWidget(ad: _banner))
          : null,
      body: Stack(
        children: [
          // fond dégradé + flou
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff002d74), Color(0xff005ee0)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.black.withOpacity(.20)),
          ),

          // carte
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.surface.withOpacity(.75),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.25),
                      blurRadius: 30,
                      offset: const Offset(0, 14)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Text(_loginMode ? 'Bienvenue'.tr() : 'Créer un compte'.tr(),
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 24),

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
                              _obscure ? Icons.visibility :
                                          Icons.visibility_off,
                              color: cs.primary),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),

                    // remember + action
                    const SizedBox(height: 6),
                    Row(children: [
                      Checkbox(
                        value: _remember,
                        activeColor: cs.primary,
                        onChanged: (v) => setState(() => _remember = v!),
                      ),
                      Text('Se souvenir de moi'.tr()),
                    ]),
                    const SizedBox(height: 4),
                    ElevatedButton.icon(
                      icon: Icon(_loginMode
                          ? Icons.login
                          : Icons.person_add_alt_1),
                      label: Text(_loginMode
                          ? 'Se connecter'.tr()
                          : 'S’inscrire'.tr()),
                      onPressed: _loginMode ? _signInMail : _signUpMail,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _loginMode = !_loginMode),
                      child: Text(_loginMode
                              ? 'Créer un compte'
                              : 'Déjà inscrit ? Connectez-vous')
                          .tr(),
                    ),

                    const Divider(height: 24),

                    // Invité
                    ElevatedButton.icon(
                      icon: const Icon(Icons.videogame_asset),
                      label: const Text('Continuer en invité'),
                      onPressed: _guest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 18),
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
