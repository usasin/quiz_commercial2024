import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'screens/compte_rendu_screen.dart';
import 'theme_provider.dart'; // Assurez-vous d'importer le ThemeProvider ici
import 'leaderboard_page.dart';
import 'screens/about_screen.dart';
import 'screens/information_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_page.dart';
import 'screens/quiz_screen.dart';
import 'screens/levels_page.dart';
import 'screens/lessons_screen.dart';
import 'screens/settings_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await EasyLocalization.ensureInitialized();
  testFirebaseServices(); // Appel du test après l'initialisation de Firebase
  runApp(
    EasyLocalization(
      supportedLocales: [Locale('en'), Locale('fr')],
      path: 'assets/translations', // Ajustez selon votre structure de dossiers
      fallbackLocale: Locale('en'),
      child: MyApp(),
    ),
  );
}

void testFirebaseServices() async {
  try {
    UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
    print("User signed in: ${userCredential.user?.uid}");

    CollectionReference users = FirebaseFirestore.instance.collection('users');
    users.add({'username': 'test'}).then((value) => print("User Added")).catchError((error) => print("Failed to add user: $error"));
  } catch (e) {
    print("Error: $e");
  }
}

class LanguageProvider with ChangeNotifier {
  Locale _currentLocale = const Locale('en');

  Locale get currentLocale => _currentLocale;

  void changeLocale(Locale locale) {
    _currentLocale = locale;
    notifyListeners();
  }
}

String obtenirCollectionIdPourChapitre(int chapter) {
  // Logic to determine the collection id for chapters
  if (chapter == 1) {
    return 'chapters1';
  } else if (chapter == 2) {
    return 'chapters2';
  } else {
    return 'chapters'; // Example logic, modify as needed
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()), // Fournir le ThemeProvider ici
      ],
      child: Consumer2<LanguageProvider, ThemeProvider>(
        builder: (context, lang, themeProvider, _) => ScreenUtilInit(
          designSize: const Size(414, 896),
          builder: (context, _) => MaterialApp(
            title: 'Flutter Demo',
            theme: themeProvider.currentTheme, // Utiliser le thème actuel fourni par ThemeProvider
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            initialRoute: '/login',
            routes: {
              '/login': (context) => LoginScreen(),
              '/quiz': (context) => QuizScreen(
                level: 1,
                chapterId: obtenirCollectionIdPourChapitre(1), // Updated logic
                onLevelCompleted: () {},
              ),
              '/levels': (context) => LevelsPage(),
              '/lessons': (context) => LessonsScreen(),
              '/settings': (context) => SettingsScreen(),
              '/profile': (context) => ProfilePage(),
              '/leaderboard': (context) => LeaderboardPage(),
              '/about': (context) => AboutScreen(),
              '/information': (context) => InformationScreen(),
              '/compt_rendu': (context) => CompteRenduScreen(
                chapterId: 'defaultChapterId', // Remplacez par une valeur par défaut ou obtenue dynamiquement
              ),

            },
          ),
        ),
      ),
    );
  }
}
