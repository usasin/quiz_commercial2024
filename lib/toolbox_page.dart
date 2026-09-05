import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/custom_bottom_nav_bar.dart';
import 'services/localized_firestore.dart';
import 'services/active_track_service.dart';
import 'services/app_language.dart';
import '../widgets/cip_page_header.dart';
import '../widgets/cip_widgets.dart';

// 🎨 Palette (si tu veux, tu peux ensuite remplacer par ton Theme/CipColors)
const cipBlue = Color(0xFF5AACDB);
const cipGreen = Color(0xFF3CC398);
const cipPeach = Color(0xFFFBA49B);

class ToolboxPage extends StatelessWidget {
  final String? trackId;

  const ToolboxPage({super.key, this.trackId});

  String _titleForTrack(BuildContext context, String track) {
    switch (track) {
      case 'cip':
        return context.bilingual(fr: 'Boîte à outils CIP', en: 'CIP toolbox');
      case 'sales':
      case 'agent':
        return context.bilingual(
          fr: 'Boîte à outils Agent de comptoir',
          en: 'Rental Desk Agent toolbox',
        );
      case 'ntc':
        return context.bilingual(fr: 'Boîte à outils NTC', en: 'NTC toolbox');
      default:
        return context.bilingual(fr: 'Boîte à outils', en: 'Toolbox');
    }
  }

