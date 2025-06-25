import 'dart:io';
import 'package:flutter/material.dart';
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

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  _showLocalNotification(message);
}

void _showLocalNotification(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;

  const androidDetails = AndroidNotificationDetails(
    'invites_channel',
    'Invitations',
    channelDescription: 'Canal des invitations',
    importance: Importance.max,
    priority: Priority.high,
  );

  const iosDetails = DarwinNotificationDetails();

  _localNotif.show(
    notification.hashCode,
    notification.title,
    notification.body,
    const NotificationDetails(android: androidDetails, iOS: iosDetails),
    payload: message.data['challengeId'],
  );
}

void _handleMessageOpenedApp(RemoteMessage message) {
  final data = message.data;
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

void _handleNotificationResponse(NotificationResponse response) {
  final payload = response.payload;
  if (payload != null) {
    navigatorKey.currentState?.pushNamed(
      '/challenge-lobby',
      arguments: {
        'isCreator': false,
        'challengeId': payload,
      },
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await EasyLocalization.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await MobileAds.instance.initialize();

  if (Platform.isAndroid || Platform.isIOS) {
    await FirebaseMessaging.instance.requestPermission();
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
  }

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();

  await _localNotif.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
    onDidReceiveNotificationResponse: _handleNotificationResponse,
  );

  const channel = AndroidNotificationChannel(
    'invites_channel',
    'Invitations',
    description: 'Canal pour les invitations de défi',
    importance: Importance.high,
  );

  final androidImpl = _localNotif.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await androidImpl?.createNotificationChannel(channel);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen(_showLocalNotification);
  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }
      await FirebaseMessaging.instance.subscribeToTopic('app_updates');
    }
  });

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fr')],
      path: 'assets/translations',
      fallbackLocale: const Locale('fr'),
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
  MyApp({super.key}); // ⬅️ PAS const ici

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).currentTheme;
    return ScreenUtilInit(
      designSize: const Size(414, 896),
      builder: (_, __) => MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Quiz Commercial',
        theme: theme,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        initialRoute: '/login',
        routes: {
          '/login': (_) => LoginScreen(),
          '/chapter_menu': (_) => ChapterMenuPage(),
          '/challenge-menu': (_) => ChallengeHomeMenu(),
          '/levels': (_) => LevelsPage(),
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
            final args = ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>;
            return ChallengeLobby(
              isCreator: args['isCreator'] as bool,
              challengeId: args['challengeId'] as String,
              levelId: args['levelId'] as String,
              chapterId: args['chapterId'] as String,
            );
          },
        },
      ),
    );
  }
}
