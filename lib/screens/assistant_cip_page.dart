import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/engagement_service.dart';
import '../services/active_track_service.dart';
import '../services/localized_firestore.dart';

/// Assistant pédagogique multi-diplôme.
///
/// Le nom historique est conservé pour ne pas casser les routes existantes,
/// mais le contenu, les suggestions et les réponses sont isolés par track.
class AssistantCipPage extends StatefulWidget {
  final String? trackId;

  const AssistantCipPage({super.key, this.trackId});

  @override
  State<AssistantCipPage> createState() => _AssistantCipPageState();
}

class _AssistantCipPageState extends State<AssistantCipPage> {
  final _question = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final List<_KnowledgeItem> _knowledge = [];

  List<_KnowledgeResult> _results = const [];
  List<String> _suggestions = const [];
  bool _loading = true;
  bool _searched = false;
  String? _error;
  String _trackId = 'cip';
  String _trackTitle = 'CIP';
  String _assistantTitle = 'Assistant CIP';
  String _assistantSubtitle =
      'Réponses gratuites basées sur les leçons et les fiches du parcours.';

  static const _cipSuggestions = <String>[
    'Comment poser le cadre et parler de confidentialité ?',
    'Comment construire un diagnostic partagé ?',
    'Que doit contenir une synthèse professionnelle ?',
    'Comment répondre aux questions du jury ?',
    'Comment accompagner un projet professionnel ?',
    'Quels partenaires mobiliser sur le territoire ?',
  ];

  static const _ntcSuggestions = <String>[
    'Comment construire un plan d’actions commerciales ?',
    'Comment préparer un appel de prospection B2B ?',
    'Comment analyser un tableau de bord commercial ?',
    'Comment rédiger une proposition technique et commerciale ?',
    'Comment traiter une objection sans baisser immédiatement le prix ?',
    'Comment préparer la négociation et les questions du jury NTC ?',
  ];

  static const _stopWords = <String>{
    'alors',
    'avec',
    'avoir',
    'cette',
    'comment',
    'dans',
    'des',
    'elle',
    'est',
    'faire',
    'faut',
    'les',
    'mais',
    'mes',
    'mon',
    'nous',
    'par',
    'pas',
    'peut',
    'pour',
    'que',
    'quel',
    'quelle',
    'qui',
    'quoi',
    'sans',
    'ses',
    'son',
    'sur',
    'une',
    'vous',
    'aux',
    'être',
    'doit',
    'dois',
  };

