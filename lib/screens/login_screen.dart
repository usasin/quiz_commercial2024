// lib/screens/login_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'chapter_menu_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth  = FirebaseAuth.instance;
  final _mail  = TextEditingController();
  final _pass  = TextEditingController();
  final _name  = TextEditingController();

  bool _obscure   = true;
  bool _loginMode = true;   // false = sign-up

  /* ───────── Firestore helper ───────── */
  Future<void> _saveUser(User u, String pseudo) async {
    await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
      'name'      : pseudo,
      'name_lower': pseudo.toLowerCase(),
      'email'     : u.email ?? '',
    }, SetOptions(merge: true));

    final fcm = await FirebaseMessaging.instance.getToken();
    if (fcm != null) {
      FirebaseFirestore.instance
          .collection('users').doc(u.uid)
          .set({'fcmToken': fcm}, SetOptions(merge: true));
    }
  }

  /* ───────── Dialog pseudo invité ───────── */
  Future<String?> _askPseudo() async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Choisis un pseudo'),
        content: TextField(controller: c, autofocus: true, maxLength: 20),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final n = c.text.trim();
              if (n.length < 3) return;
              Navigator.pop(context, n);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /* ───────── Auth flows ───────── */
  Future<void> _signIn() async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: _mail.text.trim(),
        password: _pass.text,
      );
      await _saveUser(cred.user!, cred.user!.displayName ?? 'Joueur');
      _goHome();
    } on FirebaseAuthException catch (e) {
      _error(e.message);
    }
  }

  Future<void> _signUp() async {
    if (_name.text.trim().length < 3) return _error('Pseudo manquant');
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _mail.text.trim(),
        password: _pass.text,
      );
      await cred.user!.updateDisplayName(_name.text.trim());
      await _saveUser(cred.user!, _name.text.trim());
      _goHome();
    } on FirebaseAuthException catch (e) {
      _error(e.message);
    }
  }

  Future<void> _guest() async {
    final nick = _name.text.trim().isNotEmpty ? _name.text.trim() : await _askPseudo();
    if (nick == null) return;
    final cred = await _auth.signInAnonymously();
    await _saveUser(cred.user!, nick);
    _goHome();
  }

  /* ───────── Navigation ───────── */
  void _goHome() {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => ChapterMenuPage()),
      (_) => false,
    );
  }

  /* ───────── UI helpers ───────── */
  void _error(String? m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m ?? 'Erreur')));

  InputDecoration _dec(String l) =>
      InputDecoration(labelText: l, border: const OutlineInputBorder());

  /* ───────── Build ───────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loginMode ? 'Connexion' : 'Inscription',
                  style: const TextStyle(fontSize: 28,fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              if (!_loginMode)
                TextField(controller: _name, decoration: _dec('Pseudo')),
              const SizedBox(height: 12),

              TextField(controller: _mail, decoration: _dec('Email')),
              const SizedBox(height: 12),

              TextField(
                controller: _pass,
                obscureText: _obscure,
                decoration: _dec('Mot de passe').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(()=>_obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _loginMode ? _signIn : _signUp,
                child: Text(_loginMode ? 'Se connecter' : 'Créer le compte'),
              ),
              TextButton(
                onPressed: () => setState(()=> _loginMode = !_loginMode),
                child: Text(_loginMode ? 'Créer un compte' : 'Déjà inscrit ? Connexion'),
              ),
              const Divider(height: 30),
              ElevatedButton.icon(
                onPressed: _guest,
                icon: const Icon(Icons.videogame_asset),
                label: const Text('Continuer en invité'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
