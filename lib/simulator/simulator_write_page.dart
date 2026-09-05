import 'package:flutter/material.dart';

import '../theme/cip_colors.dart' as c;
import '../services/openai_roleplay_service.dart';
import '../services/app_language.dart';

class SimulatorWritingPage extends StatefulWidget {
  final String scenarioId;
  final Map<String, dynamic> persona;
  final List<Map<String, String>> transcript;
  final OpenAiRoleplayService service;

  final String moduleTitle;
  final String scenarioTitle;
  final Map<String, dynamic> scenarioData;
  final String? trainingSessionId;

  const SimulatorWritingPage({
    super.key,
    required this.scenarioId,
    required this.persona,
    required this.transcript,
    required this.service,
    required this.moduleTitle,
    required this.scenarioTitle,
    this.scenarioData = const <String, dynamic>{},
    this.trainingSessionId,
  });

  @override
  State<SimulatorWritingPage> createState() => _SimulatorWritingPageState();
}

class _SimulatorWritingPageState extends State<SimulatorWritingPage> {
  final _synthCtrl = TextEditingController();
  final _analysisCtrl = TextEditingController();

  bool _loading = false;

  Map<String, dynamic>? _synthResult;
  Map<String, dynamic>? _analysisResult;

  @override
  void dispose() {
    _synthCtrl.dispose();
    _analysisCtrl.dispose();
    super.dispose();
  }

  // -------------------- safe helpers

