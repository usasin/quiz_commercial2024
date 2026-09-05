import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../rotating_glow_border.dart';
import '../simulator/simulator_hub_page.dart';
import '../theme/cip_colors.dart';
import '../widgets/cip_page_header.dart';
import '../widgets/cip_widgets.dart';
import '../services/localized_firestore.dart';
import '../services/app_language.dart';

import 'custom_bottom_nav_bar.dart';
import 'lessons_screen.dart';
import 'quiz_screen.dart';

class ModulePage extends StatelessWidget {
  final String chapterId;
  final String chapterTitle;

  const ModulePage({
    super.key,
    required this.chapterId,
    required this.chapterTitle,
  });

  Future<void> _askLogin(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: cs.outline.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Icon(Icons.lock_rounded, size: 40, color: cs.onSurface),
              const SizedBox(height: 10),
              Text(
                context.bilingual(fr: 'Mode invité', en: 'Guest mode'),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                context.bilingual(
                  fr: 'Connecte-toi pour débloquer les quiz, la progression et la simulation IA.',
                  en: 'Sign in to unlock quizzes, progress tracking and AI simulations.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface.withOpacity(0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/login');
                  },
                  child: Text(
                    context.bilingual(fr: 'Se connecter', en: 'Sign in'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.bilingual(fr: 'Plus tard', en: 'Later')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: CipAppBar(onBackPressed: () => Navigator.pop(context)),
      body: CipDigitalBackground(
        child: Column(
          children: [
            CipPageHeader(
              moduleTitle: chapterTitle,
              pageTitle: context.bilingual(fr: 'Modules', en: 'Modules'),
              moduleTitleColor: cs.primary,
              subtitle: Text(
                context.bilingual(
                  fr: 'Leçons → Quiz (N1→N3) → Révision → Simu IA',
                  en: 'Lessons → Quiz (L1→L3) → Review → AI simulation',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: _ModulesList(
                chapterId: chapterId,
                onAskLogin: () => _askLogin(context),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 0),
    );
  }
}

class _ModulesList extends StatelessWidget {
  final String chapterId;
  final VoidCallback onAskLogin;

  const _ModulesList({required this.chapterId, required this.onAskLogin});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final userDocStream = user == null
        ? null
        : FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots();

    final modulesStream = FirebaseFirestore.instance
        .collection('chapters')
        .doc(chapterId)
        .collection('modules')
        .orderBy('order')
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDocStream,
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() ?? {};
        final levelsResults =
            (userData['levelsResults'] as Map<String, dynamic>?) ?? {};
        final lessonsSeen =
            (userData['lessonsSeen'] as Map<String, dynamic>?) ?? {};
        final simuDoneMap =
            (userData['simuDone'] as Map<String, dynamic>?) ?? {};

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: modulesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${context.bilingual(fr: 'Erreur', en: 'Error')}: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Center(
                child: Text(
                  context.bilingual(
                    fr: 'Aucun module trouvé.',
                    en: 'No modules found.',
                  ),
                ),
              );
            }

            bool isUnlockedAtThisIndex(int index) {
              if (index == 0) return true;
              if (user == null) return false;

              final prev = docs[index - 1];
              final prevKey = '$chapterId::${prev.id}';
              return simuDoneMap[prevKey] == true;
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = LocalizedFirestore.data(context, doc.data());

                final order = (data['order'] is int)
                    ? (data['order'] as int)
                    : int.tryParse('${data['order']}') ?? (index + 1);

                final title = (data['title'] ?? 'Module').toString();
                final description = (data['description'] ?? '').toString();

                return _ModuleCard(
                  chapterId: chapterId,
                  moduleId: doc.id,
                  order: order,
                  title: title,
                  description: description,
                  onAskLogin: onAskLogin,
                  isLoggedIn: user != null,
                  moduleUnlocked: isUnlockedAtThisIndex(index),
                  levelsResults: levelsResults,
                  lessonsSeen: lessonsSeen,
                  simuDoneMap: simuDoneMap,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String chapterId;
  final String moduleId;
  final int order;
  final String title;
  final String description;

  final VoidCallback onAskLogin;
  final bool isLoggedIn;
  final bool moduleUnlocked;

  final Map<String, dynamic> levelsResults;
  final Map<String, dynamic> lessonsSeen;
  final Map<String, dynamic> simuDoneMap;

  const _ModuleCard({
    required this.chapterId,
    required this.moduleId,
    required this.order,
    required this.title,
    required this.description,
    required this.onAskLogin,
    required this.isLoggedIn,
    required this.moduleUnlocked,
    required this.levelsResults,
    required this.lessonsSeen,
    required this.simuDoneMap,
  });

  int _bestForLevel(int level) {
    final key = '$chapterId::$moduleId::$level';
    final raw = levelsResults[key];
    if (raw is Map<String, dynamic>)
      return (raw['bestPercent'] as num?)?.toInt() ?? 0;
    if (raw is num) return raw.toInt();
    return 0;
  }

  Future<void> _setUserFlag(String field, bool value) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
      field: {'$chapterId::$moduleId': value},
    }, SetOptions(merge: true));
  }

  void _blocked(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.bilingual(
            fr: '🔒 Termine le module précédent (Leçons + N1 + N2 + N3 + Simu IA) pour débloquer celui-ci.',
            en: '🔒 Complete the previous module (Lessons + L1 + L2 + L3 + AI simulation) to unlock this one.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final key = '$chapterId::$moduleId';
    final lessonsDone = lessonsSeen[key] == true;
    final simuDone = simuDoneMap[key] == true;

    final best1 = _bestForLevel(1);
    final best2 = _bestForLevel(2);
    final best3 = _bestForLevel(3);

    final n1Done = best1 >= 80;
    final n2Done = best2 >= 80;
    final n3Done = best3 >= 80;

    final gate = moduleUnlocked;

    final n1Enabled = gate && isLoggedIn && lessonsDone;
    final n2Enabled = gate && isLoggedIn && n1Done;
    final n3Enabled = gate && isLoggedIn && n2Done;

    final revisionEnabled = gate && isLoggedIn && (n1Done && n2Done && n3Done);
    final simuEnabled = gate && isLoggedIn && (n1Done && n2Done && n3Done);

    String nextStep = 'lessons';
    if (!isLoggedIn) nextStep = 'login';
    if (isLoggedIn && lessonsDone && !n1Done) nextStep = 'level1';
    if (isLoggedIn && n1Done && !n2Done) nextStep = 'level2';
    if (isLoggedIn && n2Done && !n3Done) nextStep = 'level3';
    if (isLoggedIn && n3Done && !simuDone) nextStep = 'simulation';
    if (isLoggedIn && simuDone) nextStep = 'done';

    final moduleProgress = ((best1 + best2 + best3) / 3.0).round().clamp(
      0,
      100,
    );

    return Opacity(
      opacity: gate ? 1.0 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CipColors.surface2, // ✅ blanc cassé (le cadre)
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outline.withOpacity(0.75)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de carte
            Row(
              children: [
                _IconPill(
                  icon: gate ? Icons.play_arrow_rounded : Icons.lock_rounded,
                  color: gate ? cs.primary : cs.onSurface.withOpacity(0.55),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$order. $title',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface.withOpacity(0.65),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.outline.withOpacity(0.7)),
                  ),
                  child: Text(
                    '$moduleProgress%',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Leçons (glow si nextStep)
            _GlowTile(
              glow: gate && nextStep == 'lessons',
              colors: [cs.primary, cs.secondary, cs.tertiary, cs.primary],
              child: _ActionTile(
                label: context.bilingual(fr: 'Leçons', en: 'Lessons'),
                subtitle: !isLoggedIn
                    ? context.bilingual(fr: 'Connexion', en: 'Sign in')
                    : (lessonsDone
                          ? context.bilingual(fr: 'Fait', en: 'Done')
                          : context.bilingual(fr: 'À faire', en: 'To do')),
                icon: Icons.menu_book_rounded,
                enabled: gate,
                accent: cs.primary,
                onTap: () async {
                  if (!gate) return _blocked(context);
                  if (!isLoggedIn) return onAskLogin();
                  await _setUserFlag('lessonsSeen', true);
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LessonsScreen(
                        chapterId: chapterId,
                        moduleId: moduleId,
                        moduleTitle: title,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // Niveaux 1/2/3
            Row(
              children: [
                Expanded(
                  child: _MiniTile(
                    label: "N1",
                    percent: best1,
                    enabled: n1Enabled,
                    done: n1Done,
                    accent: cs.primary,
                    icon: Icons.looks_one_rounded,
                    glow: gate && nextStep == 'level1',
                    onTap: () {
                      if (!gate) return _blocked(context);
                      if (!isLoggedIn) return onAskLogin();
                      if (!n1Enabled) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizScreen(
                            chapterId: chapterId,
                            moduleId: moduleId,
                            level: 1,
                            onLevelCompleted: () {},
                            isRevision: false,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniTile(
                    label: "N2",
                    percent: best2,
                    enabled: n2Enabled,
                    done: n2Done,
                    accent: cs.primary,
                    icon: Icons.looks_two_rounded,
                    glow: gate && nextStep == 'level2',
                    onTap: () {
                      if (!gate) return _blocked(context);
                      if (!isLoggedIn) return onAskLogin();
                      if (!n2Enabled) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizScreen(
                            chapterId: chapterId,
                            moduleId: moduleId,
                            level: 2,
                            onLevelCompleted: () {},
                            isRevision: false,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniTile(
                    label: "N3",
                    percent: best3,
                    enabled: n3Enabled,
                    done: n3Done,
                    accent: cs.primary,
                    icon: Icons.looks_3_rounded,
                    glow: gate && nextStep == 'level3',
                    onTap: () {
                      if (!gate) return _blocked(context);
                      if (!isLoggedIn) return onAskLogin();
                      if (!n3Enabled) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizScreen(
                            chapterId: chapterId,
                            moduleId: moduleId,
                            level: 3,
                            onLevelCompleted: () {},
                            isRevision: false,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Révision
            _GlowTile(
              glow: revisionEnabled && nextStep == 'review',
              colors: [cs.tertiary, cs.primary, cs.secondary, cs.tertiary],
              child: _ActionTile(
                label: context.bilingual(fr: 'Révision', en: 'Review'),
                subtitle: revisionEnabled
                    ? context.bilingual(fr: 'Débloqué', en: 'Unlocked')
                    : context.bilingual(fr: 'Bloqué', en: 'Locked'),
                icon: Icons.auto_awesome_rounded,
                enabled: revisionEnabled,
                accent: cs.tertiary,
                onTap: () async {
                  if (!gate) return _blocked(context);
                  if (!isLoggedIn) return onAskLogin();
                  if (!revisionEnabled) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(
                        chapterId: chapterId,
                        moduleId: moduleId,
                        level: 1,
                        onLevelCompleted: () {},
                        isRevision: true,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // Simu IA
            _GlowTile(
              glow: simuEnabled && nextStep == 'simulation',
              colors: [cs.secondary, cs.primary, cs.tertiary, cs.secondary],
              child: _ActionTile(
                label: context.bilingual(fr: 'Simu IA', en: 'AI simulation'),
                subtitle: simuDone
                    ? context.bilingual(fr: 'Fait', en: 'Done')
                    : (simuEnabled
                          ? context.bilingual(fr: 'Débloqué', en: 'Unlocked')
                          : context.bilingual(fr: 'Bloqué', en: 'Locked')),
                icon: Icons.smart_toy_rounded,
                enabled: simuEnabled,
                accent: cs.secondary,
                onTap: () {
                  if (!gate) return _blocked(context);
                  if (!isLoggedIn) return onAskLogin();
                  if (!simuEnabled) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SimulatorHubPage(
                        chapterId: chapterId,
                        moduleId: moduleId,
                        moduleTitle: title,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper: applique le glow seulement si glow=true
class _GlowTile extends StatelessWidget {
  final bool glow;
  final List<Color> colors;
  final Widget child;

  const _GlowTile({
    required this.glow,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!glow) return child;

    return RotatingGlowBorder(
      borderRadius: 18,
      borderWidth: 3,
      colors: colors,
      duration: const Duration(seconds: 2),
      padding: const EdgeInsets.all(3),
      child: child,
    );
  }
}

class _IconPill extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconPill({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withOpacity(0.7)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final Color accent;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white, // ✅ boutons blancs (ressortent sur surface2)
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outline.withOpacity(0.75)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withOpacity(0.20)),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.68),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                enabled ? Icons.chevron_right_rounded : Icons.lock_rounded,
                color: enabled ? accent : cs.onSurface.withOpacity(0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  final String label;
  final int percent;
  final bool enabled;
  final bool done;
  final IconData icon;
  final Color accent;
  final bool glow;
  final VoidCallback onTap;

  const _MiniTile({
    required this.label,
    required this.percent,
    required this.enabled,
    required this.done,
    required this.icon,
    required this.accent,
    required this.glow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final tile = InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outline.withOpacity(0.75)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 12,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withOpacity(0.20)),
                ),
                child: Icon(done ? Icons.check_rounded : icon, color: accent),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withOpacity(0.25)),
                ),
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!glow) return tile;

    return RotatingGlowBorder(
      borderRadius: 16,
      borderWidth: 3,
      colors: [cs.primary, cs.secondary, cs.tertiary, cs.primary],
      duration: const Duration(seconds: 2),
      padding: const EdgeInsets.all(3),
      child: tile,
    );
  }
}
