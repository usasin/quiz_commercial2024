// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point') // requis pour iOS/Android release
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage msg) async {
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    }
  }
  _showLocalNotification(msg);
}

void _showLocalNotification(RemoteMessage msg) {
  final notif = msg.notification;
  if (notif == null) return;

  const androidDetails = AndroidNotificationDetails(
    'invites_channel',
    'Invitations',
    channelDescription: 'Canal des invitations',
    importance: Importance.max,
    priority: Priority.high,
  );
  const iosDetails = DarwinNotificationDetails();

  _localNotif.show(
    notif.hashCode,
    notif.title,
    notif.body,
    const NotificationDetails(android: androidDetails, iOS: iosDetails),
    payload: msg.data['challengeId'],
  );
}

void _handleMessageOpenedApp(RemoteMessage msg) {
  final data = msg.data;
  navigatorKey.currentState?.pushNamed(
    '/challenge-lobby',
    arguments: {
      'isCreator': false,
      'challengeId': data['challengeId'],
      'levelId': data['levelId'],
      'chapterId': data['chapterId'],
    },
  );
}

void _handleNotificationResponse(NotificationResponse resp) {
  final payload = resp.payload;
  if (payload != null && payload.isNotEmpty) {
    navigatorKey.currentState?.pushNamed(
      '/challenge-lobby',
      arguments: {
        'isCreator': false,
        'challengeId': payload,
      },
    );
  }
}

Future<void> _safeLoadDotEnv() async {
  try {
    // On ne plante pas si le fichier n’est pas packagé dans l’IPA
    await rootBundle.loadString('.env');
    await dotenv.load(fileName: '.env');
  } catch (_) {/* ignore missing .env */}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Localisation – on ne fait pas échouer l’app si les assets manquent
  await EasyLocalization.ensureInitialized();

  // 2) DotEnv – tolérant à l’absence du fichier
  await _safeLoadDotEnv();

  // 3) Firebase
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  // 4) Notifs locales
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await _localNotif.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
    onDidReceiveNotificationResponse: _handleNotificationResponse,
  );

  // 5) Canal Android (no-op sur iOS)
  const channel = AndroidNotificationChannel(
    'invites_channel',
    'Invitations',
    description: 'Canal pour les invitations de défi',
    importance: Importance.high,
  );
  final androidImpl =
      _localNotif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidImpl?.createNotificationChannel(channel);

  // 6) FCM permissions & options
  await FirebaseMessaging.instance.requestPermission();
  if (Platform.isIOS) {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );
  }
  if (Platform.isAndroid) {
    await Permission.notification.request();
  }

  // 7) Handlers FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen(_showLocalNotification);
  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

  // 8) Mobile Ads (ne fait pas échouer l’app s’il y a un souci)
  try { await MobileAds.instance.initialize(); } catch (_) {}

  // 9) Token FCM → Firestore (safe)
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      final fcm = FirebaseMessaging.instance;
      final token = await fcm.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }
      await fcm.subscribeToTopic('app_updates');
    }
  });

  // 10) Démarrage de l’app
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fr')],
      path: 'assets/translations', // doit exister, sinon fallback en EN
      fallbackLocale: const Locale('en'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).currentTheme;

    return ScreenUtilInit(
      designSize: const Size(414, 896),
      builder: (_, __) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Quiz Commercial',
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        initialRoute: '/login',
        routes: {
          '/login': (_) => const LoginScreen(),
          '/chapter_menu': (_) => ChapterMenuPage(),
          '/challenge-menu': (_) => const ChallengeHomeMenu(),
          '/levels': (_) => const LevelsPage(),
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
            // 🔒 Protège contre des arguments absents/mal typés
            final args = (ModalRoute.of(ctx)?.settings.arguments
                    as Map<String, dynamic>?) ??
                const {};
            return ChallengeLobby(
              isCreator: (args['isCreator'] as bool?) ?? false,
              challengeId: (args['challengeId'] as String?) ?? '',
              levelId: (args['levelId'] as String?) ?? '',
              chapterId: (args['chapterId'] as String?) ?? '',
            );
          },
        },
      ),
    );
  }
}
