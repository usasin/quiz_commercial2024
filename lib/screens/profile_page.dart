import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/usage_meter.dart';
import '../services/engagement_service.dart';
import '../services/admin_service.dart';
import '../services/app_language.dart';
import '../widgets/cip_page_header.dart';
import 'custom_bottom_nav_bar.dart';

const String _storeUrl =
    'https://play.google.com/store/apps/details?id=com.emploiboost.emploiboost';

const Map<String, String> _englishBadgeTitles = {
  'first_quiz': 'First quiz',
  'first_simulation': 'First simulation',
  'streak_3': '3-day streak',
  'streak_7': '7-day streak',
  'streak_14': '14-day streak',
  'streak_30': '30-day streak',
  'quiz_10': '10 quizzes completed',
  'quiz_25': 'Quiz expert',
  'simu_5': '5 simulations',
  'simu_10': 'Expert in action',
  'first_lesson': 'First lesson',
  'perfect_quiz': 'Perfect score',
  'oral_90': 'Outstanding interview',
  'xp_500': '500 XP milestone',
  'xp_1500': 'Proven proficiency',
  'challenge_winner': 'Challenge completed',
  'assistant_10': 'Professional curiosity',
};

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  /// ✅ FIX "retour page noire"
  void _safeBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      // si la page est "racine" (ex: arrivée via pushReplacementNamed)
      Navigator.pushNamedAndRemoveUntil(context, '/levels', (route) => false);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      AdminService.instance.clearCache();
      await UsageMeter().setAdminPreviewFree(false);
      await UsageMeter().setPremium(false);

      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      debugPrint('Erreur signOut: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.bilingual(
                fr: 'Erreur lors de la déconnexion',
                en: 'Sign-out error',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      // ✅ back safe
      appBar: CipAppBar(onBackPressed: () => _safeBack(context)),
      body: Column(
        children: [
          CipPageHeader(
            moduleTitle: context.bilingual(fr: 'PROFIL', en: 'PROFILE'),
            pageTitle: context.bilingual(fr: 'Mon compte', en: 'My account'),
            moduleTitleColor: cs.primary,
            subtitle: Text(
              context.bilingual(
                fr: 'Progression • Crédits • Partage • Compte',
                en: 'Progress • Credits • Sharing • Account',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Container(
              color: cs.background,
              child: user == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          context.bilingual(
                            fr: 'Aucun utilisateur connecté.',
                            en: 'No signed-in user.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ),
                    )
                  : _ProfileContent(user: user, parent: this),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 2),
    );
  }
}

class _ProfileContent extends StatefulWidget {
  final User user;
  final ProfilePage parent;

  const _ProfileContent({required this.user, required this.parent});

  @override
  State<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<_ProfileContent> {
  final _meter = UsageMeter();

  bool _loading = true;
  bool _isPremium = false;

  int _simCredits = 0;
  int _intensiveExamPasses = 0;
  int _freeLevelsLeft = 0; // /3

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _meter.initIfNeeded();

    bool prem = false;
    int simCredits = 0;
    int intensiveExamPasses = 0;
    int freeLevels = 0;

    try {
      prem = await _meter.isPremium();
    } catch (_) {}

    try {
      intensiveExamPasses = await _meter.getIntensiveExamPasses();
    } catch (_) {}

    try {
      final dyn = _meter as dynamic;
      final sc = await dyn.getSimCredits();
      simCredits = (sc as num).toInt();
    } catch (_) {
      try {
        final t = await _meter.getTextCredits();
        simCredits = (t as num).toInt();
      } catch (_) {
        simCredits = 0;
      }
    }

    try {
      final dyn = _meter as dynamic;
      final fl = await dyn.getFreeLevelPlays();
      freeLevels = (fl as num).toInt();
    } catch (_) {
      freeLevels = 0;
    }

    if (!mounted) return;
    setState(() {
      _isPremium = prem;
      _simCredits = simCredits;
      _intensiveExamPasses = intensiveExamPasses;
      _freeLevelsLeft = freeLevels;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = widget.user;

    final w = MediaQuery.of(context).size.width;
    final bool isSmall = w < 380;
    final double iconBtn = isSmall ? 22 : 20;
    final double iconSmall = isSmall ? 18 : 16;

    final displayName =
        user.displayName ?? context.bilingual(fr: 'Utilisateur', en: 'User');
    final email =
        user.email ??
        context.bilingual(fr: 'Email inconnu', en: 'Unknown email');

    // ✅ FIX CRASH: NetworkImage("") / file:///
    final photoUrl = (user.photoURL ?? '').trim();
    final hasPhoto = photoUrl.isNotEmpty;

    final planLabel = _loading ? "..." : (_isPremium ? "PREMIUM" : "FREE");
    final passLabel = _intensiveExamPasses > 0
        ? context.bilingual(
            fr: ' • $_intensiveExamPasses pass intensif prêt',
            en: ' • $_intensiveExamPasses intensive pass ready',
          )
        : '';
    final planSubtitle = _loading
        ? ""
        : (_isPremium
              ? context.bilingual(
                  fr: '2 séances guidées/jour • 1 examen blanc/7 jours$passLabel',
                  en: '2 guided sessions/day • 1 mock exam/7 days$passLabel',
                )
              : context.bilingual(
                  fr: 'Essai simulation offert • Niveaux gratuits: $_freeLevelsLeft/3$passLabel',
                  en: 'Free simulation trial • Free levels: $_freeLevelsLeft/3$passLabel',
                ));

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ----- Carte profil
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: cs.outline.withOpacity(0.7)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: cs.primary.withOpacity(0.10),
                        backgroundImage: hasPhoto
                            ? NetworkImage(photoUrl)
                            : null,
                        child: !hasPhoto
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: isSmall ? 30 : 28,
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withOpacity(0.65),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            user.providerData.any(
                                  (p) => p.providerId == 'google.com',
                                )
                                ? Icons.account_circle_rounded
                                : Icons.email_rounded,
                            size: iconSmall,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              user.providerData.any(
                                    (p) => p.providerId == 'google.com',
                                  )
                                  ? context.bilingual(
                                      fr: 'Connecté avec Google',
                                      en: 'Signed in with Google',
                                    )
                                  : context.bilingual(
                                      fr: 'Connecté par email',
                                      en: 'Signed in with email',
                                    ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: cs.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: (_isPremium ? cs.tertiary : cs.secondary)
                              .withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cs.outline.withOpacity(0.7),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  size: iconSmall,
                                  color: _isPremium
                                      ? cs.tertiary
                                      : cs.secondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${context.bilingual(fr: 'Compte actif', en: 'Active account')} • $planLabel',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!_loading) ...[
                              const SizedBox(height: 6),
                              Text(
                                planSubtitle,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: isSmall ? 10.5 : 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface.withOpacity(0.75),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                _SectionTitle(
                  title: context.bilingual(
                    fr: 'Ta progression',
                    en: 'Your progress',
                  ),
                ),
                const SizedBox(height: 8),
                _UserStatsCard(uid: user.uid),

                const SizedBox(height: 18),

                _SectionTitle(
                  title: context.bilingual(
                    fr: 'Série & badges',
                    en: 'Streak & badges',
                  ),
                ),
                const SizedBox(height: 8),
                _EngagementCard(uid: user.uid),

                const SizedBox(height: 18),

                _SectionTitle(
                  title: context.bilingual(fr: 'Application', en: 'App'),
                ),
                const SizedBox(height: 8),

                StreamBuilder<bool>(
                  stream: AdminService.instance.watchIsAdmin(),
                  builder: (context, snapshot) {
                    if (snapshot.data != true) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/admin'),
                          icon: Icon(
                            Icons.admin_panel_settings_rounded,
                            size: iconBtn,
                          ),
                          label: const Text(
                            'Super Admin',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/credits',
                    ).then((_) => _boot()),
                    icon: Icon(Icons.workspace_premium_rounded, size: iconBtn),
                    label: Text(
                      context.bilingual(
                        fr: 'Premium / Abonnement',
                        en: 'Premium / Subscription',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _shareApp(context),
                        icon: Icon(Icons.ios_share_rounded, size: iconBtn),
                        label: Text(
                          context.bilingual(fr: 'Partager', en: 'Share'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _rateApp,
                        icon: Icon(Icons.star_rate_rounded, size: iconBtn),
                        label: Text(
                          context.bilingual(
                            fr: 'Noter l’app',
                            en: 'Rate the app',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showQrSheet(context),
                    icon: Icon(Icons.qr_code_rounded, size: iconBtn),
                    label: Text(
                      context.bilingual(
                        fr: 'Code QR de l’app',
                        en: 'App QR code',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                _SectionTitle(
                  title: context.bilingual(fr: 'Compte', en: 'Account'),
                ),
                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red.shade700,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => _showLogoutDialog(context),
                    icon: Icon(Icons.logout_rounded, size: iconBtn),
                    label: Text(
                      context.bilingual(fr: 'Se déconnecter', en: 'Sign out'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                TextButton.icon(
                  onPressed: () => _showDeleteDialog(context),
                  icon: Icon(
                    Icons.delete_forever_rounded,
                    size: iconBtn,
                    color: Colors.red,
                  ),
                  label: Text(
                    context.bilingual(
                      fr: 'Supprimer mon compte',
                      en: 'Delete my account',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _shareApp(BuildContext context) {
    Share.share(
      context.bilingual(
        fr: 'Découvre EmploiBoost pour renforcer tes compétences professionnelles : $_storeUrl',
        en: 'Discover EmploiBoost and build your professional skills: $_storeUrl',
      ),
      subject: context.bilingual(
        fr: 'EmploiBoost – Préparation professionnelle',
        en: 'EmploiBoost – Professional preparation',
      ),
    );
  }

  Future<void> _rateApp() async {
    final uri = Uri.parse(_storeUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Impossible d’ouvrir le store');
    }
  }

  void _showQrSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.bilingual(fr: 'Partage rapide', en: 'Quick share'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                context.bilingual(
                  fr: 'Scanne ce code QR pour télécharger l’app sur le Play Store.',
                  en: 'Scan this QR code to download the app from the Play Store.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withOpacity(0.65),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cs.outline.withOpacity(0.7)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _storeUrl,
                  version: QrVersions.auto,
                  size: 210,
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            context.bilingual(fr: 'Déconnexion', en: 'Sign out'),
            textAlign: TextAlign.center,
          ),
          content: Text(
            context.bilingual(
              fr: 'Veux-tu vraiment te déconnecter ?',
              en: 'Do you really want to sign out?',
            ),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.bilingual(fr: 'Annuler', en: 'Cancel')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await widget.parent._signOut(context);
              },
              child: Text(
                context.bilingual(fr: 'Déconnexion', en: 'Sign out'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            context.bilingual(
              fr: 'Supprimer mon compte',
              en: 'Delete my account',
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            context.bilingual(
              fr: 'Cette action est définitive.\n\nTon compte, ta progression et toutes tes données seront supprimés.',
              en: 'This action is permanent.\n\nYour account, progress and all your data will be deleted.',
            ),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.bilingual(fr: 'Annuler', en: 'Cancel')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _deleteAccount(context);
              },
              child: Text(
                context.bilingual(fr: 'Supprimer', en: 'Delete'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(current.uid)
          .delete()
          .catchError((_) {});
      await current.delete();
      await FirebaseAuth.instance.signOut();

      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Erreur deleteAccount: ${e.code}');
      if (e.code == 'requires-recent-login') {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              context.bilingual(
                fr: 'Pour des raisons de sécurité, reconnecte-toi puis réessaie.',
                en: 'For security, sign in again and retry.',
              ),
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              context.bilingual(
                fr: 'Impossible de supprimer le compte.',
                en: 'Unable to delete the account.',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur deleteAccount: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.bilingual(
              fr: 'Erreur lors de la suppression du compte.',
              en: 'Account deletion error.',
            ),
          ),
        ),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      title,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w900,
        color: cs.onSurface,
      ),
    );
  }
}

class _EngagementCard extends StatelessWidget {
  final String uid;
  const _EngagementCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? const <String, dynamic>{};
        final eng =
            (data['engagement'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};

        final xp = (eng['xp'] as num?)?.toInt() ?? 0;
        final streakCur = (eng['streakCurrent'] as num?)?.toInt() ?? 0;
        final streakBest = (eng['streakBest'] as num?)?.toInt() ?? 0;
        final badgesMap =
            (eng['badges'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
        final badges = badgesMap.keys.map((e) => e.toString()).toSet();
        final badgesCount = badges.length;

        final preview = badges.toList()..sort();
        final previewBadges = preview.take(3).toList();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: cs.outline.withOpacity(0.7)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.bilingual(
                        fr: 'Ton entraînement',
                        en: 'Your training',
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                        fontSize: 15.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cs.secondary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: cs.outline.withOpacity(0.7)),
                    ),
                    child: Text(
                      '$xp XP',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: cs.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.local_fire_department_rounded,
                      label: context.bilingual(fr: 'Série', en: 'Streak'),
                      value: context.bilingual(
                        fr: '$streakCur j',
                        en: '$streakCur d',
                      ),
                      tint: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.emoji_events_rounded,
                      label: context.bilingual(fr: 'Record', en: 'Best'),
                      value: context.bilingual(
                        fr: '$streakBest j',
                        en: '$streakBest d',
                      ),
                      tint: cs.tertiary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.badge_rounded,
                      label: 'Badges',
                      value: badgesCount.toString(),
                      tint: cs.secondary,
                    ),
                  ),
                ],
              ),
              if (previewBadges.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: previewBadges.map((id) {
                    final meta = EngagementService.badgeCatalog[id];
                    final title = context.isEnglish
                        ? (_englishBadgeTitles[id] ?? id)
                        : (meta?['title'] ?? id);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: cs.outline.withOpacity(0.7)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events_rounded,
                            size: 16,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/progression'),
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: Text(
                    context.bilingual(
                      fr: 'Missions, niveaux et récompenses',
                      en: 'Missions, levels and rewards',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/badges'),
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Badges'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/leaderboard'),
                      icon: const Icon(Icons.leaderboard_rounded),
                      label: Text(
                        context.bilingual(fr: 'Classement', en: 'Leaderboard'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          Icon(icon, color: tint),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: cs.onSurface.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserStatsCard extends StatelessWidget {
  final String uid;
  const _UserStatsCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDoc,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outline.withOpacity(0.7)),
            ),
            child: const LinearProgressIndicator(),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildStatsContainer(
            context,
            xp: 0,
            streakDays: 0,
            totalScore: 0,
            bestAreaLabel: context.bilingual(
              fr: 'Pas encore de données',
              en: 'No data yet',
            ),
            bestAreaValue: 0,
          );
        }

        final data = snapshot.data!.data() ?? {};
        int xp = (data['xp'] as num?)?.toInt() ?? 0;
        int streakDays = (data['streakDays'] as num?)?.toInt() ?? 0;
        int totalScore = (data['totalScore'] as num?)?.toInt() ?? 0;

        final levelsResults =
            (data['levelsResults'] as Map<String, dynamic>?) ?? {};

        String bestLabel = context.bilingual(
          fr: 'Pas encore de niveau maîtrisé',
          en: 'No level mastered yet',
        );
        int bestValue = 0;
        int computedScore = 0;

        levelsResults.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            final p = (value['bestPercent'] as num?)?.toInt() ?? 0;
            if (p > 0) computedScore += p;

            if (p > bestValue) {
              bestValue = p;
              final parts = key.split('::');
              int levelNum = 1;
              if (parts.length >= 3) levelNum = int.tryParse(parts[2]) ?? 1;
              bestLabel = context.bilingual(
                fr: 'Niveau $levelNum le plus maîtrisé',
                en: 'Best mastered: level $levelNum',
              );
            }
          } else if (value is num) {
            final p = value.toInt();
            if (p > 0) computedScore += p;
            if (p > bestValue) {
              bestValue = p;
              bestLabel = context.bilingual(
                fr: 'Niveau 1 le plus maîtrisé',
                en: 'Best mastered: level 1',
              );
            }
          }
        });

        if (totalScore == 0 && computedScore > 0) totalScore = computedScore;
        if (xp == 0 && computedScore > 0) xp = computedScore;

        return _buildStatsContainer(
          context,
          xp: xp,
          streakDays: streakDays,
          totalScore: totalScore,
          bestAreaLabel: bestLabel,
          bestAreaValue: bestValue,
        );
      },
    );
  }

  Widget _buildStatsContainer(
    BuildContext context, {
    required int xp,
    required int streakDays,
    required int totalScore,
    required String bestAreaLabel,
    required int bestAreaValue,
  }) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final itemWidth = (width - 16 * 2 - 12) / 2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withOpacity(0.7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              SizedBox(
                width: itemWidth,
                child: _StatItem(
                  label: 'XP',
                  value: xp.toString(),
                  icon: Icons.bolt_rounded,
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _StatItem(
                  label: context.bilingual(
                    fr: 'Série (jours)',
                    en: 'Streak (days)',
                  ),
                  value: streakDays.toString(),
                  icon: Icons.local_fire_department_rounded,
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _StatItem(
                  label: context.bilingual(
                    fr: 'Score total',
                    en: 'Total score',
                  ),
                  value: totalScore.toString(),
                  icon: Icons.emoji_events_rounded,
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _StatItem(
                  label: bestAreaLabel,
                  value: '$bestAreaValue%',
                  icon: Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withOpacity(0.65),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
