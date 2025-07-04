// lib/screens/login_screen.dart
// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/*──────────────────────────────────────────────────────────*/

class _LoginScreenState extends State<LoginScreen> {
  /* ---- controllers & services ---- */
  final _auth  = FirebaseAuth.instance;
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  final _name  = TextEditingController();

  /* ---- UI states ---- */
  bool _obscure    = true;
  bool _remember   = false;
  bool _loginMode  = true; // true = connexion, false = inscription

  /* ───────────────── Firebase util ───────────────── */

  Future<void> _ensureUserDoc(User u, {String? displayName}) async {
    final ref  = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final snap = await ref.get();

    await ref.set({
      'name'     : displayName ?? u.displayName ?? 'Invité',
      'email'    : u.email ?? '',
      'photoURL' : u.photoURL ?? '',
    }, SetOptions(merge: true));

    if (!snap.exists) {
      await ref.set({
        'createdAt'      : FieldValue.serverTimestamp(),
        'totalScore'     : 0,
        'chapters'       : {},
        'unlockedLevels' : {},
      }, SetOptions(merge: true));
    }

    // token FCM (facultatif : commente si tu n’utilises plus FCM)
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await ref.set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  /* ───────────────── Helpers ───────────────── */

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  InputDecoration _dec(String label, {Widget? icon}) =>
      InputDecoration(labelText: label, suffixIcon: icon);

  Future<void> _loginEmail() async {
    if (_email.text.isEmpty || _pass.text.isEmpty) return;
    try {
      await _auth.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
      await _ensureUserDoc(_auth.currentUser!);

      if (_remember) {
        final p = await SharedPreferences.getInstance();
        p
          ..setString('email', _email.text)
          ..setString('password', _pass.text)
          ..setBool('rememberMe', true);
      }
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Erreur de connexion');
    }
  }

  Future<void> _signupEmail() async {
    if ([_name.text, _email.text, _pass.text].any((v) => v.isEmpty)) return;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
      await _ensureUserDoc(cred.user!, displayName: _name.text.trim());
      _snack('Inscription réussie, connectez-vous 👍');
      setState(() {
        _loginMode = true;
        _pass.clear();
      });
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Erreur inscription');
    }
  }

  Future<void> _guest() async {
    try {
      final res = await _auth.signInAnonymously();
      await _ensureUserDoc(res.user!, displayName: 'Invité');
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Erreur invité');
    }
  }

  /* ───────────────── Build ───────────────── */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loginMode ? 'Connexion' : 'Créer un compte',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
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
                    icon: Icon(_obscure ? Icons.visibility :
                                               Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),

              Row(
                children: [
                  Checkbox(
                    value: _remember,
                    onChanged: (v) => setState(() => _remember = v!),
                  ),
                  const Text('Se souvenir de moi'),
                ],
              ),
              const SizedBox(height: 8),

              ElevatedButton.icon(
                icon: Icon(_loginMode ? Icons.login : Icons.person_add),
                label: Text(_loginMode ? 'Se connecter' : 'S’inscrire'),
                onPressed: _loginMode ? _loginEmail : _signupEmail,
              ),
              TextButton(
                onPressed: () => setState(() => _loginMode = !_loginMode),
                child: Text(_loginMode
                    ? 'Créer un compte'
                    : 'Déjà inscrit ? Connexion'),
              ),

              const Divider(height: 32),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
                icon: const Icon(Icons.videogame_asset),
                label: const Text('Continuer en invité'),
                onPressed: _guest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
