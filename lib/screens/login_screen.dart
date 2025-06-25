import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || (!_isLogin && _nameController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez remplir tous les champs.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential;

      if (_isLogin) {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = userCredential.user;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'name': _nameController.text.trim(),
            'email': user.email,
            'createdAt': FieldValue.serverTimestamp(),
            'chapters': {},
            'totalScore': 0,
          });
        }
      }

      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : ${e.message}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Connexion' : 'Inscription')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (!_isLogin)
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nom'),
                  ),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mot de passe'),
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _handleAuth,
                        child: Text(_isLogin ? 'Se connecter' : 'S\'inscrire'),
                      ),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin
                      ? 'Créer un compte'
                      : 'Déjà un compte ? Connectez-vous'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

