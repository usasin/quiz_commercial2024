import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/engagement_service.dart';
import '../services/app_language.dart';
import '../widgets/cip_page_header.dart';
import 'custom_bottom_nav_bar.dart';

class BadgesPage extends StatelessWidget {
  const BadgesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: CipAppBar(onBackPressed: () => Navigator.pop(context)),
      body: Column(
        children: [
          CipPageHeader(
            moduleTitle: 'BADGES',
            pageTitle: context.bilingual(fr: 'Tes badges', en: 'Your badges'),
            moduleTitleColor: cs.primary,
            subtitle: Text(
              context.bilingual(
                fr: 'Débloque des récompenses avec les leçons, quiz, simulations et défis.',
                en: 'Unlock rewards through lessons, quizzes, simulations and challenges.',
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // ✅ Le reste DOIT être scrollable -> Expanded + ListView = pas d'overflow
          Expanded(
            child: Container(
              color: cs.background,
              child: user == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          context.bilingual(
                            fr: 'Connecte-toi pour voir tes badges.',
                            en: 'Sign in to view your badges.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ),
                    )
                  : _BadgesBody(uid: user.uid),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 2),
    );
  }
}

class _BadgesBody extends StatelessWidget {
  final String uid;
  const _BadgesBody({required this.uid});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data?.data() ?? const <String, dynamic>{};
        final eng =
            (data['engagement'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
        final badgesMap =
            (eng['badges'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
        final unlocked = badgesMap.keys.map((e) => e.toString()).toSet();

        // catalogue global
        final catalog = EngagementService.badgeCatalog;
        final allIds = catalog.keys.toList()..sort();

        if (allIds.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.bilingual(
                  fr: 'Aucun badge configuré (badgeCatalog est vide).',
                  en: 'No badges configured (badgeCatalog is empty).',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
              ),
            ),
          );
        }

        // ✅ ListView (scroll)
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.outline.withOpacity(0.7)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 14,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withOpacity(0.7)),
                    ),
                    child: Icon(Icons.emoji_events_rounded, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${context.bilingual(fr: 'Débloqués', en: 'Unlocked')}: ${unlocked.length} / ${allIds.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            ...allIds.map((id) {
              final meta = catalog[id] ?? const <String, dynamic>{};
              final title = context.isEnglish
                  ? (_englishBadges[id]?['title'] ?? id)
                  : (meta['title'] ?? id).toString();
              final desc = context.isEnglish
                  ? (_englishBadges[id]?['desc'] ?? '')
                  : (meta['desc'] ?? '').toString();
              final isUnlocked = unlocked.contains(id);

              return Opacity(
                opacity: isUnlocked ? 1 : 0.45,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isUnlocked
                          ? cs.secondary.withOpacity(0.55)
                          : cs.outline.withOpacity(0.7),
                      width: isUnlocked ? 1.3 : 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x11000000),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isUnlocked
                              ? cs.secondary.withOpacity(0.12)
                              : cs.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: cs.outline.withOpacity(0.7),
                          ),
                        ),
                        child: Icon(
                          isUnlocked
                              ? Icons.check_circle_rounded
                              : Icons.lock_rounded,
                          color: isUnlocked
                              ? cs.secondary
                              : cs.onSurface.withOpacity(0.55),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: cs.onSurface,
                                fontSize: 15,
                              ),
                            ),
                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                desc,
                                style: TextStyle(
                                  color: cs.onSurface.withOpacity(0.65),
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

const Map<String, Map<String, String>> _englishBadges = {
  'first_quiz': {
    'title': 'First quiz',
    'desc': 'You completed your first quiz.',
  },
  'first_simulation': {
    'title': 'First simulation',
    'desc': 'You completed your first simulation.',
  },
  'streak_3': {
    'title': '3-day streak',
    'desc': '3 consecutive days in the app.',
  },
  'streak_7': {
    'title': '7-day streak',
    'desc': '7 consecutive days in the app.',
  },
  'streak_30': {
    'title': '30-day streak',
    'desc': '30 consecutive days in the app.',
  },
  'quiz_10': {
    'title': '10 quizzes completed',
    'desc': 'You completed 10 quizzes.',
  },
  'simu_5': {'title': '5 simulations', 'desc': 'You completed 5 simulations.'},
  'first_lesson': {
    'title': 'First lesson',
    'desc': 'You completed your first lesson block.',
  },
  'perfect_quiz': {
    'title': 'Perfect score',
    'desc': 'You scored 100% on a quiz.',
  },
  'quiz_25': {'title': 'Quiz expert', 'desc': 'You completed 25 quizzes.'},
  'simu_10': {
    'title': 'Expert in action',
    'desc': 'You completed 10 simulations.',
  },
  'oral_90': {
    'title': 'Outstanding interview',
    'desc': 'You scored at least 90 in a simulation.',
  },
  'xp_500': {
    'title': '500 XP milestone',
    'desc': 'You reached your first major milestone.',
  },
  'xp_1500': {'title': 'Proven proficiency', 'desc': 'You reached 1,500 XP.'},
  'streak_14': {
    'title': '14-day streak',
    'desc': 'Two weeks of consistent practice.',
  },
  'challenge_winner': {
    'title': 'Challenge completed',
    'desc': 'You completed a special challenge.',
  },
  'assistant_10': {
    'title': 'Professional curiosity',
    'desc': 'You used the learning coach on 10 different topics.',
  },
};
