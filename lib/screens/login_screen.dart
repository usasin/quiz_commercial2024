import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loginAsGuest();
  }

  Future<void> _loginAsGuest() async {
    try {
      final result = await _auth.signInAnonymously();
      await _ensureUserDoc(result.user!);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/chapter_menu');
    } catch (e) {
      print('❌ Erreur connexion invité : $e');
      // Affiche quand même une UI simple si ça échoue
    }
  }

  Future<void> _ensureUserDoc(User u) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final snap = await ref.get();

    await ref.set({
      'name': 'Invité',
      'email': '',
      'photoURL': '',
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

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await ref.set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

                  