  int _safeInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  List<String> _safeList(dynamic v) {
    if (v is List)
      return v
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    return const [];
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  bool get _synthReady => _synthCtrl.text.trim().length >= 40;
  bool get _analysisReady => _analysisCtrl.text.trim().length >= 40;

  bool get _allDone => _synthResult != null && _analysisResult != null;

  // -------------------- actions

  Future<void> _submitSynthesis() async {
    if (_loading) return;
    if (!_synthReady) {
      _snack(
        context.bilingual(
          fr: 'Écris une synthèse plus complète (au moins quelques paragraphes).',
          en: 'Write a more complete summary (at least a few paragraphs).',
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await widget.service.correctSynthesis(
        scenarioId: widget.scenarioId,
        persona: widget.persona,
        transcript: widget.transcript,
        synthesisText: _synthCtrl.text.trim(),
        scenarioData: widget.scenarioData,
        track: widget.scenarioData['track']?.toString(),
        sessionId: widget.trainingSessionId,
      );
      if (!mounted) return;
      setState(() => _synthResult = res);
      _snack(
        context.bilingual(
          fr: '✅ Synthèse corrigée.',
          en: '✅ Summary reviewed.',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack(
        '${context.bilingual(fr: 'Erreur synthèse', en: 'Summary error')}: $e',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitAnalysis() async {
    if (_loading) return;
    if (!_analysisReady) {
      _snack(
        context.bilingual(
          fr: 'Écris une analyse plus complète (au moins quelques paragraphes).',
          en: 'Write a more complete analysis (at least a few paragraphs).',
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await widget.service.correctAnalysis(
        scenarioId: widget.scenarioId,
        persona: widget.persona,
        transcript: widget.transcript,
        analysisText: _analysisCtrl.text.trim(),
        scenarioData: widget.scenarioData,
        track: widget.scenarioData['track']?.toString(),
        sessionId: widget.trainingSessionId,
      );
      if (!mounted) return;
      setState(() => _analysisResult = res);
      _snack(
        context.bilingual(
          fr: '✅ Analyse corrigée.',
          en: '✅ Analysis reviewed.',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack(
        '${context.bilingual(fr: 'Erreur analyse', en: 'Analysis error')}: $e',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _finishAndReturn() {
    if (!_allDone) {
      _snack(
        context.bilingual(
          fr: 'Termine la synthèse ET l’analyse pour valider.',
          en: 'Complete both the summary and analysis to finish.',
        ),
      );
      return;
    }

    Navigator.pop<Map<String, dynamic>>(context, {
      "done": true,
      "synthesis": _synthResult,
      "analysis": _analysisResult,
    });
  }

  // -------------------- UI atoms

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _resultCard(String title, Map<String, dynamic> r) {
    final note = _safeInt(r['note']);
    final ok = _safeList(r['ok']);
    final bad = _safeList(r['a_corriger']);
    final prop = (r['proposition'] ?? '').toString().trim();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: c.cipGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "$note/100",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: c.cipGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text("✅ OK", style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          if (ok.isEmpty)
            const Text("—", style: TextStyle(color: Color(0xFF6B7280))),
          for (final x in ok.take(8)) Text("• $x"),
          const SizedBox(height: 10),
          Text(
            context.bilingual(fr: '⚠️ À corriger', en: '⚠️ Needs improvement'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          if (bad.isEmpty)
            const Text("—", style: TextStyle(color: Color(0xFF6B7280))),
          for (final x in bad.take(8)) Text("• $x"),
          if (prop.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              context.bilingual(
                fr: '✍️ Proposition',
                en: '✍️ Suggested answer',
              ),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(prop),
          ],
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController ctrl,
    required String hint,
    required bool enabled,
  }) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      minLines: 10,
      maxLines: 20,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // -------------------- BUILD

  @override
  Widget build(BuildContext context) {
    final synthDone = _synthResult != null;
    final analysisDone = _analysisResult != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black45,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: null,
        actions: [
          TextButton(
            onPressed: _finishAndReturn,
            child: Text(
              context.bilingual(fr: 'VALIDER', en: 'SUBMIT'),
              style: TextStyle(
                color: _allDone ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Header comme OralPage
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
            color: Colors.white,
            child: Column(
              children: [
                Text(
                  widget.moduleTitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: c.cipBlue,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${context.bilingual(fr: 'Écrits', en: 'Writing')} • ${widget.scenarioTitle}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                // Intro
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.cipBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.cipBlue.withOpacity(0.25)),
                  ),
                  child: Text(
                    context.bilingual(
                      fr: 'Ici c’est l’ÉCRIT.\n\n1) Synthèse\n2) Analyse\n\nUne fois les deux validés, tu reviens au résultat final (oral + écrits).',
                      en: 'This is the WRITING section.\n\n1) Summary\n2) Analysis\n\nOnce both are completed, you will return to the final result (speaking + writing).',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                      height: 1.35,
                    ),
                  ),
                ),

                // --- SYNTHÈSE
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.bilingual(
                                fr: '1) Synthèse',
                                en: '1) Summary',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Icon(
                            synthDone
                                ? Icons.check_circle_rounded
                                : Icons.edit_rounded,
                            color: synthDone ? c.cipGreen : c.cipBlue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _textField(
                        ctrl: _synthCtrl,
                        enabled: !_loading,
                        hint: context.bilingual(
                          fr: 'Structure conseillée :\n• Contexte / cadre\n• Demande\n• Infos factuelles\n• Freins / atouts\n• Urgences\n• Suite (RDV / actions / docs)',
                          en: 'Suggested structure:\n• Context / setting\n• Request\n• Factual information\n• Barriers / strengths\n• Urgent points\n• Next steps (meeting / actions / documents)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.cipGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _loading ? null : _submitSynthesis,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            synthDone
                                ? context.bilingual(
                                    fr: 'Re-corriger la synthèse',
                                    en: 'Review summary again',
                                  )
                                : context.bilingual(
                                    fr: 'Valider & corriger',
                                    en: 'Submit & review',
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_synthResult != null)
                  _resultCard(
                    context.bilingual(
                      fr: 'Feedback Synthèse (écrit)',
                      en: 'Summary feedback (writing)',
                    ),
                    _synthResult!,
                  ),

                // --- ANALYSE (bloquée tant que synthèse pas faite)
                _card(
                  child: Opacity(
                    opacity: synthDone ? 1 : 0.45,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.bilingual(
                                  fr: '2) Analyse',
                                  en: '2) Analysis',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Icon(
                              analysisDone
                                  ? Icons.check_circle_rounded
                                  : Icons.edit_note_rounded,
                              color: analysisDone ? c.cipGreen : c.cipBlue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!synthDone)
                          Text(
                            context.bilingual(
                              fr: 'Termine d’abord la synthèse pour débloquer l’analyse.',
                              en: 'Complete the summary first to unlock the analysis.',
                            ),
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const SizedBox(height: 8),
                        IgnorePointer(
                          ignoring: !synthDone,
                          child: _textField(
                            ctrl: _analysisCtrl,
                            enabled: synthDone && !_loading,
                            hint: context.bilingual(
                              fr: 'Attendu :\n• Ce que j’ai fait\n• Pourquoi\n• Ce qui a marché\n• Ce que j’améliore\n• Ajustement concret',
                              en: 'Expected:\n• What I did\n• Why\n• What worked\n• What I will improve\n• Concrete adjustment',
                            ),
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
                            onPressed: (!synthDone || _loading)
                                ? null
                                : _submitAnalysis,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded),
                            label: Text(
                              analysisDone
                                  ? context.bilingual(
                                      fr: 'Re-corriger l’analyse',
                                      en: 'Review analysis again',
                                    )
                                  : context.bilingual(
                                      fr: 'Valider & corriger',
                                      en: 'Submit & review',
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_analysisResult != null)
                  _resultCard(
                    context.bilingual(
                      fr: 'Feedback Analyse (écrit)',
                      en: 'Analysis feedback (writing)',
                    ),
                    _analysisResult!,
                  ),

                // --- FIN
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _allDone ? c.cipGreen : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _allDone ? _finishAndReturn : null,
                    icon: const Icon(Icons.done_all_rounded),
                    label: Text(
                      context.bilingual(
                        fr: 'Retour au résultat final',
                        en: 'Return to final result',
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
  }
}
