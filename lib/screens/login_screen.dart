import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_manager.dart';

import '../logo_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;

  bool _isObscured = true;
  bool _rememberMe = false;
  bool _isLoginMode = true;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
    _loadLoginInfo();
    _emailController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));

    // ───── Banner AdMob ─────
    _bannerAd = BannerAd(
      adUnitId: AdManager.bannerAdUnitId,
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdReady = true),
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          debugPrint('Erreur BannerAd LoginScreen: ${err.message}');
        },
      ),
    );
    _bannerAd.load();
  }


  Future<void> _saveFCMTokenToFirestore(String uid) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  void _changeLanguage(String languageCode) {
    context.setLocale(Locale(languageCode));
  }

  Future<void> _checkAuthenticationStatus() async {
    if (_auth.currentUser != null) {
      Navigator.pushNamed(context, '/chapter_menu');
    }
  }

  Future<void> _loadLoginInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailController.text = prefs.getString('email') ?? '';
      _passwordController.text = prefs.getString('password') ?? '';
      _rememberMe = prefs.getBool('rememberMe') ?? false;
    });
  }

  Future<void> _saveLoginInfo() async {
    final prefs = await SharedPreferences.getInstance();
    prefs
      ..setString('email', _emailController.text)
      ..setString('password', _passwordController.text)
      ..setBool('rememberMe', _rememberMe);
  }

  // ──────────────────────────────────────────────────────────── SIGN IN (EMAIL)
  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez remplir tous les champs.'.tr())));
      return;
    }

    try {
      if (_rememberMe) await _saveLoginInfo();

      await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final user = _auth.currentUser;
      if (user != null) {
        await _ensureUserDocument(user);
        await _saveFCMTokenToFirestore(user.uid);
        Navigator.pushNamed(context, '/chapter_menu');
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message!.tr())));
    }
  }

  // ───────────────────────────────────────────────────────────── SIGN UP
  Future<void> _signUp() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez remplir tous les champs.'.tr())));
      return;
    }

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      final user = userCredential.user;

      if (user != null) {
        await _ensureUserDocument(user, displayName: _nameController.text);
        await _saveFCMTokenToFirestore(user.uid);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Inscription réussie. Veuillez vous connecter.'.tr())));
        setState(() {
          _isLoginMode = true;
          _emailController.clear();
          _passwordController.clear();
          _nameController.clear();
        });
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Erreur lors de l\'inscription.'.tr())));
    }
  }

  // ───────────────────────────────────────────────────────── GOOGLE SIGN-IN
  Future<void> _signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // Annulation

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return;

      // Assure la présence (ou la mise à jour) du document utilisateur
      await _ensureUserDocument(user);

      // Stocke / met à jour le token FCM
      await _saveFCMTokenToFirestore(user.uid);

      Navigator.pushNamed(context, '/chapter_menu');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'.tr())));
    }
  }

  // ───────────────────────────────────────────────────────── UTILITAIRES
  Widget _buildLanguageSwitch(String langCode, String imagePath) {
    return InkWell(
      onTap: () => _changeLanguage(langCode),
      child: Container(
        margin: EdgeInsets.all(10.w),
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.5), blurRadius: 5)],
        ),
        child: Image.asset(imagePath, width: 28.w, height: 28.h),
      ),
    );
  }

  Future<void> _ensureUserDocument(User user, {String? displayName}) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap   = await docRef.get();

    // On merge les infos de base + la photo de profil
    await docRef.set({
      'name'      : displayName ?? user.displayName ?? 'Utilisateur',
      'name_lower': (displayName ?? user.displayName ?? 'Utilisateur').toLowerCase(),
      'email'     : user.email ?? '',
      'photoURL'  : user.photoURL ?? '',   // ← Ajouté pour stocker l'URL de l'avatar
    }, SetOptions(merge: true));

    if (!snap.exists) {
      await docRef.set({
        'createdAt'      : FieldValue.serverTimestamp(),
        'chapters'       : {},
        'totalScore'     : 0,
        'unlockedLevels' : {},
        'unlockedModules': {},
        'lastChapterId'  : '',
        'scrollPositions': {},
      }, SetOptions(merge: true));
    }
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────── UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Image.asset('assets/images/backgroundlogin.jpg',
              fit: BoxFit.cover, width: double.infinity, height: double.infinity),
          BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(color: Colors.black.withOpacity(0.3))),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LogoWidget(),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLanguageSwitch('fr', 'assets/images/france.png'),
                          _buildLanguageSwitch('en', 'assets/images/united-kingdom.png'),
                        ],
                      ),
                      Text(
                        _isLoginMode ? 'Bienvenue'.tr() : 'Créer un compte'.tr(),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      if (!_isLoginMode)
                        TextField(
                            controller: _nameController,
                            decoration: InputDecoration(labelText: 'Nom'.tr())),
                      TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                              labelText: 'Email'.tr(),
                              helperText: 'Exemple : utilisateur@domaine.com'.tr())),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: _isObscured,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe'.tr(),
                          helperText:
                          'Au moins 8 caractères, une majuscule, un chiffre.'.tr(),
                          suffixIcon: IconButton(
                            icon: Icon(_isObscured
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () =>
                                setState(() => _isObscured = !_isObscured),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Checkbox(
                              value: _rememberMe,
                              onChanged: (value) =>
                                  setState(() => _rememberMe = value!)),
                          Text('Se souvenir de moi'.tr()),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: Icon(_isLoginMode
                            ? Icons.login
                            : Icons.person_add,
                            color: Colors.teal),
                        label: Text(_isLoginMode
                            ? 'Se connecter'.tr()
                            : 'S\'inscrire'.tr()),
                        onPressed: _isLoginMode ? _signIn : _signUp,
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _isLoginMode = !_isLoginMode),
                        child: Text(_isLoginMode
                            ? 'Créer un compte'.tr()
                            : 'Déjà un compte ? Connectez-vous'.tr()),
                      ),
                      ElevatedButton.icon(
                        icon: SvgPicture.asset('assets/icons/Google.svg',
                            width: 24, height: 24),
                        label: Text('Connexion avec Google'.tr()),
                        onPressed: _signInWithGoogle,
                      ),

                      const SizedBox(height: 20),
                      Padding(
                        padding: EdgeInsets.only(bottom: 20.0.h),
                        child: Column(
                          children: [
                            Text('Tous droits réservés © 2023'.tr(),
                                style: TextStyle(fontSize: 12.sp)),
                            Text('Conforme au RGPD de l\'UE'.tr(),
                                style: TextStyle(fontSize: 12.sp)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: _isBannerAdReady
          ? SizedBox(
        width: _bannerAd.size.width.toDouble(),
        height: _bannerAd.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd),
      )
          : SizedBox.shrink(),
    );
  }
}
