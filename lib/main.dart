
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/login_screen.dart';
import 'screens/chapter_menu_page.dart';
import 'firebase_options.dart'; // Assure-toi qu’il existe

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz Commercial',
      debugShowCheckedModeBanner: false,
      initialRoute: FirebaseAuth.instance.currentUser == null
          ? '/login'
          : '/chapter_menu',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/chapter_menu': (context) => const ChapterMenuPage(),
      },
    );
  }
}
