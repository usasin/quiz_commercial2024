import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/cip_colors.dart';
import '../widgets/cip_widgets.dart';
import '../widgets/admob_banner.dart';
import '../services/engagement_service.dart';
import '../services/active_track_service.dart';
import '../services/admin_service.dart';
import '../services/app_language.dart';
import '../services/localized_firestore.dart';
import 'custom_bottom_nav_bar.dart' hide cipBlue, cipGreen;
import 'module_page.dart';

/// Palette COMMERCIAL (fallback si Firestore ne fournit pas de couleurs)
const commercialBlue = Color(0xFF2D6CDF);
const commercialGreen = Color(0xFF00B894);

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

class LevelsPage extends StatefulWidget {
  const LevelsPage({super.key});

  @override
  State<LevelsPage> createState() => _LevelsPageState();
}

class _LevelsPageState extends State<LevelsPage> {
  static const int unlockThreshold = 80;

  /// track sélectionné (vient de Firestore + users.activeTrack)
  String _selectedTrack = 'sales';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadActiveTrackIfLogged();
    EngagementService.recordAppOpen();
  }

  Future<void> _loadActiveTrackIfLogged() async {
    final track = await ActiveTrackService.resolve(fallback: _selectedTrack);
    final isAdmin = await AdminService.instance.isAdmin(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      if (track.isNotEmpty) _selectedTrack = track;
      _isAdmin = isAdmin;
    });
  }

  Future<void> _saveActiveTrackIfLogged(String track) async {
    await ActiveTrackService.select(track);
  }

  void _showLockedChapterInfo(BuildContext context, {required int threshold}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.bilingual(
            fr: "Chapitre verrouillé : termine le chapitre précédent à $threshold% pour le débloquer.",
            en: "Chapter locked: complete the previous chapter at $threshold% to unlock it.",
          ),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

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
                  color: cs.outline.withOpacity(0.6),
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
                  fr: "Connecte-toi pour sauvegarder ta progression et débloquer automatiquement les chapitres suivants.",
                  en: 'Sign in to save your progress and automatically unlock the next chapters.',
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
      final k = key.toString();
      if (!k.startsWith('$chapterId::')) return;

      if (value is Map<String, dynamic>) {
        final p = (value['bestPercent'] as num?)?.toInt() ?? 0;
        if (p >= unlockThreshold) completedSlots++;
      }
    });

    if (completedSlots <= 0) return 0;
    final percent = ((completedSlots / totalSlots) * 100).round();
    return percent.clamp(0, 100);
  }

  /// Convertit un champ Firestore en Color
  Color _colorFrom(dynamic v, Color fallback) {
    if (v is num) return Color(v.toInt());
    if (v is int) return Color(v);
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    final tracksStream = FirebaseFirestore.instance
        .collection('tracks')
        .orderBy('order')
        .snapshots();

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Prépa Boost"),
        actions: [
          const _LanguageMenu(),
          IconButton(
            tooltip: context.bilingual(fr: 'Examen blanc', en: 'Mock exam'),
            onPressed: () => Navigator.pushNamed(
              context,
              '/exam',
              arguments: {'trackId': _selectedTrack},
            ),
            icon: const Icon(Icons.school_rounded),
          ),
          IconButton(
            tooltip: context.bilingual(
              fr: 'Poser une question',
              en: 'Ask a question',
            ),
            onPressed: () => Navigator.pushNamed(
              context,
              '/assistant',
              arguments: {'trackId': _selectedTrack},
            ),
            icon: const Icon(Icons.psychology_alt_rounded),
          ),
          if (user == null)
            TextButton(
              onPressed: () => _askLogin(context),
              child: Text(context.bilingual(fr: 'Connexion', en: 'Sign in')),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: CipDigitalBackground(
        child: SafeArea(
          top: false,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: tracksStream,
            builder: (context, tracksSnap) {
              if (tracksSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (tracksSnap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.bilingual(
                        fr: "Erreur tracks: ${tracksSnap.error}\nVérifie la collection 'tracks'.",
                        en: "Track error: ${tracksSnap.error}\nCheck the 'tracks' collection.",
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }

              final trackDocs = (tracksSnap.data?.docs ?? const [])
                  .where((doc) => _isAdmin || doc.data()['adminOnly'] != true)
                  .toList(growable: false);
              if (trackDocs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.bilingual(
                        fr: "Aucun parcours trouvé.\nVérifie la collection 'tracks'.",
                        en: "No learning track found.\nCheck the 'tracks' collection.",
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onBackground.withOpacity(0.65),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }

              // Si le track sélectionné n’existe plus → fallback sur le 1er
              final trackIds = trackDocs.map((d) => d.id).toList();
              if (!trackIds.contains(_selectedTrack)) {
                _selectedTrack = trackIds.first;
              }

              // UI du track sélectionné
              final selectedDoc = trackDocs.firstWhere(
                (d) => d.id == _selectedTrack,
              );
              final tData = LocalizedFirestore.data(
                context,
                selectedDoc.data(),
              );

              final String title = (tData['title'] ?? _selectedTrack)
                  .toString();
              final String subtitle = (tData['subtitle'] ?? '').toString();
              final String badge = (tData['badge'] ?? '📚').toString();
              final Color c1 = _colorFrom(
                tData['color1'],
                (_selectedTrack == 'cip') ? cipBlue : commercialBlue,
              );
              final Color c2 = _colorFrom(
                tData['color2'],
                (_selectedTrack == 'cip') ? cipGreen : commercialGreen,
              );

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: user == null
                    ? null
                    : FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .snapshots(),
                builder: (context, userSnap) {
                  final userData = userSnap.data?.data() ?? {};
                  final levelsResults =
                      (userData['levelsResults'] as Map<String, dynamic>?) ??
                      {};
                  final engagement =
                      (userData['engagement'] as Map<String, dynamic>?) ?? {};

                  final chaptersStream = FirebaseFirestore.instance
                      .collection('chapters')
                      .where('track', isEqualTo: _selectedTrack)
                      .snapshots();

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: chaptersStream,
                    builder: (context, chapSnap) {
                      if (chapSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (chapSnap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              context.bilingual(
                                fr: 'Erreur : ${chapSnap.error}',
                                en: 'Error: ${chapSnap.error}',
                              ),
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final raw = chapSnap.data?.docs ?? [];
                      final chapters = [...raw];
                      chapters.sort((a, b) {
                        final ao = (a.data()['order'] is int)
                            ? (a.data()['order'] as int)
                            : int.tryParse('${a.data()['order']}') ?? 0;
                        final bo = (b.data()['order'] is int)
                            ? (b.data()['order'] as int)
                            : int.tryParse('${b.data()['order']}') ?? 0;
                        return ao.compareTo(bo);
                      });

                      if (chapters.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              context.bilingual(
                                fr: 'Aucun chapitre trouvé pour ce parcours.',
                                en: 'No chapter found for this learning track.',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: cs.onBackground.withOpacity(0.65),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }

                      final chapterPercents = <String, int>{};
                      for (final doc in chapters) {
                        final data = LocalizedFirestore.data(
                          context,
                          doc.data(),
                        );
                        final modulesCount = (data['numberOfModules'] is int)
                            ? (data['numberOfModules'] as int)
                            : int.tryParse('${data['numberOfModules']}') ?? 0;

                        chapterPercents[doc.id] = _computeChapterProgress(
                          doc.id,
                          levelsResults,
                          modulesCount,
                        );
                      }

                      final globalPercent =
                          (chapterPercents.values.fold<int>(
                                    0,
                                    (a, b) => a + b,
                                  ) /
                                  chapters.length)
                              .round()
                              .clamp(0, 100);

                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                if (user != null)
                                  _ProgressMissionStrip(
                                    xp:
                                        (engagement['xp'] as num?)?.toInt() ??
                                        0,
                                    streak:
                                        (engagement['streakCurrent'] as num?)
                                            ?.toInt() ??
                                        0,
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      '/progression',
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    14,
                                    16,
                                    8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.bilingual(
                                          fr: 'CHOISIR UN PARCOURS',
                                          en: 'CHOOSE A LEARNING TRACK',
                                        ),
                                        style: TextStyle(
                                          color: cs.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        child: Row(
                                          children: trackDocs.map((d) {
                                            final data =
                                                LocalizedFirestore.data(
                                                  context,
                                                  d.data(),
                                                );
                                            final id = d.id;
                                            final configuredShortTitle =
                                                (data['shortTitle'] ?? '')
                                                    .toString()
                                                    .trim();
                                            final label =
                                                configuredShortTitle.isNotEmpty
                                                ? configuredShortTitle
                                                : id == 'cip'
                                                ? 'CIP'
                                                : (data['title'] ?? id)
                                                      .toString();
                                            final icon = (data['badge'] ?? '📚')
                                                .toString();

                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: _TrackChip(
                                                selected: _selectedTrack == id,
                                                label: label,
                                                icon: icon,
                                                activeColor: cs.primary,
                                                onTap: () async {
                                                  setState(
                                                    () => _selectedTrack = id,
                                                  );
                                                  await _saveActiveTrackIfLogged(
                                                    id,
                                                  );
                                                },
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: _ActiveTrackSummary(
                                    title: title,
                                    subtitle: subtitle,
                                    badge: badge,
                                    percent: globalPercent,
                                    startColor: c1,
                                    endColor: c2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),

                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                            sliver: SliverList.separated(
                              itemCount: chapters.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final doc = chapters[index];
                                final data = LocalizedFirestore.data(
                                  context,
                                  doc.data(),
                                );

                                final chapId = doc.id;
                                final chapTitle =
                                    (data['title'] ??
                                            context.bilingual(
                                              fr: 'Chapitre',
                                              en: 'Chapter',
                                            ))
                                        .toString();
                                final desc = (data['description'] ?? '')
                                    .toString();
                                final percent = chapterPercents[chapId] ?? 0;

                                bool unlocked;
                                if (index == 0) {
                                  unlocked = true;
                                } else {
                                  final prevId = chapters[index - 1].id;
                                  final prevPercent =
                                      chapterPercents[prevId] ?? 0;
                                  unlocked = prevPercent >= unlockThreshold;
                                }

                                if (user == null) unlocked = index == 0;

                                return _ChapterCard(
                                  title: chapTitle,
                                  description: desc,
                                  percent: percent,
                                  unlocked: unlocked,
                                  onTap: unlocked
                                      ? () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ModulePage(
                                                chapterId: chapId,
                                                chapterTitle: chapTitle,
                                              ),
                                            ),
                                          );
                                        }
                                      : () {
                                          if (user == null) {
                                            _askLogin(context);
                                          } else {
                                            _showLockedChapterInfo(
                                              context,
                                              threshold: unlockThreshold,
                                            );
                                          }
                                        },
                                );
                              },
                            ),
                          ),

                          const SliverToBoxAdapter(child: SizedBox(height: 10)),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [AdmobBanner(), CustomBottomNavBar(currentIndex: 0)],
      ),
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu();

  @override
  Widget build(BuildContext context) {
    final currentLanguage = context.locale.languageCode;

    return PopupMenuButton<String>(
      tooltip: currentLanguage == 'en' ? 'Language' : 'Langue',
      initialValue: currentLanguage,
      onSelected: (languageCode) {
        if (languageCode != currentLanguage) {
          context.setLocale(Locale(languageCode));
        }
      },
      itemBuilder: (context) => [
        _item(
          languageCode: 'fr',
          label: 'Français',
          flag: '🇫🇷',
          selected: currentLanguage == 'fr',
        ),
        _item(
          languageCode: 'en',
          label: 'English',
          flag: '🇬🇧',
          selected: currentLanguage == 'en',
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.language_rounded),
            Text(
              currentLanguage.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _item({
    required String languageCode,
    required String label,
    required String flag,
    required bool selected,
  }) {
    return PopupMenuItem<String>(
      value: languageCode,
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          if (selected) const Icon(Icons.check_rounded, size: 20),
        ],
      ),
    );
  }
}

class _ProgressMissionStrip extends StatelessWidget {
  final int xp;
  final int streak;
  final VoidCallback onTap;

  const _ProgressMissionStrip({
    required this.xp,
    required this.streak,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: cs.primary.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.rocket_launch_rounded, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.isEnglish
                            ? _englishLevelTitle(xp)
                            : EngagementService.levelTitleForXp(xp),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        context.bilingual(
                          fr: '$xp XP • série de $streak jour${streak > 1 ? 's' : ''}',
                          en: '$xp XP • $streak-day streak',
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveTrackSummary extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final int percent;
  final Color startColor;
  final Color endColor;

  const _ActiveTrackSummary({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.percent,
    required this.startColor,
    required this.endColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: startColor.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.bilingual(fr: 'PARCOURS ACTIF', en: 'ACTIVE TRACK'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Text(badge, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$percent%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12.5,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent / 100.0,
              minHeight: 7,
              backgroundColor: Colors.white.withOpacity(0.22),
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withOpacity(0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackChip extends StatelessWidget {
  final bool selected;
  final String label;
  final String icon;
  final Color activeColor;
  final VoidCallback onTap;

  const _TrackChip({
    required this.selected,
    required this.label,
    required this.icon,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.68;

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 92, maxWidth: maxWidth),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? activeColor.withOpacity(0.12) : cs.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? activeColor.withOpacity(0.35) : cs.outline,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(selected ? 0.06 : 0.03),
                blurRadius: selected ? 14 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selected ? activeColor : cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final String title;
  final String description;
  final int percent;
  final bool unlocked;
  final VoidCallback onTap;

  const _ChapterCard({
    required this.title,
    required this.description,
    required this.percent,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = percent >= _LevelsPageState.unlockThreshold;

    final borderC = done ? cs.secondary : cs.outline;

    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderC.withOpacity(done ? 1 : 0.75),
              width: done ? 1.4 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: done
                      ? LinearGradient(colors: [cs.secondary, cs.tertiary])
                      : const LinearGradient(
                          colors: [Color(0xFFE0F2FE), Color(0xFFDBEAFE)],
                        ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: done ? Colors.white : cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                        fontSize: 15.5,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
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
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (percent.clamp(0, 100) / 100).toDouble(),
                        backgroundColor: cs.outline.withOpacity(0.35),
                        color: done ? cs.secondary : cs.primary,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percent%',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: done ? cs.secondary : cs.primary,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.35)),
            ],
          ),
        ),
      ),
    );
  }
}
