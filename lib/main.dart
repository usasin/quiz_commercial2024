// lib/main.dart
import 'dart:io';
import 'dart:async';
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

@pragma('vm:entry-point')
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
    await rootBundle.loadString('.env');
    await dotenv.load(fileName: '.env');
  } catch (_) {/* ignore missing .env */}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On garde juste EasyLocalization avant runApp (rapide).
  await EasyLocalization.ensureInitialized();

  // >>> Affiche l'UI tout de suite
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fr')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => ThemeProvider())],
        child: const MyApp(),
      ),
    ),
  );

  // >>> Tout le reste en arrière-plan (ne pas await)
  // ignore: discarded_futures
  _bootstrap();
}

/// Initialisation asynchrone NON bloquante
Future<void> _bootstrap() async {
  // 1) DotEnv (tolérant)
  await _safeLoadDotEnv();

  // 2) Firebase (avec timeout de sécurité)
  try {
    await Firebase
        .initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 10));
  } on TimeoutException { /* continue avec valeurs par défaut */ }
    catch (e) { /* ne bloque pas le lancement */ }

  // 3) Notifs locales
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

  if (Platform.isAndroid) {
    const channel = AndroidNotificationChannel(
      'invites_channel',
      'Invitations',
      description: 'Canal pour les invitations de défi',
      importance: Importance.high,
    );
    final androidImpl = _localNotif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(channel);
  }

  // 4) FCM & permissions (APRES affichage de l’UI)
  try {
    await FirebaseMessaging.instance.requestPermission();
    if (Platform.isIOS) {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );
    } else {
      await Permission.notification.request();
    }
  } catch (_) {}

  // 5) Handlers FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen(_showLocalNotification);
  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

  // 6) Mobile Ads (tente mais ne bloque pas)
  try { await MobileAds.instance.initialize(); } catch (_) {}

  // 7) Token FCM -> Firestore
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      final fcm = FirebaseMessaging.instance;
      try {
        final token = await fcm.getToken();
        if (token != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'fcmToken': token}, SetOptions(merge: true));
        }
        await fcm.subscribeToTopic('app_updates');
      } catch (_) {}
    }
  });
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
          '/login': (_) => const LoginScreen(key: Key('home_screen')), // identifiant utile pour tests
          '/chapter_menu': (_) => ChapterMenuPage(),
          '/challenge-menu': (_) => const ChallengeHomeMenu(),
          '/levels': (_) => const LevelsPage(),
          '/lessons': (_) => LessonsScreen(),
          '/quiz': (_) => QuizScreen(level: 1, chapterId: 'chapters1', onLevelCompleted: () {}),
          '/simulation': (_) => SimulationScreen(chapterId: 'chapters1'),
          '/compt_rendu': (_) => CompteRenduScreen(chapterId: 'chapters1'),
          '/profile': (_) => ProfilePage(),
          '/leaderboard': (_) => LeaderboardPage(),
          '/settings': (_) => SettingsScreen(),
          '/about': (_) => AboutScreen(),
          '/information': (_) => InformationScreen(),
          '/challenge-lobby': (ctx) {
            final args = (ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?) ?? const {};
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
