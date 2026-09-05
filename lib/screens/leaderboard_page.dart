import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/cip_page_header.dart';
import '../services/app_language.dart';
import 'custom_bottom_nav_bar.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  bool _isValidHttpUrl(String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty) return false;
    final uri = Uri.tryParse(u);
    if (uri == null) return false;
    // ✅ On accepte uniquement http/https avec host
    if (!(uri.scheme == 'http' || uri.scheme == 'https')) return false;
    if (uri.host.trim().isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: CipAppBar(onBackPressed: () => Navigator.pop(context)),
      body: Column(
        children: [
          CipPageHeader(
            moduleTitle: context.bilingual(fr: 'CLASSEMENT', en: 'LEADERBOARD'),
            pageTitle: 'Leaderboard',
            moduleTitleColor: cs.primary,
            subtitle: Text(
              context.bilingual(
                fr: 'XP • Série • Top entraînement',
                en: 'XP • Streak • Top training',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Container(
              color: cs.background,
              child: user == null
                  ? Center(
                      child: Text(
                        context.bilingual(
                          fr: 'Connecte-toi pour voir le classement.',
                          en: 'Sign in to view the leaderboard.',
                        ),
                        style: TextStyle(color: cs.onSurface.withOpacity(0.65)),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('leaderboard')
                          .orderBy('xp', descending: true)
                          .limit(50)
                          .snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snap.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                '${context.bilingual(fr: 'Erreur', en: 'Error')}: ${snap.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          );
                        }

                        final docs = snap.data?.docs ?? const [];
                        if (docs.isEmpty) {
                          return Center(
                            child: Text(
                              context.bilingual(
                                fr: 'Aucune donnée de classement pour le moment.',
                                en: 'No leaderboard data yet.',
                              ),
                              style: TextStyle(
                                color: cs.onSurface.withOpacity(0.65),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final d = docs[i].data();
                            final uid = (d['uid'] ?? docs[i].id).toString();
                            final name =
                                (d['name'] ??
                                        context.bilingual(
                                          fr: 'Utilisateur',
                                          en: 'User',
                                        ))
                                    .toString();

                            final rawPhoto = (d['photoUrl'] as String?);
                            final photoUrl = _isValidHttpUrl(rawPhoto)
                                ? rawPhoto!.trim()
                                : null;

                            final xp = (d['xp'] as num?)?.toInt() ?? 0;
                            final best =
                                (d['streakBest'] as num?)?.toInt() ?? 0;
                            final isMe = uid == user.uid;

                            return _LeaderTile(
                              rank: i + 1,
                              name: name,
                              xp: xp,
                              bestStreak: best,
                              photoUrl: photoUrl,
                              highlight: isMe,
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 2),
    );
  }
}

class _LeaderTile extends StatelessWidget {
  final int rank;
  final String name;
  final int xp;
  final int bestStreak;
  final String? photoUrl;
  final bool highlight;

  const _LeaderTile({
    required this.rank,
    required this.name,
    required this.xp,
    required this.bestStreak,
    required this.photoUrl,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bg = highlight ? cs.primary.withOpacity(0.08) : cs.surface;
    final border = highlight
        ? cs.primary.withOpacity(0.35)
        : cs.outline.withOpacity(0.7);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
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
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: [cs.primary, cs.secondary]),
            ),
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),

          CircleAvatar(
            radius: 18,
            backgroundColor: cs.primary.withOpacity(0.12),
            backgroundImage: (photoUrl != null)
                ? NetworkImage(photoUrl!)
                : null,
            child: (photoUrl == null)
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                    ),
                  )
                : null,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.bilingual(
                    fr: 'Série max : $bestStreak jours',
                    en: 'Best streak: $bestStreak days',
                  ),
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.65),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    );
  }
}
