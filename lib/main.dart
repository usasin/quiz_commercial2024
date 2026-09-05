import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'firebase_options.dart';

import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/levels_page.dart';

import 'screens/profile_page.dart';
import 'toolbox_page.dart';
import 'screens/badges_page.dart';
import 'screens/leaderboard_page.dart';
import 'screens/assistant_cip_page.dart';
import 'screens/exam_router_page.dart';
import 'screens/admin_dashboard_page.dart';
import 'screens/progression_hub_page.dart';
import 'screens/module_page.dart';
import 'screens/quiz_screen.dart';
import 'simulator/simulator_hub_page.dart';

import 'theme/cip_theme.dart';

// Paywall + UsageMeter
import 'screens/credits_paywall_page.dart';
import 'services/usage_meter.dart';
import 'services/purchase_bootstrapper.dart';
import 'services/admob_interstitial_service.dart';
import 'services/app_language.dart';
import 'widgets/app_communication_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ Initialisation AdMob.
  // Les vrais IDs sont utilisés uniquement en release.
  await MobileAds.instance.initialize();

  final meter = UsageMeter();
  await meter.initIfNeeded();
  await meter.syncFromCloud();
  // ✅ UX pro: restore silencieux au démarrage (Premium se resync automatiquement)
  // Ne bloque pas le lancement.
  unawaited(PurchaseBootstrapper.runOnce());

  // ✅ Précharge les interstitiels pour qu'ils soient prêts aux transitions naturelles.
  unawaited(AdmobInterstitialService.instance.preloadAll());

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('fr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('fr'),
      child: const MyApp(),
    ),
  );
}

/// ✅ Page “bloquée” si pas connecté
class RequireAuth extends StatelessWidget {
  final Widget child;
  final String title;
  final String message;

  const RequireAuth({
    super.key,
    required this.child,
    this.title = "Connexion requise",
    this.message = "Connecte-toi pour accéder à cette page.",
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return child;

    final localizedTitle = context.isEnglish ? 'Sign-in required' : title;
    final localizedMessage = context.isEnglish
        ? _englishAuthMessage(message)
        : message;

    return Scaffold(
      appBar: AppBar(title: Text(localizedTitle), centerTitle: true),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 46),
                const SizedBox(height: 12),
                Text(
                  localizedMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    child: Text(
                      context.bilingual(fr: 'Se connecter', en: 'Sign in'),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/levels',
                    (r) => false,
                  ),
                  child: Text(
                    context.bilingual(
                      fr: 'Continuer en mode invité',
                      en: 'Continue as guest',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _englishAuthMessage(String message) {
  if (message.contains('boîte à outils')) {
    return 'Sign in to access the toolbox.';
  }
  if (message.contains('modules')) return 'Sign in to access the modules.';
  if (message.contains('profil')) return 'Sign in to access your profile.';
  if (message.contains('badges')) return 'Sign in to view your badges.';
  if (message.contains('classement')) return 'Sign in to view the leaderboard.';
  if (message.contains('missions')) {
    return 'Sign in to track your missions and levels.';
  }
  if (message.contains('abonnement')) {
    return 'Sign in before choosing a subscription.';
  }
  if (message.contains('examen')) return 'Sign in to start a mock exam.';
  if (message.contains('administrateur')) {
    return 'Sign in with your administrator account.';
  }
  if (message.contains('quiz')) return 'Sign in to start quizzes.';
  if (message.contains('simulations')) {
    return 'Sign in to access simulations.';
  }
  return 'Sign in to access this page.';
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EmploiBoost',
      debugShowCheckedModeBanner: false,
      theme: buildCipTheme(),
      builder: (context, child) =>
          AppCommunicationGate(child: child ?? const SizedBox.shrink()),

      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,

      // ✅ Splash animé au démarrage, puis Levels (mode invité)
      initialRoute: '/splash',

      routes: {
        '/splash': (_) => const SplashScreen(nextRoute: '/levels'),
        '/login': (_) => const LoginScreen(),

        // ✅ Accessible même sans compte
        '/levels': (_) => const LevelsPage(),
        '/toolbox': (context) {
          final raw = ModalRoute.of(context)?.settings.arguments;
          final args = raw is Map ? raw : const <String, dynamic>{};
          final trackId = (args['trackId'] ?? '').toString().trim();
          return RequireAuth(
            title: "Connexion requise",
            message: "Connecte-toi pour accéder à la boîte à outils.",
            child: ToolboxPage(trackId: trackId.isEmpty ? null : trackId),
          );
        },

        // 🔒 Bloquées si pas connecté
        '/module': (_) => RequireAuth(
          title: "Connexion requise",
          message: "Connecte-toi pour accéder aux modules.",
          child: ModulePage(chapterTitle: '', chapterId: ''),
        ),

        '/profile': (_) => const RequireAuth(
          title: "Connexion requise",
          message: "Connecte-toi pour accéder à ton profil.",
          child: ProfilePage(),
        ),

        '/badges': (_) => const RequireAuth(
          title: "Connexion requise",
          message: "Connecte-toi pour voir tes badges.",
          child: BadgesPage(),
        ),
        '/leaderboard': (_) => const RequireAuth(
          title: "Connexion requise",
          message: "Connecte-toi pour accéder au classement.",
          child: LeaderboardPage(),
        ),
        '/progression': (_) => const RequireAuth(
          title: "Connexion requise",
          message: "Connecte-toi pour suivre tes missions et tes niveaux.",
          child: ProgressionHubPage(),
        ),

        // Un achat doit être rattaché à un compte avant sa vérification serveur.
        '/credits': (_) => const RequireAuth(
          title: 'Connexion requise',
          message: 'Connecte-toi avant de choisir un abonnement.',
          child: CreditsPaywallPage(),
        ),
        '/assistant': (context) {
          final raw = ModalRoute.of(context)?.settings.arguments;
          final args = raw is Map ? raw : const <String, dynamic>{};
          final trackId = (args['trackId'] ?? '').toString().trim();
          return AssistantCipPage(trackId: trackId.isEmpty ? null : trackId);
        },
        '/exam': (context) {
          final raw = ModalRoute.of(context)?.settings.arguments;
          final args = raw is Map ? raw : const <String, dynamic>{};
          final trackId = (args['trackId'] ?? '').toString().trim();
          return RequireAuth(
            title: 'Connexion requise',
            message: 'Connecte-toi pour lancer un examen blanc.',
            child: ExamRouterPage(trackId: trackId.isEmpty ? null : trackId),
          );
        },
        '/admin': (_) => const RequireAuth(
          title: 'Connexion requise',
          message: 'Connecte-toi avec ton compte administrateur.',
          child: AdminDashboardPage(),
        ),

        // Optionnel
        '/quiz': (_) => RequireAuth(
          title: "Connexion requise",
          message: "Connecte-toi pour lancer les quiz.",
          child: QuizScreen(
            level: 1,
            chapterId: 'chapter1',
            moduleId: 'module1',
            onLevelCompleted: () {},
          ),
        ),
      },

      onGenerateRoute: (settings) {
        if (settings.name == '/simulator') {
          final args = (settings.arguments as Map<String, dynamic>?) ?? {};
          return MaterialPageRoute(
            builder: (_) => RequireAuth(
              title: "Connexion requise",
              message: "Connecte-toi pour accéder aux simulations.",
              child: SimulatorHubPage(
                chapterId: (args['chapterId'] ?? '') as String,
                moduleId: (args['moduleId'] ?? '') as String,
                moduleTitle: (args['moduleTitle'] ?? 'Module') as String,
              ),
            ),
          );
        }
        return null;
      },
    );
  }
}
