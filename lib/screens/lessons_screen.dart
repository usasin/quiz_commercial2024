import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/cip_page_header.dart';
import 'quiz_screen.dart';
import '../services/engagement_service.dart';
import '../services/localized_firestore.dart';
import '../services/app_language.dart';
import 'custom_bottom_nav_bar.dart';

class LessonsScreen extends StatefulWidget {
  final String chapterId;
  final String moduleId;
  final String moduleTitle;
  final bool unlocked;

  const LessonsScreen({
    super.key,
    required this.chapterId,
    required this.moduleId,
    required this.moduleTitle,
    this.unlocked = true,
  });

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  final FlutterTts _tts = FlutterTts();
  String? _speakingLessonId;
  String? _ttsLanguageCode;

  @override
  void initState() {
    super.initState();
    _tts.setSpeechRate(.46);
    _tts.setPitch(1.0);
    _tts.setCompletionHandler(_clearSpeakingState);
    _tts.setCancelHandler(_clearSpeakingState);
    _tts.setErrorHandler((_) => _clearSpeakingState());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = Localizations.localeOf(context).languageCode;
    if (_ttsLanguageCode == languageCode) return;
    _ttsLanguageCode = languageCode;
    _tts.setLanguage(languageCode == 'en' ? 'en-US' : 'fr-FR');
  }

  void _clearSpeakingState() {
    if (mounted) setState(() => _speakingLessonId = null);
  }

