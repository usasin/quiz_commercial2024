import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/usage_meter.dart';
import '../services/ai_training_session_service.dart';
import '../services/localized_firestore.dart';
import '../services/app_language.dart';
import '../screens/credits_paywall_page.dart';
import 'simulator_oral_page.dart';

class SimulatorHubPage extends StatefulWidget {
  final String chapterId;
  final String moduleId;
  final String moduleTitle;

  const SimulatorHubPage({
    super.key,
    required this.chapterId,
    required this.moduleId,
    required this.moduleTitle,
  });

  @override
  State<SimulatorHubPage> createState() => _SimulatorHubPageState();
}

class _SimulatorHubPageState extends State<SimulatorHubPage> {
  DocumentReference<Map<String, dynamic>> get _moduleRef => FirebaseFirestore
      .instance
      .collection('chapters')
      .doc(widget.chapterId)
      .collection('modules')
      .doc(widget.moduleId);

  Stream<QuerySnapshot<Map<String, dynamic>>> get _simStream =>
      _moduleRef.collection('simulations').snapshots();

  String _groupLabelFromActor(
    BuildContext context,
    String actor,
    String idUpper,
  ) {
    final a = actor.toLowerCase().trim();
    if (a == "jury" || a == "evaluation" || idUpper.contains("CERT"))
      return context.bilingual(fr: 'Évaluation', en: 'Assessment');
    if (a == "coach" || idUpper.contains("SELF")) return "Coach";
    return context.bilingual(fr: 'Simulation', en: 'Simulation');
  }

  Color _groupColor(BuildContext context, String group) {
    final cs = Theme.of(context).colorScheme;
    if (group.contains("Évaluation") || group.contains('Assessment')) {
      return const Color(0xFF7C3AED);
    }
    if (group.contains("Coach")) return cs.tertiary;
    return cs.primary;
  }

  String _badgeActor(BuildContext context, String actor) {
    switch (actor.toLowerCase().trim()) {
      case "client":
        return "Client";
      case "prospect":
        return "Prospect";
      case "decideur":
        return context.bilingual(fr: 'Décideur', en: 'Decision-maker');
      case "gerant":
      case "gérant":
        return context.bilingual(fr: 'Gérant', en: 'Manager');
      case "jury":
        return context.bilingual(fr: 'Évaluation', en: 'Assessment');
      case "groupe":
        return context.bilingual(fr: 'Groupe', en: 'Group');
      case "collegue":
      case "interne":
        return context.bilingual(fr: 'Interne', en: 'Internal');
      case "coach":
        return "Coach";
      default:
        return context.bilingual(fr: 'Décideur', en: 'Decision-maker');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: Text(widget.moduleTitle), centerTitle: true),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _simStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${context.bilingual(fr: 'Erreur Firestore', en: 'Firestore error')} : ${snap.error}',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.65),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomSafe),
              children: [
                Text(
                  context.bilingual(
                    fr: 'Aucune simulation trouvée dans Firestore pour ce module.\n\nVérifie : /chapters/<chapterId>/modules/<moduleId>/simulations',
                    en: 'No simulations were found in Firestore for this module.\n\nCheck: /chapters/<chapterId>/modules/<moduleId>/simulations',
                  ),
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            );
          }

          final sorted = [...docs];
          sorted.sort((a, b) {
            final ao = (a.data()['order'] is num)
                ? (a.data()['order'] as num).toInt()
                : 999999;
            final bo = (b.data()['order'] is num)
                ? (b.data()['order'] as num).toInt()
                : 999999;
            if (ao != bo) return ao.compareTo(bo);
            final at = (a.data()['title'] ?? a.id).toString();
            final bt = (b.data()['title'] ?? b.id).toString();
            return at.compareTo(bt);
          });

          return ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomSafe),
            children: [
              for (final doc in sorted)
                _SimCard(
                  data: LocalizedFirestore.data(context, doc.data()),
                  docId: doc.id,
                  chapterId: widget.chapterId,
                  moduleId: widget.moduleId,
                  moduleTitle: widget.moduleTitle,
                  groupLabelFromActor: (actor, id) =>
                      _groupLabelFromActor(context, actor, id),
                  groupColor: (g) => _groupColor(context, g),
                  badgeActor: (actor) => _badgeActor(context, actor),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SimCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  final String chapterId;
  final String moduleId;
  final String moduleTitle;

  final String Function(String actor, String idUpper) groupLabelFromActor;
  final Color Function(String group) groupColor;
  final String Function(String actor) badgeActor;

  const _SimCard({
    required this.data,
    required this.docId,
    required this.chapterId,
    required this.moduleId,
    required this.moduleTitle,
    required this.groupLabelFromActor,
    required this.groupColor,
    required this.badgeActor,
  });

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v as Map);
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final simTitle = (data['title'] ?? data['name'] ?? docId).toString();
    final actor = (data['actor'] ?? '').toString();
    final idUpper = docId.toUpperCase();

    final group = groupLabelFromActor(actor, idUpper);
    final groupC = groupColor(group);

    final startLine =
        (data['startLine'] ??
                data['opening'] ??
                data['prompt'] ??
                context.bilingual(
                  fr: 'Bonjour. On commence.',
                  en: "Hello. Let's begin.",
                ))
            .toString();
    final persona = _asMap(data['persona']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withOpacity(0.7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            simTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                text: badgeActor(actor),
                bg: cs.surface,
                fg: cs.onSurface,
                border: cs.outline.withOpacity(0.7),
              ),
              _Pill(
                text: group,
                bg: groupC.withOpacity(0.12),
                fg: groupC,
                border: cs.outline.withOpacity(0.7),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final meter = UsageMeter();
                await meter.initIfNeeded();
                try {
                  final session = await AiTrainingSessionService.startGuided(
                    scenarioId: docId,
                    track: data['track']?.toString(),
                  );
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SimulatorOralPage(
                        chapterId: chapterId,
                        moduleId: moduleId,
                        moduleTitle: moduleTitle,
                        scenarioId: docId,
                        scenarioTitle: simTitle,
                        startLine: startLine,
                        persona: persona,
                        briefingData: Map<String, dynamic>.from(data),
                        stepId: moduleId,
                        trainingSessionId: session.id,
                        trainingMaxTurns: session.maxTurns,
                      ),
                    ),
                  );
                } on AiTrainingAccessException catch (error) {
                  if (!context.mounted) return;
                  if (error.reason == 'discovery_used') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreditsPaywallPage(),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          error.localizedMessage(
                            Localizations.localeOf(context).languageCode,
                          ),
                        ),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.mic_rounded, size: 18),
              label: Text(
                context.bilingual(
                  fr: 'Démarrer (Oral)',
                  en: 'Start (Speaking)',
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.bilingual(
              fr: '1 essai découverte, puis 2 séances guidées par jour avec Premium.',
              en: '1 discovery attempt, then 2 guided sessions per day with Premium.',
            ),
            style: TextStyle(
              color: cs.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final Color border;

  const _Pill({
    required this.text,
    required this.bg,
    required this.fg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}
