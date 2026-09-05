import 'package:flutter/material.dart';

import '../services/engagement_service.dart';
import '../services/app_language.dart';

String _englishLevelTitle(int xp) {
  const titles = [
    'Discovery',
    'Apprentice',
    'Progressing',
    'Independent',
    'Proficient',
    'Job expert',
    'Track master',
  ];
  return titles[EngagementService.levelIndexForXp(xp)];
}

const Map<String, String> _englishBadgeTitles = {
  'first_quiz': 'First quiz',
  'first_simulation': 'First simulation',
  'first_lesson': 'First lesson',
  'perfect_quiz': 'Perfect score',
  'challenge_winner': 'Challenge completed',
  'assistant_10': 'Professional curiosity',
  'streak_3': '3-day streak',
  'streak_7': '7-day streak',
  'streak_14': '14-day streak',
  'streak_30': '30-day streak',
  'quiz_10': '10 quizzes completed',
  'quiz_25': 'Quiz expert',
  'simu_5': '5 simulations',
  'simu_10': 'Expert in action',
  'oral_90': 'Outstanding interview',
  'xp_500': '500 XP milestone',
  'xp_1500': 'Proven proficiency',
};

class ProgressionHubPage extends StatefulWidget {
  const ProgressionHubPage({super.key});

  @override
  State<ProgressionHubPage> createState() => _ProgressionHubPageState();
}

