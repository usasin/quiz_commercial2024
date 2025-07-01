// login_screen.dart — version light (e-mail + invité uniquement) 2025
// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ad_manager.dart';

/*───────────────────────────────────────────────────────────*/

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /* ------------- Firebase ------------- */
  final _auth = FirebaseAuth.instance;
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  final _name  = TextEditingController();

  /* ------------- UI states ------------- */
  bool _obscure   = true;
  bool _remember  = false;
  bool _loginMode = true;         // true = connexion, false = inscription

  /* ------------- Ad banner ------------- */
  late final BannerAd _banner;
  bool _bannerReady = false;

  /* ******************************************************* */
  /*  INIT / DISPOSE                                         */
  /* ******************************************************* */
  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _initBanner();

    // Redirige seulement si l’utilisateur est connecté ET non-anonyme
    final u = _auth.currentUser;
    if (u != null && !u.isAnonymous) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.pushReplacementNamed(context, '/chapter_menu'),
      );
    }
  }

  void _initBanner() {
    _banner = BannerAd(
      adUnitId : AdManager.bannerAdUnitId,
      size     : AdSize.banner,
      request  : const AdRequest(),
      listener : BannerAdListener(
        onAdLoaded    : (_) => setState(() => _bannerReady = true),
        onAdFailedToLoad: (ad, err) => ad.dispose(),
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

  /* ******************************************************* */
  /*  PREFERENCES                                            */
  /* ******************************************************* */
  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _email.text = p.getString('email')      ?? '';
      _pass.text  = p.getString('password')   ?? '';
      _remember   = p.getBool('rememberMe')   ?? false;
    });
  }

  Future<void> _savePrefs() async {
    if (!_remember) return;
    final p = await SharedPreferences.getInstance();
    p
      ..setString('email', _email.text)
      ..setString('password', _pass.text)
      ..setBool('rememberMe', true);
  }

  /* ******************************************************* */
  /*  FIRESTORE helper                                       */
  /* ******************************************************* */
  Future<void> _ensureUserDoc(User u, {String? displayName}) async {
    final ref  = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final snap = await ref.get();

    await ref.set({
      'name'    : displayName ?? u.displayName ?? 'Invité',
      'email'   : u.email ?? '',
      'photoURL': u.photoURL ?? '',
    }, SetOptions(merge: true));

    if (!snap.exists) {
      await ref.set({
        'createdAt'      : FieldValue.serverTimestamp(),
        'totalScore'     : 0,
        'unlockedLevels' : {},
        'unlockedModules': {},
        'scrollPositions': {},
        'lastChapterId'  : '',
        'chapters'       : {},
      }, SetOptions(merge: true));
    }

    final fcm = await FirebaseMessaging.instance.getToken();
    if (fcm != null) ref.set({'fcmToken': fcm}, SetOptions(merge: true));
  }

  /* ******************************************************* */
  /*  AUTH flows                                             */
  /* ******************************************************* */
  Future<void> _signInMail() async {
    if (_email.text.isEmpty || _pass.text.isEmpty) return;
    try {
      await _auth.signInWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text);
      await _savePrefs();
      await _ensureUserDoc(_auth.currentUser!);
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Erreur de connexion');
    }
  }

  Future<void> _signUpMail() async {
    if ([_name.text, _email.text, _pass.text].any((e) => e.isEmpty)) return;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text);
      await _ensureUserDoc(cred.user!, displayName: _name.text.trim());
      _snack('Inscription réussie 🎉 Connecte-toi maintenant.');
      setState(() { _loginMode = true; _pass.clear(); });
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Erreur d’inscription');
    }
  }

  Future<void> _guest() async {
    try {
      final res = await _auth.signInAnonymously();
      await _ensureUserDoc(res.user!, displayName: 'Invité');
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } on FirebaseAuthException catch (e) {
      _snack('Invité : ${e.message}');
    }
  }

  /* ******************************************************* */
  /*  UI helpers                                             */
  /* ******************************************************* */
  void _snack(String m) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  InputDecoration _dec(String label, {Widget? icon}) => InputDecoration(
        labelText: label,
        border   : const UnderlineInputBorder(),
        suffixIcon: icon,
      );

  /* ******************************************************* */
  /*  BUILD                                                  */
  /* ******************************************************* */
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: _bannerReady
          ? SizedBox(height: _banner.size.height.toDouble(), child: AdWidget(ad: _banner))
          : null,
      body: Stack(
        children: [
          // Fond dégradé + flou
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff002d74), Color(0xff005ee0)],
                begin : Alignment.topLeft,
                end   : Alignment.bottomRight,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child : Container(color: Colors.black.withOpacity(.20)),
          ),

          // Carte centrale
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child  : _buildCard(colors),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color        : colors.surface.withOpacity(.80),
        borderRadius : BorderRadius.circular(26),
        boxShadow    : [BoxShadow(color: Colors.black26, blurRadius: 28, offset: const Offset(0, 12))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(
            _loginMode ? 'Bienvenue' : 'Créer un compte',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),

          if (!_loginMode)
            TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: _dec('Nom')),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: _dec('E-mail')),
          const SizedBox(height: 14),
          TextField(
            controller : _pass,
            obscureText: _obscure,
            decoration : _dec(
              'Mot de passe',
              icon: IconButton(
                icon : Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: colors.primary),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),

          const SizedBox(height: 6),
          Row(children: [
            Checkbox(value: _remember, activeColor: colors.primary, onChanged: (v) => setState(() => _remember = v!)),
            const Text('Se souvenir de moi'),
          ]),
          const SizedBox(height: 4),
          ElevatedButton.icon(
            style : ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape     : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon  : Icon(_loginMode ? Icons.login : Icons.person_add_alt_1),
            label : Text(_loginMode ? 'Se connecter' : 'S’inscrire'),
            onPressed: _loginMode ? _signInMail : _signUpMail,
          ),
          TextButton(
            onPressed: () => setState(() => _loginMode = !_loginMode),
            child   : Text(_loginMode ? 'Créer un compte' : 'Déjà inscrit ? Connectez-vous'),
          ),

          const Divider(height: 24),

          ElevatedButton.icon(
            style : ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              minimumSize    : const Size.fromHeight(48),
              shape          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon : const Icon(Icons.videogame_asset),
            label: const Text('Continuer en invité'),
            onPressed: _guest,
          ),

          const SizedBox(height: 18),
          Text('© 2025 AI-Nego  •  RGPD ready',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.outline)),
        ],
      ),
    );
  }
}
