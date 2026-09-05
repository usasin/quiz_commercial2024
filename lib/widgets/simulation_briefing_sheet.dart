import 'package:flutter/material.dart';
import '../services/app_language.dart';
import '../theme/cip_colors.dart' as c;

class SimulationBriefingSheet extends StatelessWidget {
  final String title;
  final String duration;
  final List<String> objectives;
  final List<String> plan;
  final List<String> starterPhrases;
  final List<String> pitfalls;

  // CHANGEMENT ICI : On accepte dynamic pour plus de souplesse avec Firestore
  final List<Map<String, dynamic>> example;

  const SimulationBriefingSheet({
    super.key,
    required this.title,
    required this.duration,
    required this.objectives,
    required this.plan,
    required this.starterPhrases,
    required this.pitfalls,
    required this.example,
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final sheetH = (h * 0.86).clamp(520.0, 760.0);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: sheetH,
        child: DefaultTabController(
          length: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    duration,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
                const SizedBox(height: 10),
                TabBar(
                  indicatorColor: c.cipBlue,
                  labelColor: const Color(0xFF111827),
                  unselectedLabelColor: const Color(0xFF6B7280),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                  tabs: [
                    const Tab(text: 'Briefing'),
                    Tab(
                      text: context.bilingual(fr: 'Exemple', en: 'Example'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    children: [_briefing(context), _example(context)],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.cipBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      context.bilingual(
                        fr: 'OK, je démarre',
                        en: "OK, let's start",
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardSection(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final x in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text("• $x", style: const TextStyle(height: 1.3)),
            ),
        ],
      ),
    );
  }

  Widget _briefing(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _cardSection(
            context.bilingual(fr: '🎯 Objectifs', en: '🎯 Objectives'),
            objectives,
          ),
          _cardSection(
            context.bilingual(fr: '🧩 Plan simple', en: '🧩 Simple plan'),
            plan,
          ),
          _cardSection(
            context.bilingual(
              fr: '✅ Phrases pour démarrer',
              en: '✅ Starter phrases',
            ),
            starterPhrases,
          ),
          _cardSection(
            context.bilingual(fr: '❌ À éviter', en: '❌ Pitfalls'),
            pitfalls,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _example(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.bilingual(
                fr: 'Mini dialogue modèle',
                en: 'Sample mini-dialogue',
              ),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (final turn in example)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      height: 1.35,
                    ),
                    children: [
                      TextSpan(
                        text:
                            "${turn['role'] ?? context.bilingual(fr: 'Intervenant', en: 'Speaker')}: ",
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      TextSpan(text: turn["text"] ?? ""), // Sécurité null
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