class _ProgressionHubPageState extends State<ProgressionHubPage> {
  late Future<_ProgressionData> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _future = _load();
  }

  Future<_ProgressionData> _load() async {
    await EngagementService.recordAppOpen();
    final xp = await EngagementService.getXpLocal();
    final streak = await EngagementService.getStreakCurrentLocal();
    final bestStreak = await EngagementService.getStreakBestLocal();
    final badges = await EngagementService.getBadgesLocal();
    final missions = await EngagementService.getMissionProgressLocal();
    return _ProgressionData(
      xp: xp,
      streak: streak,
      bestStreak: bestStreak,
      badges: badges,
      missions: missions,
    );
  }

  String _metricLabel(BuildContext context, String metric) {
    switch (metric) {
      case 'simulation':
        return context.bilingual(
          fr: 'simulations terminées',
          en: 'simulations completed',
        );
      case 'lesson':
        return context.bilingual(
          fr: 'blocs de leçons terminés',
          en: 'lesson blocks completed',
        );
      case 'assistant':
        return context.bilingual(
          fr: 'recherches utiles dans le coach pédagogique',
          en: 'useful searches with the learning coach',
        );
      case 'xp':
        return context.bilingual(fr: 'XP gagnés', en: 'XP earned');
      default:
        return context.bilingual(fr: 'quiz validés', en: 'quizzes completed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(context.bilingual(fr: 'Mon parcours', en: 'My journey')),
        actions: [
          IconButton(
            tooltip: context.bilingual(fr: 'Actualiser', en: 'Refresh'),
            onPressed: () => setState(_refresh),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<_ProgressionData>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            final levelIndex = EngagementService.levelIndexForXp(data.xp);
            final levelTitle = context.isEnglish
                ? _englishLevelTitle(data.xp)
                : EngagementService.levelTitleForXp(data.xp);
            final startXp = EngagementService.levelStartXp(data.xp);
            final nextXp = EngagementService.nextLevelXp(data.xp);
            final atMax = nextXp <= startXp;
            final levelProgress = atMax
                ? 1.0
                : ((data.xp - startXp) / (nextXp - startXp)).clamp(0.0, 1.0);
            final dailyProgress =
                (data.missions['dailyProgress'] as num?)?.toInt() ?? 0;
            final dailyGoal =
                (data.missions['dailyGoal'] as num?)?.toInt() ?? 3;
            final dailyBonusXp =
                (data.missions['dailyBonusXp'] as num?)?.toInt() ?? 25;
            final challenge = data.missions['challenge'] is Map
                ? Map<String, dynamic>.from(data.missions['challenge'] as Map)
                : <String, dynamic>{};
            final challengeEnabled = challenge['enabled'] == true;
            final challengeProgress =
                (data.missions['challengeProgress'] as num?)?.toInt() ?? 0;
            final challengeTarget = (challenge['target'] as num?)?.toInt() ?? 1;
            final challengeDone = data.missions['challengeCompleted'] == true;
            final unlockedBadges = data.badges.toList()..sort();

            return RefreshIndicator(
              onRefresh: () async {
                setState(_refresh);
                await _future;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 72),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.primary.withBlue(220)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withOpacity(.25),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.18),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${levelIndex + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    levelTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    context.bilingual(
                                      fr: '${data.xp} XP au total',
                                      en: '${data.xp} total XP',
                                    ),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(.82),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.workspace_premium_rounded,
                              color: Colors.amberAccent,
                              size: 32,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: levelProgress,
                            minHeight: 10,
                            backgroundColor: Colors.white.withOpacity(.2),
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.amberAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          atMax
                              ? context.bilingual(
                                  fr: 'Niveau maximum atteint',
                                  en: 'Maximum level reached',
                                )
                              : context.bilingual(
                                  fr: '${nextXp - data.xp} XP avant le prochain niveau',
                                  en: '${nextXp - data.xp} XP to the next level',
                                ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.local_fire_department_rounded,
                          value: context.bilingual(
                            fr: '${data.streak} j',
                            en: '${data.streak} d',
                          ),
                          label: context.bilingual(
                            fr: 'Série actuelle',
                            en: 'Current streak',
                          ),
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.emoji_events_rounded,
                          value: context.bilingual(
                            fr: '${data.bestStreak} j',
                            en: '${data.bestStreak} d',
                          ),
                          label: context.bilingual(
                            fr: 'Meilleure série',
                            en: 'Best streak',
                          ),
                          color: Colors.amber.shade800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.military_tech_rounded,
                          value: '${data.badges.length}',
                          label: 'Badges',
                          color: cs.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _MissionCard(
                    icon: Icons.today_rounded,
                    title: context.bilingual(
                      fr: 'Mission du jour',
                      en: 'Daily mission',
                    ),
                    description: context.bilingual(
                      fr: 'Réalise $dailyGoal activités : leçon, quiz, simulation ou recherche dans le coach.',
                      en: 'Complete $dailyGoal activities: lesson, quiz, simulation or coach search.',
                    ),
                    progress: dailyProgress,
                    target: dailyGoal,
                    bonusLabel: '+$dailyBonusXp XP',
                    completed: dailyProgress >= dailyGoal,
                    color: cs.secondary,
                  ),
                  if (challengeEnabled) ...[
                    const SizedBox(height: 12),
                    _MissionCard(
                      icon: Icons.bolt_rounded,
                      title: context.isEnglish
                          ? 'Special challenge'
                          : '${challenge['title'] ?? 'Défi spécial'}',
                      description: context.isEnglish
                          ? 'Complete this special challenge.\nGoal: $challengeTarget ${_metricLabel(context, '${challenge['metric']}')}.'
                          : '${challenge['description'] ?? ''}\nObjectif : $challengeTarget ${_metricLabel(context, '${challenge['metric']}')}.',
                      progress: challengeProgress,
                      target: challengeTarget,
                      bonusLabel: '+${challenge['bonusXp'] ?? 150} XP',
                      completed: challengeDone,
                      color: Colors.deepPurple,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.bilingual(
                            fr: 'Derniers badges',
                            en: 'Latest badges',
                          ),
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/badges'),
                        child: Text(
                          context.bilingual(fr: 'Tout voir', en: 'View all'),
                        ),
                      ),
                    ],
                  ),
                  if (unlockedBadges.isEmpty)
                    const _EmptyBadges()
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: unlockedBadges.reversed.take(5).map((id) {
                        final meta = EngagementService.badgeCatalog[id];
                        return Chip(
                          avatar: const Icon(
                            Icons.emoji_events_rounded,
                            size: 18,
                          ),
                          label: Text(
                            context.isEnglish
                                ? (_englishBadgeTitles[id] ?? id)
                                : (meta?['title'] ?? id),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/levels',
                      (route) => false,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      context.bilingual(
                        fr: 'Continuer mon entraînement',
                        en: 'Continue training',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/leaderboard'),
                    icon: const Icon(Icons.leaderboard_rounded),
                    label: Text(
                      context.bilingual(
                        fr: 'Voir le classement',
                        en: 'View leaderboard',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProgressionData {
  final int xp;
  final int streak;
  final int bestStreak;
  final Set<String> badges;
  final Map<String, dynamic> missions;

  const _ProgressionData({
    required this.xp,
    required this.streak,
    required this.bestStreak,
    required this.badges,
    required this.missions,
  });
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final int progress;
  final int target;
  final String bonusLabel;
  final bool completed;
  final Color color;

  const _MissionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
    required this.bonusLabel,
    required this.completed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final safeTarget = target <= 0 ? 1 : target;
    final value = (progress / safeTarget).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(.14),
                child: Icon(
                  completed ? Icons.check_rounded : icon,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  completed
                      ? context.bilingual(fr: 'GAGNÉ', en: 'EARNED')
                      : bonusLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(height: 1.35, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: color.withOpacity(.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${progress.clamp(0, safeTarget)} / $safeTarget',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBadges extends StatelessWidget {
  const _EmptyBadges();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_open_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.bilingual(
                fr: 'Valide ton premier quiz pour débloquer ton premier badge.',
                en: 'Complete your first quiz to unlock your first badge.',
              ),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
