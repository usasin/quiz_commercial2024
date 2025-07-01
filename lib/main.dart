// main.dart — léger mais avec FCM + notifications locales
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'theme_provider.dart';
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

/* ───────────────────  NOTIFICATIONS  ─────────────────── */

final _navKey = GlobalKey<NavigatorState>();
final _localNotif = FlutterLocalNotificationsPlugin();

Future<void> _showLocal(RemoteMessage msg) async {
  final n = msg.notification; if (n == null) return;
  const android = AndroidNotificationDetails(
    'invites_channel', 'Invitations',
    channelDescription: 'Canal des invitations',
    importance: Importance.max, priority: Priority.high);
  const ios = DarwinNotificationDetails();
  await _localNotif.show(
    n.hashCode, n.title, n.body,
    const NotificationDetails(android: android, iOS: ios),
    payload: msg.data['challengeId'],
  );
}

Future<void> _bgHandler(RemoteMessage msg) async {
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
  await _showLocal(msg);
}

void _onForeground(RemoteMessage msg) => _showLocal(msg);

void _onOpened(RemoteMessage msg) {
  final d = msg.data;
  _navKey.currentState?.pushNamed('/challenge-lobby', arguments: {
    'isCreator': false,
    'challengeId': d['challengeId'],
    'levelId'   : d['levelId'],
    'chapterId' : d['chapterId'],
  });
}

void _onLocalTap(NotificationResponse resp) {
  if (resp.payload == null) return;
  _navKey.currentState?.pushNamed('/challenge-lobby', arguments: {
    'isCreator': false,
    'challengeId': resp.payload,
  });
}

/* ───────────────────  MAIN  ─────────────────── */

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);

  await MobileAds.instance.initialize();

  // FCM permission
  await FirebaseMessaging.instance.requestPermission();
  if (Platform.isAndroid && await FirebaseMessaging.instance.isSupported()) {
    // Android 13 : runtime permission
    await FirebaseMessaging.instance.requestPermission();
  }

  // flutter_local_notifications init
  const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initIOS    = DarwinInitializationSettings();
  await _localNotif.initialize(
    const InitializationSettings(android: initAndroid, iOS: initIOS),
    onDidReceiveNotificationResponse: _onLocalTap,
  );

  // Android channel (must exist before first notif)
  const channel = AndroidNotificationChannel(
    'invites_channel', 'Invitations',
    description: 'Canal des invitations', importance: Importance.high);
  await _localNotif
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // FCM handlers
  FirebaseMessaging.onBackgroundMessage(_bgHandler);
  FirebaseMessaging.onMessage.listen(_onForeground);
  FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);

  // Sauvegarde du token dès connexion
  FirebaseAuth.instance.authStateChanges().listen((u) async {
    if (u == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }
  });

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const _App(),
    ),
  );
}

/* ───────────────────  ROOT  ─────────────────── */

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;

    return MaterialApp(
      navigatorKey: _navKey,
      debugShowCheckedModeBanner: false,
      title: 'Quiz Commercial',
      theme: theme,
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/chapter_menu': (_) => ChapterMenuPage(),
        '/challenge-menu': (_) => const ChallengeHomeMenu(),
        '/levels': (_) => const LevelsPage(),
        '/lessons': (_) => LessonsScreen(),
        '/quiz': (_) => QuizScreen(
              level: 1, chapterId: 'chapters1', onLevelCompleted: () {}),
        '/simulation': (_) => SimulationScreen(chapterId: 'chapters1'),
        '/compt_rendu': (_) =>
            CompteRenduScreen(chapterId: 'chapters1'),
        '/profile': (_) => ProfilePage(),
        '/leaderboard': (_) => LeaderboardPage(),
        '/settings': (_) => SettingsScreen(),
        '/about': (_) => AboutScreen(),
        '/information': (_) => InformationScreen(),
        '/challenge-lobby': (ctx) {
          final a = ModalRoute.of(ctx)!.settings.arguments
              as Map<String, dynamic>;
          return ChallengeLobby(
            isCreator : a['isCreator'] as bool,
            challengeId: a['challengeId'] as String,
            levelId   : a['levelId'] as String? ?? '',
            chapterId : a['chapterId'] as String? ?? '',
          );
        },
      },
    );
  }
}