  Future<void> _toggleSpeech(String lessonId, String text) async {
    if (_speakingLessonId == lessonId) {
      await _tts.stop();
      _clearSpeakingState();
      return;
    }
    await _tts.stop();
    if (!mounted) return;
    setState(() => _speakingLessonId = lessonId);
    final result = await _tts.speak(text);
    if (result != 1 && mounted) {
      setState(() => _speakingLessonId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.bilingual(
              fr: 'Active la voix française dans les réglages du téléphone.',
              en: 'Enable an English voice in your phone settings.',
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!widget.unlocked) {
      return Scaffold(
        appBar: CipAppBar(onBackPressed: () => Navigator.pop(context)),
        body: Column(
          children: [
            CipPageHeader(
              moduleTitle: widget.moduleTitle,
              pageTitle: context.bilingual(fr: 'Leçons', en: 'Lessons'),
              moduleTitleColor: cs.primary,
              subtitle: Text(
                context.bilingual(
                  fr: 'Module verrouillé.',
                  en: 'Locked module.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 46, color: cs.onSurface),
                      const SizedBox(height: 10),
                      Text(
                        context.bilingual(
                          fr: 'Module verrouillé',
                          en: 'Locked module',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.bilingual(
                          fr: 'Termine le module précédent pour accéder à celui-ci.',
                          en: 'Complete the previous module to access this one.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurface.withOpacity(0.65),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          context.bilingual(fr: 'Retour', en: 'Back'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: CipAppBar(onBackPressed: () => Navigator.pop(context)),
      body: Column(
        children: [
          CipPageHeader(
            moduleTitle: widget.moduleTitle,
            pageTitle: context.bilingual(fr: 'Leçons', en: 'Lessons'),
            moduleTitleColor: cs.primary,
            subtitle: Text(
              context.bilingual(
                fr: 'Écoute • Comprends • Observe un exemple • Relève le défi',
                en: 'Listen • Understand • Study an example • Take the challenge',
              ),
              textAlign: TextAlign.center,
            ),
          ),

          Expanded(
            child: Container(
              color: cs.background,
              child: _LessonsList(
                chapterId: widget.chapterId,
                moduleId: widget.moduleId,
                speakingLessonId: _speakingLessonId,
                onSpeak: _toggleSpeech,
              ),
            ),
          ),

          // ✅ footer toujours visible (pas caché par le bas du téléphone)
          SafeArea(
            top: false,
            child: LessonFooter(
              chapterId: widget.chapterId,
              moduleId: widget.moduleId,
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 0),
    );
  }
}

class _LessonsList extends StatelessWidget {
  final String chapterId;
  final String moduleId;
  final String? speakingLessonId;
  final Future<void> Function(String lessonId, String text) onSpeak;

  const _LessonsList({
    required this.chapterId,
    required this.moduleId,
    required this.speakingLessonId,
    required this.onSpeak,
  });

  List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (chapterId.isEmpty || moduleId.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.bilingual(
              fr: 'Module introuvable (identifiant manquant).\n\nReviens à la page "Apprendre" et rouvre ce module.',
              en: 'Module not found (missing identifier).\n\nGo back to the Learn page and reopen this module.',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final lessonsStream = FirebaseFirestore.instance
        .collection('chapters')
        .doc(chapterId)
        .collection('modules')
        .doc(moduleId)
        .collection('lessons')
        .orderBy('order')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: lessonsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${context.bilingual(fr: 'Erreur', en: 'Error')} : ${snapshot.error}',
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.bilingual(
                fr: 'Aucune leçon disponible pour ce module.\n\nVérifie dans Firestore :\nchapters/{chapterId}/modules/{moduleId}/lessons',
                en: 'No lessons are available for this module.\n\nCheck in Firestore:\nchapters/{chapterId}/modules/{moduleId}/lessons',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final lessonDoc = docs[index];
            final lesson = LocalizedFirestore.data(context, lessonDoc.data());
            return _LessonCard(
              key: ValueKey(lessonDoc.id),
              lessonId: lessonDoc.id,
              index: index + 1,
              title:
                  (lesson['title'] ??
                          context.bilingual(
                            fr: 'Leçon ${index + 1}',
                            en: 'Lesson ${index + 1}',
                          ))
                      .toString(),
              content: (lesson['content'] ?? '').toString(),
              duration: (lesson['durationMinutes'] ?? '5').toString(),
              competency: (lesson['rncpCompetency'] ?? '').toString(),
              sourceTitle: (lesson['sourceTitle'] ?? '').toString(),
              sourceUrl: (lesson['sourceUrl'] ?? '').toString(),
              contentStatus: (lesson['contentStatus'] ?? '').toString(),
              objectives: _strings(lesson['learningObjectives']),
              keyPoints: _strings(lesson['keyPoints']),
              checklist: _strings(lesson['checklist']),
              fieldExample: _map(lesson['fieldExample']),
              challenge: _map(lesson['challenge']),
              jury: _map(lesson['jury']),
              memoryTip: (lesson['memoryTip'] ?? '').toString(),
              isSpeaking: speakingLessonId == lessonDoc.id,
              onSpeak: onSpeak,
            );
          },
        );
      },
    );
  }
}

class _LessonCard extends StatefulWidget {
  final String lessonId;
  final int index;
  final String title;
  final String content;
  final String duration;
  final String competency;
  final String sourceTitle;
  final String sourceUrl;
  final String contentStatus;
  final List<String> objectives;
  final List<String> keyPoints;
  final List<String> checklist;
  final Map<String, dynamic> fieldExample;
  final Map<String, dynamic> challenge;
  final Map<String, dynamic> jury;
  final String memoryTip;
  final bool isSpeaking;
  final Future<void> Function(String lessonId, String text) onSpeak;

  const _LessonCard({
    super.key,
    required this.lessonId,
    required this.index,
    required this.title,
    required this.content,
    required this.duration,
    required this.competency,
    required this.sourceTitle,
    required this.sourceUrl,
    required this.contentStatus,
    required this.objectives,
    required this.keyPoints,
    required this.checklist,
    required this.fieldExample,
    required this.challenge,
    required this.jury,
    required this.memoryTip,
    required this.isSpeaking,
    required this.onSpeak,
  });

  @override
  State<_LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends State<_LessonCard> {
  late bool _expanded;
  bool _showChallengeAnswer = false;
  bool _showJuryAnswer = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.index == 1;
  }

  String _value(Map<String, dynamic> data, String key) =>
      (data[key] ?? '').toString().trim();

  String get _speechText {
    final parts = <String>[
      widget.title,
      ...widget.objectives,
      widget.content,
      ...widget.keyPoints,
      _value(widget.fieldExample, 'context'),
      _value(widget.fieldExample, 'expertApproach'),
      _value(widget.fieldExample, 'debrief'),
      _value(widget.challenge, 'prompt'),
      _value(widget.challenge, 'modelAnswer'),
      _value(widget.jury, 'question'),
      _value(widget.jury, 'modelAnswer'),
      widget.memoryTip,
    ].where((part) => part.isNotEmpty).toList();
    return parts.join('. ');
  }

  Future<void> _openSource(BuildContext context) async {
    final uri = Uri.tryParse(widget.sourceUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.bilingual(
              fr: 'Source momentanément inaccessible.',
              en: 'Source temporarily unavailable.',
            ),
          ),
        ),
      );
    }
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    final accent = color ?? cs.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }

  Widget _bullets(BuildContext context, List<String> items) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: cs.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item, style: const TextStyle(height: 1.4)),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _revealAnswer({
    required String answer,
    required bool visible,
    required VoidCallback onPressed,
  }) {
    if (answer.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(
            visible ? Icons.visibility_off_rounded : Icons.lightbulb_rounded,
          ),
          label: Text(
            visible
                ? context.bilingual(
                    fr: 'Masquer la correction',
                    en: 'Hide answer',
                  )
                : context.bilingual(
                    fr: 'Voir la réponse experte',
                    en: 'Show expert answer',
                  ),
          ),
        ),
        if (visible) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.82),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(answer, style: const TextStyle(height: 1.45)),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final exampleContext = _value(widget.fieldExample, 'context');
    final weakApproach = _value(widget.fieldExample, 'weakApproach');
    final expertApproach = _value(widget.fieldExample, 'expertApproach');
    final debrief = _value(widget.fieldExample, 'debrief');
    final challengePrompt = _value(widget.challenge, 'prompt');
    final challengeAnswer = _value(widget.challenge, 'modelAnswer');
    final juryQuestion = _value(widget.jury, 'question');
    final juryAnswer = _value(widget.jury, 'modelAnswer');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withOpacity(0.7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.index.toString(),
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 7,
            children: [
              _LessonBadge(
                icon: Icons.timer_outlined,
                label: '${widget.duration} min',
              ),
              if (widget.competency.isNotEmpty)
                _LessonBadge(
                  icon: Icons.workspace_premium_outlined,
                  label: widget.competency.split('•').first.trim(),
                ),
              _LessonBadge(
                icon: Icons.volume_up_outlined,
                label: context.bilingual(fr: 'Audio gratuit', en: 'Free audio'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.content,
            maxLines: _expanded ? null : 5,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withOpacity(0.85),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () async {
                  await widget.onSpeak(widget.lessonId, _speechText);
                },
                icon: Icon(
                  widget.isSpeaking
                      ? Icons.stop_circle_outlined
                      : Icons.headphones_rounded,
                ),
                label: Text(
                  widget.isSpeaking
                      ? context.bilingual(fr: 'Arrêter', en: 'Stop')
                      : context.bilingual(
                          fr: 'Écouter la leçon',
                          en: 'Listen to lesson',
                        ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                label: Text(
                  _expanded
                      ? context.bilingual(fr: 'Réduire', en: 'Collapse')
                      : context.bilingual(
                          fr: 'Explorer la leçon',
                          en: 'Explore lesson',
                        ),
                ),
              ),
            ],
          ),
          if (_expanded) ...[
            if (widget.objectives.isNotEmpty) ...[
              const SizedBox(height: 14),
              _section(
                context,
                icon: Icons.flag_rounded,
                title: context.bilingual(
                  fr: 'Objectifs de la leçon',
                  en: 'Lesson objectives',
                ),
                child: _bullets(context, widget.objectives),
              ),
            ],
            if (widget.keyPoints.isNotEmpty) ...[
              const SizedBox(height: 12),
              _section(
                context,
                icon: Icons.auto_awesome_rounded,
                title: context.bilingual(
                  fr: 'Les réflexes à retenir',
                  en: 'Key habits to remember',
                ),
                color: cs.secondary,
                child: _bullets(context, widget.keyPoints),
              ),
            ],
            if (exampleContext.isNotEmpty || expertApproach.isNotEmpty) ...[
              const SizedBox(height: 12),
              _section(
                context,
                icon: Icons.work_rounded,
                title: context.bilingual(
                  fr: 'Exemple terrain expliqué',
                  en: 'Workplace example explained',
                ),
                color: cs.tertiary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (exampleContext.isNotEmpty)
                      Text(
                        exampleContext,
                        style: const TextStyle(height: 1.45),
                      ),
                    if (weakApproach.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(
                        '${context.bilingual(fr: 'À éviter', en: 'Avoid')}: $weakApproach',
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (expertApproach.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(
                        '${context.bilingual(fr: 'Réponse experte', en: 'Expert response')}: $expertApproach',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (debrief.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(
                        '${context.bilingual(fr: 'Pourquoi', en: 'Why')}: $debrief',
                        style: const TextStyle(height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (challengePrompt.isNotEmpty) ...[
              const SizedBox(height: 12),
              _section(
                context,
                icon: Icons.sports_esports_rounded,
                title: context.bilingual(
                  fr: 'Mini-défi professionnel',
                  en: 'Workplace mini-challenge',
                ),
                color: const Color(0xFF7C3AED),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(challengePrompt, style: const TextStyle(height: 1.45)),
                    _revealAnswer(
                      answer: challengeAnswer,
                      visible: _showChallengeAnswer,
                      onPressed: () => setState(
                        () => _showChallengeAnswer = !_showChallengeAnswer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (juryQuestion.isNotEmpty) ...[
              const SizedBox(height: 12),
              _section(
                context,
                icon: Icons.groups_rounded,
                title: context.bilingual(
                  fr: 'Question possible du jury',
                  en: 'Possible assessor question',
                ),
                color: const Color(0xFFB45309),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      juryQuestion,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        height: 1.45,
                      ),
                    ),
                    _revealAnswer(
                      answer: juryAnswer,
                      visible: _showJuryAnswer,
                      onPressed: () =>
                          setState(() => _showJuryAnswer = !_showJuryAnswer),
                    ),
                  ],
                ),
              ),
            ],
            if (widget.checklist.isNotEmpty) ...[
              const SizedBox(height: 12),
              _section(
                context,
                icon: Icons.fact_check_rounded,
                title: context.bilingual(
                  fr: 'Checklist avant de passer au quiz',
                  en: 'Checklist before the quiz',
                ),
                child: _bullets(context, widget.checklist),
              ),
            ],
            if (widget.memoryTip.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: Text(
                  '🧠 ${context.bilingual(fr: 'Mémo', en: 'Remember')}: ${widget.memoryTip}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
          if (_expanded &&
              (widget.competency.isNotEmpty ||
                  widget.sourceTitle.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Divider(color: cs.outline.withOpacity(0.45)),
            Text(
              [
                widget.competency,
                widget.sourceTitle,
              ].where((value) => value.isNotEmpty).join(' • '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withOpacity(0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.contentStatus == 'legacy_to_review')
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  context.bilingual(
                    fr: 'Contenu historique : rattachement au référentiel à vérifier.',
                    en: 'Legacy content: framework mapping needs review.',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.deepOrange),
                ),
              ),
            if (widget.sourceUrl.isNotEmpty)
              TextButton.icon(
                onPressed: () => _openSource(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: Text(
                  context.bilingual(
                    fr: 'Voir la source officielle',
                    en: 'View official source',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LessonBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LessonBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: cs.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class LessonFooter extends StatelessWidget {
  final String chapterId;
  final String moduleId;

  const LessonFooter({
    super.key,
    required this.chapterId,
    required this.moduleId,
  });

  int _bestForLevel(
    Map<String, dynamic> levelsResults,
    String chapterId,
    String moduleId,
    int level,
  ) {
    final key = '$chapterId::$moduleId::$level';
    final raw = levelsResults[key];

    if (raw is Map<String, dynamic>)
      return (raw['bestPercent'] as num?)?.toInt() ?? 0;
    if (raw is num) return raw.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        int levelToPlay = 1;
        String buttonLabel = context.bilingual(
          fr: 'Commencer le niveau 1',
          en: 'Start level 1',
        );
        IconData icon = Icons.play_arrow_rounded;

        if (snapshot.hasData && snapshot.data!.data() != null) {
          final data = snapshot.data!.data()!;
          final levelsResults =
              (data['levelsResults'] as Map<String, dynamic>?) ?? {};

          final best1 = _bestForLevel(levelsResults, chapterId, moduleId, 1);
          final best2 = _bestForLevel(levelsResults, chapterId, moduleId, 2);
          final best3 = _bestForLevel(levelsResults, chapterId, moduleId, 3);

          final easyOk = best1 >= 80;
          final mediumOk = best2 >= 80;
          final expertOk = best3 >= 80;

          if (!easyOk) {
            levelToPlay = 1;
            buttonLabel = context.bilingual(
              fr: 'Commencer le niveau 1',
              en: 'Start level 1',
            );
            icon = Icons.play_arrow_rounded;
          } else if (!mediumOk) {
            levelToPlay = 2;
            buttonLabel = context.bilingual(
              fr: 'Continuer avec le niveau 2',
              en: 'Continue to level 2',
            );
            icon = Icons.arrow_forward_rounded;
          } else if (!expertOk) {
            levelToPlay = 3;
            buttonLabel = context.bilingual(
              fr: 'Continuer avec le niveau 3',
              en: 'Continue to level 3',
            );
            icon = Icons.arrow_forward_rounded;
          } else {
            levelToPlay = 3;
            buttonLabel = context.bilingual(
              fr: 'Tous les niveaux sont validés (rejouer le niveau 3)',
              en: 'All levels completed (replay level 3)',
            );
            icon = Icons.replay_rounded;
          }
        }

        return Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final rewarded = await EngagementService.recordLessonCompleted(
                  activityId: '$chapterId::$moduleId',
                );
                if (!context.mounted) return;
                if (rewarded) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.bilingual(
                          fr: 'Leçons terminées : +25 XP',
                          en: 'Lessons completed: +25 XP',
                        ),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizScreen(
                      level: levelToPlay,
                      chapterId: chapterId,
                      moduleId: moduleId,
                      onLevelCompleted: () {},
                    ),
                  ),
                );
              },
              icon: Icon(icon),
              label: Text(buttonLabel, textAlign: TextAlign.center),
            ),
          ),
        );
      },
    );
  }
}