  @override
  void initState() {
    super.initState();
    _loadKnowledge();
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<String> _resolveTrackId() async {
    return ActiveTrackService.resolve(
      requestedTrackId: widget.trackId,
      fallback: 'cip',
    );
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _loadTrackPresentation() async {
    final trackDoc = await _firestore.collection('tracks').doc(_trackId).get();
    final data = LocalizedFirestore.data(
      context,
      trackDoc.data() ?? <String, dynamic>{},
    );
    final assistant = _map(data['assistant']);

    _trackTitle = (data['shortTitle'] ?? data['title'] ?? _trackId).toString();
    _assistantTitle =
        (assistant['title'] ??
                (_trackId == 'ntc'
                    ? 'Coach Commercial NTC'
                    : 'Assistant $_trackTitle'))
            .toString();
    _assistantSubtitle =
        (assistant['subtitle'] ??
                'Réponses gratuites basées uniquement sur le parcours $_trackTitle.')
            .toString();
    _suggestions = _strings(assistant['suggestions']);
    if (_suggestions.isEmpty) {
      _suggestions = _trackId == 'ntc' ? _ntcSuggestions : _cipSuggestions;
    }
  }

  Future<void> _loadLessons() async {
    final chapters = await _firestore
        .collection('chapters')
        .where('track', isEqualTo: _trackId)
        .get();

    for (final chapter in chapters.docs) {
      final modules = await chapter.reference.collection('modules').get();
      final lessonSnapshots = await Future.wait(
        modules.docs.map(
          (module) => module.reference.collection('lessons').get(),
        ),
      );
      for (final lessons in lessonSnapshots) {
        for (final doc in lessons.docs) {
          final data = LocalizedFirestore.data(context, doc.data());
          final content = (data['content'] ?? '').toString().trim();
          if (content.isEmpty) continue;
          final example = _map(data['fieldExample']);
          final challenge = _map(data['challenge']);
          final jury = _map(data['jury']);
          final enrichedParts = <String>[
            content,
            ..._strings(data['learningObjectives']),
            ..._strings(data['keyPoints']),
            ..._strings(data['checklist']),
            (example['context'] ?? '').toString(),
            (example['expertApproach'] ?? '').toString(),
            (example['debrief'] ?? '').toString(),
            (challenge['prompt'] ?? '').toString(),
            (challenge['modelAnswer'] ?? '').toString(),
            (jury['question'] ?? '').toString(),
            (jury['modelAnswer'] ?? '').toString(),
            (data['memoryTip'] ?? '').toString(),
          ].where((value) => value.trim().isNotEmpty).toList();
          _knowledge.add(
            _KnowledgeItem(
              title: (data['title'] ?? 'Leçon').toString().trim(),
              content: enrichedParts.join('\n\n'),
              kind: 'Leçon • $_trackTitle',
              path: doc.reference.path,
            ),
          );
        }
      }
    }
  }

  Future<void> _loadToolbox() async {
    final categories = await _firestore
        .collection('toolbox_categories')
        .where('track', isEqualTo: _trackId)
        .get();

    final itemSnapshots = await Future.wait(
      categories.docs.map(
        (category) => category.reference.collection('items').get(),
      ),
    );
    for (final items in itemSnapshots) {
      for (final doc in items.docs) {
        final data = LocalizedFirestore.data(context, doc.data());
        final parts = <String>[
          (data['summary'] ?? '').toString(),
          (data['content'] ?? '').toString(),
          ..._strings(data['details']),
          ..._strings(data['reflexes']),
          ..._strings(data['vigilances']),
          ..._strings(data['examples']),
        ].where((value) => value.trim().isNotEmpty).toList();
        if (parts.isEmpty) continue;
        _knowledge.add(
          _KnowledgeItem(
            title: (data['title'] ?? 'Fiche pratique').toString().trim(),
            content: parts.join('\n\n'),
            kind: 'Boîte à outils • $_trackTitle',
            path: doc.reference.path,
          ),
        );
      }
    }
  }

  Future<void> _loadKnowledge() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _searched = false;
        _results = const [];
      });
    }
    _knowledge.clear();
    var unavailableSources = 0;

    try {
      _trackId = await _resolveTrackId();
      await _loadTrackPresentation();
    } catch (_) {
      unavailableSources++;
      _suggestions = _trackId == 'ntc' ? _ntcSuggestions : _cipSuggestions;
    }

    try {
      await _loadLessons();
    } catch (error) {
      unavailableSources++;
      debugPrint('Assistant $_trackId — leçons indisponibles: $error');
    }

    try {
      await _loadToolbox();
    } catch (error) {
      unavailableSources++;
      debugPrint('Assistant $_trackId — boîte à outils indisponible: $error');
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = _knowledge.isEmpty
          ? 'Aucun contenu publié n’est encore disponible pour le parcours $_trackTitle.'
          : null;
    });
    if (unavailableSources > 0 && _knowledge.isNotEmpty) {
      debugPrint(
        'Assistant $_trackId: une source pédagogique est indisponible.',
      );
    }
  }

  String _normalize(String value) {
    var text = value.toLowerCase();
    const accents = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'á': 'a',
      'ç': 'c',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'œ': 'oe',
    };
    accents.forEach((from, to) => text = text.replaceAll(from, to));
    return text.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  }

  Set<String> _tokens(String value) => _normalize(value)
      .split(RegExp(r'\s+'))
      .where((word) => word.length >= 3 && !_stopWords.contains(word))
      .toSet();

  void _ask([String? suggested]) {
    if (suggested != null) _question.text = suggested;
    final query = _question.text.trim();
    if (query.length < 3) return;
    FocusScope.of(context).unfocus();

    final queryTokens = _tokens(query);
    final normalizedQuery = _normalize(query).trim();
    final scored = <_KnowledgeResult>[];
    for (final item in _knowledge) {
      final normalizedTitle = _normalize(item.title);
      final normalizedContent = _normalize(item.content);
      final titleTokens = _tokens(item.title);
      final contentTokens = _tokens(item.content);
      var score = normalizedTitle.contains(normalizedQuery) ? 20 : 0;
      if (normalizedQuery.length > 8 &&
          normalizedContent.contains(normalizedQuery)) {
        score += 12;
      }
      for (final token in queryTokens) {
        if (titleTokens.contains(token)) score += 6;
        if (contentTokens.contains(token)) score += 3;
        if (normalizedContent.contains(token)) score += 1;
      }
      if (score > 0) scored.add(_KnowledgeResult(item, score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final results = scored.take(5).toList();
    setState(() {
      _searched = true;
      _results = results;
    });

    if (results.isNotEmpty) {
      final normalizedId =
          '${_trackId}_${_normalize(query).replaceAll(RegExp(r'\s+'), '_').trim()}';
      final activityId = normalizedId.length > 120
          ? normalizedId.substring(0, 120)
          : normalizedId;
      unawaited(EngagementService.recordAssistantUsed(activityId: activityId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_assistantTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.secondary],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.psychology_alt_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Une question ? Je cherche dans ton parcours.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _assistantSubtitle,
                    style: const TextStyle(color: Colors.white, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  const _FreeBadge(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _question,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _ask(),
              decoration: InputDecoration(
                hintText: _trackId == 'ntc'
                    ? 'Ex. Comment préparer une négociation B2B ?'
                    : 'Ex. Comment valider un diagnostic partagé ?',
                prefixIcon: const Icon(Icons.help_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Rechercher',
                  onPressed: _loading ? null : _ask,
                  icon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              const Center(child: Text('Préparation des réponses…')),
            ] else if (_error != null) ...[
              _MessageCard(icon: Icons.cloud_off_rounded, text: _error!),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _loadKnowledge,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ] else if (!_searched) ...[
              Text(
                '${_knowledge.length} ressources vérifiées • $_trackTitle',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Questions fréquentes',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 10),
              for (final suggestion in _suggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => _ask(suggestion),
                    icon: const Icon(Icons.bolt_rounded),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(suggestion),
                    ),
                  ),
                ),
            ] else if (_results.isEmpty) ...[
              _MessageCard(
                icon: Icons.travel_explore_rounded,
                text:
                    'Je n’ai pas trouvé de réponse précise dans le parcours $_trackTitle. Essaie une question plus courte avec le nom de la compétence.',
              ),
              const SizedBox(height: 14),
              const Text(
                'Tu peux aussi essayer',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              for (final suggestion in _suggestions.take(3))
                TextButton(
                  onPressed: () => _ask(suggestion),
                  child: Text(suggestion),
                ),
            ] else ...[
              Text(
                '${_results.length} réponse${_results.length > 1 ? 's' : ''} trouvée${_results.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              for (final result in _results) _ResultCard(result: result),
            ],
          ],
        ),
      ),
    );
  }
}

class _KnowledgeItem {
  final String title;
  final String content;
  final String kind;
  final String path;

  const _KnowledgeItem({
    required this.title,
    required this.content,
    required this.kind,
    required this.path,
  });
}

class _KnowledgeResult {
  final _KnowledgeItem item;
  final int score;

  const _KnowledgeResult(this.item, this.score);
}

class _ResultCard extends StatefulWidget {
  final _KnowledgeResult result;

  const _ResultCard({required this.result});

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final full = widget.result.item.content;
    final canExpand = full.length > 900;
    final content = canExpand && !_expanded
        ? '${full.substring(0, 900)}…'
        : full;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_stories_rounded, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.result.item.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(content, style: const TextStyle(height: 1.4)),
            if (canExpand)
              TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                label: Text(_expanded ? 'Réduire' : 'Lire la réponse complète'),
              ),
            const SizedBox(height: 6),
            Text(
              widget.result.item.kind,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeBadge extends StatelessWidget {
  const _FreeBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.18),
      borderRadius: BorderRadius.circular(999),
    ),
    child: const Text(
      'GRATUIT • 0 jeton IA',
      style: TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MessageCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    ),
  );
}
