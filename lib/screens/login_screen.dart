// lib/login_simple.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginSimple extends StatelessWidget {
  const LoginSimple({Key? key}) : super(key: key);

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final user = (await FirebaseAuth.instance.signInWithCredential(credential)).user;

      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connexion Google réussie: ${user.displayName}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur Google: $e')));
    }
  }

  Future<void> _signInWithApple(BuildContext context) async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );

      final oauth = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final user = (await FirebaseAuth.instance.signInWithCredential(oauth)).user;

      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connexion Apple réussie: ${user.email}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur Apple: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Bienvenue', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _signInWithGoogle(context),
              child: const Text('Connexion Google'),
            ),
            if (Platform.isIOS)
              ElevatedButton(
                onPressed: () => _signInWithApple(context),
                child: const Text('Connexion Apple'),
              ),
          ],
        ),
      ),
    );
  }
}