  void _safeBack(BuildContext context) {
    // ✅ Evite l'écran noir si la page a été ouverte via pushReplacementNamed
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/levels', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      // ✅ AppBar vide (comme tes autres pages)
      appBar: CipAppBar(onBackPressed: () => _safeBack(context)),
      body: CipDigitalBackground(
        child: SafeArea(
          top: false,
          child: user == null
              ? Column(
                  children: [
                    CipPageHeader(
                      moduleTitle: context.bilingual(
                        fr: 'BOÎTE À OUTILS',
                        en: 'TOOLBOX',
                      ),
                      pageTitle: context.bilingual(
                        fr: 'Connexion requise',
                        en: 'Sign-in required',
                      ),
                      moduleTitleColor: cs.tertiary,
                      subtitle: Text(
                        context.bilingual(
                          fr: 'Connecte-toi pour accéder à la boîte à outils.',
                          en: 'Sign in to access the toolbox.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            context.bilingual(
                              fr: 'Connecte-toi pour accéder à la boîte à outils.',
                              en: 'Sign in to access the toolbox.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : FutureBuilder<String>(
                  future: ActiveTrackService.resolve(
                    requestedTrackId: trackId,
                    fallback: 'sales',
                  ),
                  builder: (context, trackSnap) {
                    if (trackSnap.hasError) {
                      return Column(
                        children: [
                          CipPageHeader(
                            moduleTitle: context.bilingual(
                              fr: 'BOÎTE À OUTILS',
                              en: 'TOOLBOX',
                            ),
                            pageTitle: context.bilingual(
                              fr: 'Erreur',
                              en: 'Error',
                            ),
                            moduleTitleColor: cs.tertiary,
                            subtitle: Text(
                              context.bilingual(
                                fr: 'Erreur Firestore sur le profil utilisateur.',
                                en: 'Firestore error on the user profile.',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                context.bilingual(
                                  fr: 'Erreur Firestore sur le profil utilisateur.',
                                  en: 'Firestore error on the user profile.',
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    if (trackSnap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final activeTrack = trackSnap.data ?? 'sales';

                    return Column(
                      children: [
                        // ✅ Header CIP (comme d’hab)
                        CipPageHeader(
                          moduleTitle: context.bilingual(
                            fr: 'BOÎTE À OUTILS',
                            en: 'TOOLBOX',
                          ),
                          pageTitle: _titleForTrack(context, activeTrack),
                          moduleTitleColor: cs.tertiary,
                          subtitle: Text(
                            context.bilingual(
                              fr: 'Méthodes • Scripts • Grilles • Réflexes\nTape un mot-clé pour retrouver vite.',
                              en: 'Methods • Scripts • Checklists • Key habits\nEnter a keyword to find content quickly.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        Expanded(
                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('toolbox_categories')
                                .where('track', isEqualTo: activeTrack)
                                .snapshots(),
                            builder: (context, snap) {
                              if (snap.hasError) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      context.bilingual(
                                        fr: 'Erreur Firestore. Vérifie les règles et la connexion.',
                                        en: 'Firestore error. Check the rules and your connection.',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: cs.onSurface.withOpacity(0.8),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final docs = [...(snap.data?.docs ?? [])];
                              docs.sort((a, b) {
                                final ao =
                                    (a.data()['order'] as num?)?.toInt() ?? 999;
                                final bo =
                                    (b.data()['order'] as num?)?.toInt() ?? 999;
                                return ao.compareTo(bo);
                              });
                              if (docs.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      '${context.bilingual(fr: 'Aucune catégorie trouvée pour le parcours', en: 'No category found for track')}: "$activeTrack".',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: cs.onSurface.withOpacity(0.8),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return DefaultTabController(
                                length: docs.length,
                                child: Column(
                                  children: [
                                    // ✅ TabBar RECTANGLE + sélection sur toute la case
                                    Container(
                                      margin: const EdgeInsets.fromLTRB(
                                        14,
                                        6,
                                        14,
                                        10,
                                      ),
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.85),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.black.withOpacity(0.06),
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x22000000),
                                            blurRadius: 18,
                                            offset: Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: TabBar(
                                        isScrollable: true,
                                        dividerColor: Colors.transparent,
                                        indicator: BoxDecoration(
                                          color: cipGreen.withOpacity(0.26),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: cipGreen.withOpacity(0.45),
                                          ),
                                        ),
                                        labelColor: Colors.black87,
                                        unselectedLabelColor: Colors.black45,
                                        labelStyle: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                        unselectedLabelStyle: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                        labelPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                            ),
                                        tabs: docs.map((d) {
                                          final localized =
                                              LocalizedFirestore.data(
                                                context,
                                                d.data(),
                                              );
                                          final title =
                                              (localized['title'] ?? d.id)
                                                  .toString();
                                          return Tab(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 10,
                                                  ),
                                              alignment: Alignment.center,
                                              child: Text(title),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),

                                    Expanded(
                                      child: TabBarView(
                                        children: docs
                                            .map(
                                              (d) => _ToolboxCategoryView(
                                                categoryRef: d.reference,
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
      // ✅ garde si tu veux la bottom bar ici (sinon tu peux l’enlever)
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 1),
    );
  }
}

class _ToolboxCategoryView extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> categoryRef;
  const _ToolboxCategoryView({required this.categoryRef});

  @override
  State<_ToolboxCategoryView> createState() => _ToolboxCategoryViewState();
}

class _ToolboxCategoryViewState extends State<_ToolboxCategoryView> {
  String _query = '';

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    final c = raw['content'];
    if (c is Map) return {...raw, ...Map<String, dynamic>.from(c)};
    return raw;
  }

  String _s(dynamic v) => (v == null) ? '' : v.toString();

  List<String> _list(dynamic v) {
    if (v == null) return const [];
    if (v is List)
      return v.map((e) => _s(e)).where((e) => e.trim().isNotEmpty).toList();
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? const [] : [t];
    }
    return const [];
  }

  String _mainText(Map<String, dynamic> d) {
    final content = _s(d['content']).trim();
    if (content.isNotEmpty) return content;

    final summary = _s(d['summary']).trim();
    if (summary.isNotEmpty) return summary;

    final desc = _s(d['description']).trim();
    return desc;
  }

  bool _hasAnyContent(Map<String, dynamic> d) {
    if (_mainText(d).trim().isNotEmpty) return true;
    return _list(d['details']).isNotEmpty ||
        _list(d['reflexes']).isNotEmpty ||
        _list(d['questions']).isNotEmpty ||
        _list(d['examples']).isNotEmpty ||
        _list(d['vigilances']).isNotEmpty;
  }

  String _searchBlob(Map<String, dynamic> d) {
    final parts = <String>[
      _s(d['title']),
      _s(d['summary']),
      _s(d['content']),
      _s(d['description']),
      ..._list(d['tags']),
      ..._list(d['keywords']),
      ..._list(d['details']),
      ..._list(d['reflexes']),
      ..._list(d['questions']),
      ..._list(d['examples']),
      ..._list(d['vigilances']),
    ];
    return parts.join(' ').toLowerCase();
  }

  String _formatUpdatedAt(Map<String, dynamic> d) {
    final ts = d['updatedAt'];
    if (ts is Timestamp) {
      final dt = ts.toDate().toLocal();
      String p2(int n) => n.toString().padLeft(2, '0');
      return "${p2(dt.day)}/${p2(dt.month)}/${dt.year} ${p2(dt.hour)}:${p2(dt.minute)}";
    }
    return '';
  }

  BoxDecoration _card3dDecoration() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.92),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.black.withOpacity(0.08)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 18,
          offset: Offset(0, 12),
        ),
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ],
    );
  }

  Widget _chips(List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.take(12).map((t) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: cipPeach.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: cipPeach.withOpacity(0.35)),
            ),
            child: Text(
              t,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _openItem(BuildContext context, Map<String, dynamic> d) {
    final data = _normalize(d);

    final title = _s(data['title']).trim();
    final main = _mainText(data);

    final details = _list(data['details']);
    final reflexes = _list(data['reflexes']);
    final questions = _list(data['questions']);
    final examples = _list(data['examples']);
    final vigilances = _list(data['vigilances']);

    final updated = _formatUpdatedAt(data);

    Widget section(String label, IconData icon, List<String> lines) {
      if (lines.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: cipGreen),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...lines.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "• ",
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.55),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        t,
                        style: const TextStyle(
                          color: Colors.black54,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.86,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.black.withOpacity(0.08)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 22,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: ListView(
                  controller: controller,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title.isEmpty
                          ? context.bilingual(fr: 'Sans titre', en: 'Untitled')
                          : title,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (updated.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${context.bilingual(fr: 'Mis à jour', en: 'Updated')}: $updated',
                          style: const TextStyle(
                            color: Colors.black38,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    if (main.trim().isNotEmpty)
                      Text(
                        main,
                        style: const TextStyle(
                          color: Colors.black54,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    section(
                      context.bilingual(fr: 'Détails', en: 'Details'),
                      Icons.notes,
                      details,
                    ),
                    section(
                      context.bilingual(fr: 'Réflexes', en: 'Key habits'),
                      Icons.flash_on_outlined,
                      reflexes,
                    ),
                    section('Questions', Icons.help_outline, questions),
                    section(
                      context.bilingual(fr: 'Exemples', en: 'Examples'),
                      Icons.lightbulb_outline,
                      examples,
                    ),
                    section(
                      context.bilingual(fr: 'Vigilances', en: 'Watch-outs'),
                      Icons.warning_amber_outlined,
                      vigilances,
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        label: Text(
                          context.bilingual(fr: 'Fermer', en: 'Close'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cipGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        children: [
          Container(
            decoration: _card3dDecoration(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                hintText: context.bilingual(
                  fr: 'Rechercher (mots-clés, titre, contenu...)',
                  en: 'Search (keywords, title, content…)',
                ),
                hintStyle: const TextStyle(
                  color: Colors.black45,
                  fontWeight: FontWeight.w700,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.black45),
                filled: true,
                fillColor: Colors.white.withOpacity(0.95),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: cipGreen, width: 1.3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.categoryRef
                  .collection('items')
                  .orderBy('title')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      context.bilingual(
                        fr: 'Erreur Firestore sur les items.\n(Indice : index / règles / champs manquants)',
                        en: 'Firestore error on items.\n(Hint: index / rules / missing fields)',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snap.data?.docs ?? [];
                final filtered = items.where((doc) {
                  if (_query.isEmpty) return true;
                  final data = _normalize(
                    LocalizedFirestore.data(context, doc.data()),
                  );
                  return _searchBlob(data).contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty
                          ? context.bilingual(
                              fr: 'Aucun élément dans cette catégorie.',
                              en: 'No items in this category.',
                            )
                          : '${context.bilingual(fr: 'Aucun résultat pour', en: 'No results for')} "$_query"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final doc = filtered[i];
                    final data = _normalize(
                      LocalizedFirestore.data(context, doc.data()),
                    );

                    final title = _s(data['title']).trim();
                    final summary = _s(data['summary']).trim();
                    final tags = _list(data['tags']);
                    final canOpen = _hasAnyContent(data);

                    return InkWell(
                      onTap: canOpen ? () => _openItem(context, data) : null,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        decoration: _card3dDecoration(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title.isEmpty ? "Sans titre" : title,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Icon(
                                  canOpen
                                      ? Icons.chevron_right_rounded
                                      : Icons.lock_outline,
                                  color: Colors.black38,
                                ),
                              ],
                            ),
                            if (summary.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                summary,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            _chips(tags),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
