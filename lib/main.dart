// lib/main.dart
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'firebase_options.dart';
import 'theme_provider.dart';

/* ---------- tes écrans ---------- */
import 'screens/login_screen.dart';
import 'screens/chapter_menu_page.dart';
import 'challenge_screen/challenge_home_menu.dart';
import 'screens/levels_page.dart';
import 'screens/lessons_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/simulation.dart';
import 'screens/compte_rendu_screen.dart';
import 'screens/profile_page.dart';
import 'screens/settings_screen.dart';
import 'screens/about_screen.dart';
import 'screens/information_screen.dart';
import 'leaderboard_page.dart';
import 'challenge_screen/challenge_lobby.dart';

final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // variables d’environnement (.env)
  await dotenv.load(fileName: '.env');

  // Firebase minimal (Auth / Firestore / Storage…)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Easy-Localization (si tu ne l’utilises plus, retire complètement ces 3 lignes)
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fr')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const _App(),
      ),
    ),
  );
}

/* ─────────────── ROOT ─────────────── */

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;

    return ScreenUtilInit(
      designSize: const Size(414, 896),
      builder: (_, __) => MaterialApp(
        navigatorKey: _navKey,
        debugShowCheckedModeBanner: false,
        title: 'Quiz Commercial',
        theme: theme,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        initialRoute: '/login',

        // toutes tes routes inchangées
        routes: {
          '/login'          : (_) => const LoginScreen(),
          '/chapter_menu'   : (_) => ChapterMenuPage(),
          '/challenge-menu' : (_) => const ChallengeHomeMenu(),
          '/levels'         : (_) => const LevelsPage(),
          '/lessons'        : (_) => LessonsScreen(),
          '/quiz'           : (_) => QuizScreen(
                                level: 1,
                                chapterId: 'chapters1',
                                onLevelCompleted: () {},
                              ),
          '/simulation'     : (_) => SimulationScreen(chapterId: 'chapters1'),
          '/compt_rendu'    : (_) => CompteRenduScreen(chapterId: 'chapters1'),
          '/profile'        : (_) => ProfilePage(),
          '/leaderboard'    : (_) => LeaderboardPage(),
          '/settings'       : (_) => SettingsScreen(),
          '/about'          : (_) => AboutScreen(),
          '/information'    : (_) => InformationScreen(),
          '/challenge-lobby': (ctx) {
            final args = ModalRoute.of(ctx)!.settings.arguments
                as Map<String, dynamic>;
            return ChallengeLobby(
              isCreator : args['isCreator']  as bool,
              challengeId: args['challengeId'] as String,
              levelId   : args['levelId']    as String,
              chapterId : args['chapterId']  as String,
            );
          },
        },
      ),
    );
  }
}
