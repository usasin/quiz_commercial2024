import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'services/usage_meter.dart';
import 'screens/credits_paywall_page.dart';
import 'services/localized_firestore.dart';
import 'services/app_language.dart';

// 🎨 Palette CIP (reprend ton style)
const cipBlue = Color(0xFF5AACDB);
const cipGreen = Color(0xFF3CC398);

class FirestoreSimulationsPage extends StatefulWidget {
  final String chapterId; // ex: "F0" (attention: F0 vs FO)
  final String moduleId; // ex: "F0_TERR" / "F0_POSTURE"
  final String title; // ex: "Simulateur • Territoire"

  const FirestoreSimulationsPage({
    super.key,
    required this.chapterId,
    required this.moduleId,
    required this.title,
  });

  @override
  State<FirestoreSimulationsPage> createState() =>
      _FirestoreSimulationsPageState();
}

class _FirestoreSimulationsPageState extends State<FirestoreSimulationsPage> {
  String _query = '';

  DocumentReference<Map<String, dynamic>> get _moduleRef => FirebaseFirestore
      .instance
      .collection('chapters')
      .doc(widget.chapterId)
      .collection('modules')
      .doc(widget.moduleId);

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream =>
      _moduleRef.collection('simulations').orderBy('order').snapshots();

  List<String> _asStringList(dynamic v) {
    if (v is! List) return <String>[];
    return v
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v as Map);
    return <String, dynamic>{};
  }

  String _labelActor(String actor) {
    switch (actor.toLowerCase().trim()) {
      case 'beneficiaire':
        return context.bilingual(fr: 'Bénéficiaire', en: 'Participant');
      case 'jury':
        return 'Jury';
      case 'coach':
        return 'Coach';
      case 'groupe':
        return context.bilingual(fr: 'Groupe', en: 'Group');
      case 'interne':
        return context.bilingual(fr: 'Interne', en: 'Internal');
      default:
        return actor.isEmpty ? '—' : actor;
    }
  }

  Map<String, dynamic> _personaFromActor(String actor) {
    // Format compatible avec ton SimulatorOralPage actuel (persona map)
    final a = actor.toLowerCase().trim();
    if (a == 'jury') {
      return {
        "label": "Jury",
        'style': context.bilingual(
          fr: 'exigeant, clair, questions courtes',
          en: 'demanding, clear, short questions',
        ),
        'goal': context.bilingual(
          fr: 'évaluer la posture et la capacité à expliquer simplement',
          en: 'assess professional approach and ability to explain simply',
        ),
      };
    }
    if (a == 'coach') {
      return {
        "label": "Coach",
        'style': context.bilingual(
          fr: 'bienveillant, structurant',
          en: 'supportive and structured',
        ),
        'goal': context.bilingual(
          fr: 'aider à s’auto-évaluer et progresser',
          en: 'support self-assessment and improvement',
        ),
      };
    }
    if (a == 'beneficiaire') {
      return {
        'label': context.bilingual(fr: 'Bénéficiaire', en: 'Participant'),
        'style': context.bilingual(
          fr: 'vécu réel, parfois stressé',
          en: 'real-life experience, sometimes stressed',
        ),
        'goal': context.bilingual(
          fr: 'exprimer une situation et ses freins',
          en: 'describe a situation and its barriers',
        ),
      };
    }
    if (a == 'groupe') {
      return {
        'label': context.bilingual(fr: 'Groupe', en: 'Group'),
        'style': context.bilingual(
          fr: 'plusieurs points de vue, interruptions',
          en: 'multiple viewpoints and interruptions',
        ),
        'goal': context.bilingual(
          fr: 'simuler une dynamique collective',
          en: 'simulate a group dynamic',
        ),
      };
    }
    return {
      'label': actor.isEmpty
          ? context.bilingual(fr: 'Interlocuteur', en: 'Speaker')
          : actor,
      'style': context.bilingual(fr: 'neutre', en: 'neutral'),
      'goal': context.bilingual(fr: 'jouer un rôle', en: 'play a role'),
    };
  }

  String _openingLine({
    required String actor,
    required String simTitle,
    required Map<String, dynamic> data,
  }) {
    final direct = (data['startLine'] ?? data['opening'] ?? data['prompt'])
        ?.toString()
        .trim();
    if (direct != null && direct.isNotEmpty) return direct;

    // Si pas de startLine en base, on génère une phrase de départ
    final a = actor.toLowerCase().trim();
    if (a == 'jury') {
      return context.bilingual(
        fr: 'Bonjour. Pouvez-vous expliquer simplement « $simTitle » et donner 1 exemple concret ?',
        en: 'Hello. Can you explain "$simTitle" simply and give one concrete example?',
      );
    }
    if (a == 'coach') {
      return context.bilingual(
        fr: 'On fait une auto-évaluation. Explique-moi comment tu t’y prends sur « $simTitle ».',
        en: 'Let us do a self-assessment. Explain how you approach "$simTitle".',
      );
    }
    if (a == 'beneficiaire') {
      return context.bilingual(
        fr: 'Bonjour… j’ai besoin d’aide, je ne sais pas par où commencer.',
        en: 'Hello… I need help and do not know where to start.',
      );
    }
    return context.bilingual(
      fr: 'Bonjour. On démarre la simulation : « $simTitle ».',
      en: 'Hello. We are starting the "$simTitle" simulation.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                // Search
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: TextField(
                    onChanged: (v) =>
                        setState(() => _query = v.trim().toLowerCase()),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      icon: const Icon(
                        Icons.search_rounded,
                        color: Colors.white70,
                      ),
                      hintText: context.bilingual(
                        fr: 'Rechercher (ex : jury, territoire, posture...)',
                        en: 'Search (e.g. assessor, territory, approach…)',
                      ),
                      hintStyle: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _stream,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(
                          child: Text(
                            '${context.bilingual(fr: 'Erreur Firestore', en: 'Firestore error')} : ${snap.error}',
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Text(
                            context.bilingual(
                              fr: 'Aucune simulation trouvée dans Firestore.\n\nVérifie le chemin :\n/chapters/<ID>/modules/<ID>/simulations',
                              en: 'No simulations found in Firestore.\n\nCheck the path:\n/chapters/<ID>/modules/<ID>/simulations',
                            ),
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      final filtered = docs.where((d) {
                        if (_query.isEmpty) return true;
                        final data = LocalizedFirestore.data(context, d.data());
                        final t = (data['title'] ?? d.id)
                            .toString()
                            .toLowerCase();
                        final actor = (data['actor'] ?? '')
                            .toString()
                            .toLowerCase();
                        final tags = _asStringList(
                          data['tags'],
                        ).join(' ').toLowerCase();
                        return t.contains(_query) ||
                            actor.contains(_query) ||
                            tags.contains(_query);
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            '${context.bilingual(fr: 'Aucun résultat pour', en: 'No results for')} "$_query"',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          final data = LocalizedFirestore.data(
                            context,
                            doc.data(),
                          );

                          final simTitle =
                              (data['title'] ?? data['name'] ?? doc.id)
                                  .toString();
                          final actor = (data['actor'] ?? '').toString();
                          final actorLabel = _labelActor(actor);

                          final briefing = _asMap(data['briefing']);
                          final duration = (briefing['duration'] ?? '')
                              .toString()
                              .trim();

                          final objectives = _asStringList(data['objectives']);
                          final pitfalls = _asStringList(data['pitfalls']);
                          final plan = _asStringList(data['plan']);

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: ExpansionTile(
                              collapsedIconColor: Colors.white70,
                              iconColor: Colors.white,
                              title: Text(
                                simTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _Chip(actorLabel),
                                    if (duration.isNotEmpty) _Chip(duration),
                                  ],
                                ),
                              ),
                              children: [
                                _Section(
                                  title: context.bilingual(
                                    fr: 'Objectifs',
                                    en: 'Objectives',
                                  ),
                                  items: objectives,
                                ),
                                _Section(
                                  title: context.bilingual(
                                    fr: 'Pièges fréquents',
                                    en: 'Common pitfalls',
                                  ),
                                  items: pitfalls,
                                ),
                                _Section(
                                  title: context.bilingual(
                                    fr: 'Plan conseillé',
                                    en: 'Suggested plan',
                                  ),
                                  items: plan,
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    6,
                                    16,
                                    14,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () async {
                                            final meter = UsageMeter();
                                            await meter.initIfNeeded();
                                            final ok = await meter
                                                .canStartSimulation();
                                            if (!ok) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const CreditsPaywallPage(),
                                                ),
                                              );
                                              return;
                                            }
                                            // 🔁 Utilise ta page existante (en lui ajoutant scenarioRef, voir patch plus bas)
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => SimulatorOralPage(
                                                  scenarioId: doc.id,
                                                  scenarioTitle: simTitle,
                                                  persona: _personaFromActor(
                                                    actor,
                                                  ),
                                                  startLine: _openingLine(
                                                    actor: actor,
                                                    simTitle: simTitle,
                                                    data: data,
                                                  ),
                                                  isOral: false,
                                                  scenarioRef: doc
                                                      .reference, // NEW (patch requis)
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.chat_bubble_outline,
                                          ),
                                          label: const Text("Chat"),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: cipGreen,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () async {
                                            final meter = UsageMeter();
                                            await meter.initIfNeeded();
                                            final ok = await meter
                                                .canStartSimulation();
                                            if (!ok) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const CreditsPaywallPage(),
                                                ),
                                              );
                                              return;
                                            }
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => SimulatorOralPage(
                                                  scenarioId: doc.id,
                                                  scenarioTitle: simTitle,
                                                  persona: _personaFromActor(
                                                    actor,
                                                  ),
                                                  startLine: _openingLine(
                                                    actor: actor,
                                                    simTitle: simTitle,
                                                    data: data,
                                                  ),
                                                  isOral: true,
                                                  scenarioRef: doc
                                                      .reference, // NEW (patch requis)
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.mic_none_rounded,
                                          ),
                                          label: Text(
                                            context.bilingual(
                                              fr: 'Oral',
                                              en: 'Speaking',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cipGreen.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<String> items;

  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          ...items.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                "• $e",
                style: const TextStyle(color: Colors.white70, height: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ IMPORTANT : cette classe existe déjà chez toi.
// Ajoute juste le "scenarioRef" via le patch ci-dessous.
class SimulatorOralPage extends StatelessWidget {
  final String scenarioId;
  final String scenarioTitle;
  final Map<String, dynamic> persona;
  final String startLine;
  final bool isOral;
  final DocumentReference<Map<String, dynamic>>? scenarioRef; // NEW

  const SimulatorOralPage({
    super.key,
    required this.scenarioId,
    required this.scenarioTitle,
    required this.persona,
    required this.startLine,
    required this.isOral,
    this.scenarioRef, // NEW
  });

  @override
  Widget build(BuildContext context) {
    // Placeholder pour que ce fichier compile si tu le colles seul.
    // Dans ton projet, tu as déjà la vraie page (simulator_oral_page.dart).
    return Scaffold(
      appBar: AppBar(title: Text(scenarioTitle)),
      body: Center(
        child: Text(
          context.bilingual(
            fr: 'Patch requis sur ta vraie SimulatorOralPage.',
            en: 'The real SimulatorOralPage still requires integration.',
          ),
        ),
      ),
    );
  }
}
