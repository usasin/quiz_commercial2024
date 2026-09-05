import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../toolbox_page.dart';
import '../services/localized_firestore.dart';
import 'lessons_screen.dart';
import 'quiz_screen.dart';
import 'custom_bottom_nav_bar.dart';

// 🎨 Palette CIP
const cipBlue = Color(0xFF5AACDB);
const cipGreen = Color(0xFF3CC398);
const cipPeach = Color(0xFFFBA49B);

class LearnPage extends StatelessWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Apprendre'),
          centerTitle: true,
          backgroundColor: cipBlue,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Aucun utilisateur connecté.\n\nConnecte-toi pour voir ta progression.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        bottomNavigationBar: const CustomBottomNavBar(currentIndex: 1),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apprendre'),
        centerTitle: true,
        backgroundColor: cipBlue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), cipBlue],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, userSnap) {
              final userData = userSnap.data?.data() ?? {};
              final levelsResults =
                  (userData['levelsResults'] as Map<String, dynamic>?) ?? {};

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('chapters')
                    .orderBy('order')
                    .snapshots(),
                builder: (context, chapSnap) {
                  if (chapSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (chapSnap.hasError) {
                    return Center(
                      child: Text(
                        'Erreur de chargement : ${chapSnap.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final chapters = chapSnap.data?.docs ?? [];
                  if (chapters.isEmpty) {
                    return const Center(
                      child: Text(
                        'Aucun module trouvé dans la base de données.',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  // 🔢 Calcul des % par chapitre
                  final chapterPercents = <String, int>{};
                  for (final doc in chapters) {
                    final chapId = doc.id;
                    final data = doc.data();
                    final modulesCount = (data['numberOfModules'] as int?) ?? 0;

                    final p = _computeChapterProgress(
                      chapId,
                      levelsResults,
                      modulesCount,
                    );
                    chapterPercents[chapId] = p;
                  }

                  const unlockThreshold = 80;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 💬 Bandeau explicatif
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: cipPeach.withOpacity(0.35),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.school_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Lis les leçons, puis valide les niveaux pour chaque module de ton script de vente.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ✅ AJOUT : Boîte à outils
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ToolboxPage(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cipGreen.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.10),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.menu_book_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Boîte à outils CIP",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        "Acteurs • Dispositifs • Glossaire • Réflexes territoire",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white70,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 📚 Liste des chapitres + modules
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: chapters.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final chapter = chapters[index];
                            final data = LocalizedFirestore.data(
                              context,
                              chapter.data(),
                            );

                            final chapId = chapter.id;
                            final chapPercent = chapterPercents[chapId] ?? 0;

                            bool unlocked;
                            if (index == 0) {
                              unlocked = true;
                            } else {
                              final prevChapId = chapters[index - 1].id;
                              final prevPercent =
                                  chapterPercents[prevChapId] ?? 0;
                              unlocked = prevPercent >= unlockThreshold;
                            }

                            return _ChapterCard(
                              chapterId: chapId,
                              title: data['title'] ?? 'Chapitre',
                              description: data['description'] ?? '',
                              levelsResults: levelsResults,
                              chapterPercent: chapPercent,
                              unlocked: unlocked,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 1),
    );
  }

  int _computeChapterProgress(
    String chapterId,
    Map<String, dynamic> levelsResults,
    int modulesCount,
  ) {
    const int levelsPerModule = 3;

    if (modulesCount <= 0) return 0;

    final int totalSlots = modulesCount * levelsPerModule;
    if (totalSlots <= 0) return 0;

    int completedSlots = 0;

    levelsResults.forEach((key, value) {
      if (!key.toString().startsWith('$chapterId::')) return;

      if (value is Map<String, dynamic>) {
        final p = (value['bestPercent'] as num?)?.toInt() ?? 0;
        if (p >= 80) {
          completedSlots++;
        }
      }
    });

    if (completedSlots <= 0) return 0;

    final percent = ((completedSlots / totalSlots) * 100).round();
    return percent.clamp(0, 100);
  }
}

class _ChapterCard extends StatelessWidget {
  final String chapterId;
  final String title;
  final String description;
  final Map<String, dynamic> levelsResults;
  final int chapterPercent;
  final bool unlocked;

  const _ChapterCard({
    required this.chapterId,
    required this.title,
    required this.description,
    required this.levelsResults,
    required this.chapterPercent,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: unlocked ? 1 : 0.5,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x15000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre + badge progression + lock
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? cipGreen.withOpacity(0.10)
                        : cipPeach.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                        size: 14,
                        color: unlocked ? cipGreen : cipPeach,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$chapterPercent%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: unlocked ? cipGreen : cipPeach,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (description.isNotEmpty)
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
              ),
            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chapters')
                  .doc(chapterId)
                  .collection('modules')
                  .orderBy('title')
                  .snapshots(),
              builder: (context, modSnap) {
                if (modSnap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: LinearProgressIndicator(),
                  );
                }

                if (modSnap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Erreur modules : ${modSnap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final modules = modSnap.data?.docs ?? [];
                if (modules.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Aucun module dans ce chapitre.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return Column(
                  children: modules.map((mod) {
                    final modData = LocalizedFirestore.data(
                      context,
                      mod.data(),
                    );
                    final moduleId = mod.id;
                    return _ModuleCard(
                      chapterId: chapterId,
                      moduleId: moduleId,
                      title: modData['title'] ?? 'Module',
                      description: modData['description'] ?? '',
                      levelsResults: levelsResults,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String chapterId;
  final String moduleId;
  final String title;
  final String description;
  final Map<String, dynamic> levelsResults;

  const _ModuleCard({
    required this.chapterId,
    required this.moduleId,
    required this.title,
    required this.description,
    required this.levelsResults,
  });

  int _bestForLevel(int level) {
    final key = '$chapterId::$moduleId::$level';
    final entry = levelsResults[key] as Map<String, dynamic>?;

    return (entry?['bestPercent'] as num?)?.toInt() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final best1 = _bestForLevel(1);
    final best2 = _bestForLevel(2);
    final best3 = _bestForLevel(3);

    final level1Unlocked = true;
    final level2Unlocked = best1 >= 80;
    final level3Unlocked = best2 >= 80;

    final moduleProgress = ((best1 + best2 + best3) / 3.0).round().clamp(
      0,
      100,
    );
    final fullyCompleted = best1 >= 80 && best2 >= 80 && best3 >= 80;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: fullyCompleted ? cipGreen : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre + badge terminé
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
              if (fullyCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cipGreen.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: cipGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Terminé',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cipGreen,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (description.isNotEmpty)
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6B7280),
              ),
            ),

          const SizedBox(height: 8),

          // Barre progression
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: moduleProgress / 100.0,
              minHeight: 5,
              backgroundColor: Colors.grey.shade200,
              color: fullyCompleted ? cipGreen : cipBlue,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progression',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
              ),
              Text(
                '$moduleProgress%',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: fullyCompleted ? cipGreen : cipBlue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Bouton Apprendre
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cipBlue,
                    side: BorderSide(color: cipBlue.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: const Text(
                    'Apprendre',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Niveaux
          Row(
            children: [
              _levelChip(
                context,
                label: 'Niveau 1',
                unlocked: level1Unlocked,
                percent: best1,
                onTap: level1Unlocked
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizScreen(
                              chapterId: chapterId,
                              moduleId: moduleId,
                              level: 1,
                              onLevelCompleted: () {},
                            ),
                          ),
                        );
                      }
                    : null,
              ),
              const SizedBox(width: 8),
              _levelChip(
                context,
                label: 'Niveau 2',
                unlocked: level2Unlocked,
                percent: best2,
                onTap: level2Unlocked
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizScreen(
                              chapterId: chapterId,
                              moduleId: moduleId,
                              level: 2,
                              onLevelCompleted: () {},
                            ),
                          ),
                        );
                      }
                    : null,
              ),
              const SizedBox(width: 8),
              _levelChip(
                context,
                label: 'Niveau 3',
                unlocked: level3Unlocked,
                percent: best3,
                onTap: level3Unlocked
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizScreen(
                              chapterId: chapterId,
                              moduleId: moduleId,
                              level: 3,
                              onLevelCompleted: () {},
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            ],
          ),

          // 🔁 Bouton RÉVISION
          if (fullyCompleted) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(
                        chapterId: chapterId,
                        moduleId: moduleId,
                        level: 3,
                        onLevelCompleted: () {},
                        isRevision: true,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple.shade800,
                  side: BorderSide(color: Colors.purple.shade200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  backgroundColor: Colors.purple.shade50,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Révision • Mix des levels du module',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _levelChip(
    BuildContext context, {
    required String label,
    required bool unlocked,
    required int percent,
    required VoidCallback? onTap,
  }) {
    final locked = !unlocked;
    final colorBg = locked ? Colors.grey.shade200 : cipBlue.withOpacity(0.08);
    final colorBorder = locked
        ? Colors.grey.shade400
        : cipBlue.withOpacity(0.6);
    final iconColor = locked ? Colors.grey.shade500 : cipBlue;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: colorBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colorBorder),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  locked ? Icons.lock_rounded : Icons.play_arrow_rounded,
                  size: 16,
                  color: iconColor,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: locked
                        ? Colors.grey.shade600
                        : const Color(0xFF111827),
                  ),
                ),
                if (percent > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 11,
                      color: locked ? Colors.grey.shade500 : cipGreen,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
