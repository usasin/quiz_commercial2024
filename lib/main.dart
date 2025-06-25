import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Pages
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp()); // NE PAS mettre const ici
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz Commercial',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (_) => LoginScreen(),
        '/chapter_menu': (_) => ChapterMenuPage(),
        '/challenge-menu': (_) => ChallengeHomeMenu(),
        '/levels': (_) => LevelsPage(),
        '/lessons': (_) => LessonsScreen(),
        '/quiz': (_) => QuizScreen(
              level: 1,
              chapterId: 'chapters1',
              onLevelCompleted: () {},
            ),
        '/simulation': (_) => SimulationScreen(chapterId: 'chapters1'),
        '/compt_rendu': (_) => CompteRenduScreen(chapterId: 'chapters1'),
        '/profile': (_) => ProfilePage(),
        '/leaderboard': (_) => LeaderboardPage(),
        '/settings': (_) => SettingsScreen(),
        '/about': (_) => AboutScreen(),
        '/information': (_) => InformationScreen(),
        '/challenge-lobby': (ctx) {
          final args = ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>;
          return ChallengeLobby(
            isCreator: args['isCreator'] as bool,
            challengeId: args['challengeId'] as String,
            levelId: args['levelId'] as String,
            chapterId: args['chapterId'] as String,
          );
        },
      },
    );
  }
}
