import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatelessWidget {
  Future<void> _guestLogin(BuildContext context) async {
    try {
      final res = await FirebaseAuth.instance.signInAnonymously();
      final user = res.user;
      if (user != null) {
        final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await ref.set({'createdAt': DateTime.now()}, SetOptions(merge: true));
        Navigator.pushReplacementNamed(context, '/chapter_menu');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Connexion')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: () => _guestLogin(context),
          icon: Icon(Icons.person),
          label: Text("Continuer en invité"),
        ),
      ),
    );
  }
}
