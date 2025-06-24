import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Connexion Test',
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/chapter_menu': (context) => const ChapterMenu(),
      },
    );
  }
}

class ChapterMenu extends StatelessWidget {
  const ChapterMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu des chapitres')),
      body: const Center(
        child: Text('Connexion réussie ! Bienvenue.'),
      ),
    );
  }
}
