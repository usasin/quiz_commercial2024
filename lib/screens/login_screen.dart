// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _loginMode = true;          // true = connexion, false = inscription

  /* ---------- Firebase helpers ---------- */
  Future<void> _createOrUpdateUserDoc(User u, {String? name}) async {
    final ref  = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final snap = await ref.get();

    await ref.set({
      'name'          : name ?? u.displayName ?? 'Invité',
      'email'         : u.email ?? '',
      'photoURL'      : u.photoURL ?? '',
    }, SetOptions(merge: true));

    if (!snap.exists) {
      await ref.set({
        'createdAt'      : FieldValue.serverTimestamp(),
        'totalScore'     : 0,
        'chapters'       : {},        // scores détaillés
        'unlockedLevels' : {},
        'unlockedModules': {},
        'lastChapterId'  : '',
        'scrollPositions': {},
      }, SetOptions(merge: true));
    }
  }

  /* ---------- flows ---------- */
  Future<void> _signInEmail() async {
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
  }

  Future<void> _signUpEmail() async {
    if ([_name, _email, _pass].any((c) => c.text.isEmpty)) return;
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
  }

  Future<void> _guest() async {
    try {
      final res = await FirebaseAuth.instance.signInAnonymously();
      await _createOrUpdateUserDoc(res.user!, name: 'Invité');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } on FirebaseAuthException catch (e) {
      _snack('Invité : ${e.message}');
    }
  }

  /* ---------- UI helpers ---------- */
  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  InputDecoration _dec(String label, {Widget? icon}) => InputDecoration(
        labelText: label,
        suffixIcon: icon,
      );

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
              Text(_loginMode ? 'Connexion' : 'Créer un compte',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
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

              ElevatedButton.icon(
                icon: Icon(_loginMode ? Icons.login : Icons.person_add),
                label: Text(_loginMode ? 'Se connecter' : 'S’inscrire'),
                onPressed: _loginMode ? _signInEmail : _signUpEmail,
              ),
              TextButton(
                onPressed: () => setState(() => _loginMode = !_loginMode),
                child: Text(_loginMode
                    ? 'Créer un compte'
                    : 'Déjà inscrit ? Connexion'),
              ),
              const Divider(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
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
