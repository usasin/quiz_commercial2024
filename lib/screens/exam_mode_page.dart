import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/ai_training_session_service.dart';
import '../simulator/simulator_oral_page.dart';
import 'intensive_exam_pass_page.dart';

enum _ExamStage { intro, preparation, interview, writing, jury, completed }

class ExamModePage extends StatefulWidget {
  const ExamModePage({super.key});

  @override
  State<ExamModePage> createState() => _ExamModePageState();
}

class _ExamModePageState extends State<ExamModePage> {
  final _notes = TextEditingController();
  final _synthesis = TextEditingController();
  final _analysis = TextEditingController();
  _ExamStage _stage = _ExamStage.intro;
  Timer? _timer;
  int _secondsLeft = 0;
  bool _loading = false;
  QueryDocumentSnapshot<Map<String, dynamic>>? _scenario;
  AiTrainingSession? _trainingSession;

  static const _juryQuestions = <String>[
    'Comment avez-vous posé le cadre et vérifié sa compréhension ?',
    'Quels éléments vous permettent de parler de diagnostic partagé ?',
    'Quelle question a fait progresser l’entretien et pourquoi ?',
    'Comment avez-vous distingué les faits de vos interprétations ?',
    'Quelle priorité avez-vous retenue avec la personne ?',
    'Qu’auriez-vous fait différemment avec davantage de temps ?',
    'Quels partenaires du territoire pourraient être mobilisés ?',
    'Comment assurez-vous la confidentialité et la traçabilité ?',
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _notes.dispose();
    _synthesis.dispose();
    _analysis.dispose();
    super.dispose();
  }

  String get _clock {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startTimer(int minutes, VoidCallback onEnd) {
    _timer?.cancel();
    setState(() => _secondsLeft = minutes * 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        onEnd();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<bool> _startExamSession(String scenarioId) async {
    try {
      _trainingSession = await AiTrainingSessionService.startExam(
        scenarioId: scenarioId,
        track: 'cip',
      );
      return true;
    } on AiTrainingAccessException catch (error) {
      if (!mounted) return false;
      if (error.reason == 'intensive_pass_required') {
        final purchased = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => const IntensiveExamPassPage(),
          ),
        );
        if (purchased == true && mounted) {
          return _startExamSession(scenarioId);
        }
        return false;
      }
      _snack(error.message);
      return false;
    }
  }

  Future<void> _prepareExam() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('chapters').doc('M1')
          .collection('modules').doc('M1_E8')
          .collection('simulations').get();
      final candidates = snap.docs.where((doc) =>
          (doc.data()['actor'] ?? '').toString().toLowerCase() != 'jury').toList();
      if (candidates.isEmpty) throw Exception('Aucun sujet d’examen disponible.');
      _scenario = candidates[Random().nextInt(candidates.length)];
      if (!await _startExamSession(_scenario!.id)) return;
      setState(() => _stage = _ExamStage.preparation);
      _startTimer(15, () {
        if (mounted) _startInterview();
      });
    } catch (error) {
      if (mounted) _snack(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startInterview() async {
    _timer?.cancel();
    final doc = _scenario;
    if (doc == null || _loading) return;
    final session = _trainingSession;
    if (session == null) return;
    final data = doc.data();
    if (!mounted) return;
    setState(() => _stage = _ExamStage.interview);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SimulatorOralPage(
          chapterId: 'M1',
          moduleId: 'M1_E8',
          moduleTitle: 'Examen blanc RNCP37274',
          scenarioId: doc.id,
          scenarioTitle: (data['title'] ?? 'Mise en situation').toString(),
          startLine: (data['startLine'] ?? 'Bonjour.').toString(),
          persona: data['persona'] is Map
              ? Map<String, dynamic>.from(data['persona'] as Map)
              : <String, dynamic>{},
          briefingData: Map<String, dynamic>.from(data),
          stepId: 'M1_E8',
          examMode: true,
          examDurationMinutes: 30,
          trainingSessionId: session.id,
          trainingMaxTurns: session.maxTurns,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _stage = _ExamStage.writing);
    _startTimer(20, () {
      if (mounted) setState(() => _stage = _ExamStage.jury);
    });
  }

  void _goToJury() {
    _timer?.cancel();
    if (_synthesis.text.trim().length < 80 || _analysis.text.trim().length < 80) {
      _snack('Complète la synthèse et l’analyse avant de passer au jury.');
      return;
    }
    setState(() => _stage = _ExamStage.jury);
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Examen blanc CIP'),
        actions: [
          if (_stage == _ExamStage.preparation || _stage == _ExamStage.writing)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(_clock, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            _timeline(),
            const SizedBox(height: 18),
            if (_stage == _ExamStage.intro) _intro(),
            if (_stage == _ExamStage.preparation) _preparation(),
            if (_stage == _ExamStage.interview)
              const Center(child: CircularProgressIndicator()),
            if (_stage == _ExamStage.writing) _writing(),
            if (_stage == _ExamStage.jury) _jury(),
            if (_stage == _ExamStage.completed) _completed(),
          ],
        ),
      ),
    );
  }

  Widget _timeline() {
    final current = _stage.index.clamp(0, 4);
    const labels = ['Sujet', '15 min', '30 min', '20 min', 'Jury'];
    return Row(
      children: List.generate(labels.length, (index) => Expanded(
        child: Column(children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: index <= current ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
            child: index < current
                ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
                : Text('${index + 1}', style: TextStyle(color: index <= current ? Colors.white : Colors.black54, fontSize: 12)),
          ),
          const SizedBox(height: 5),
          Text(labels[index], style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
        ]),
      )),
    );
  }

  Widget _intro() => _panel(
    icon: Icons.school_rounded,
    title: 'Conditions proches de l’épreuve officielle',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('• Tirage aléatoire d’un sujet\n• 15 minutes de préparation\n• 30 minutes d’entretien\n• 20 minutes pour la synthèse et l’analyse\n• Entraînement aux questions du jury', style: TextStyle(height: 1.65)),
      const SizedBox(height: 10),
      const Row(children: [
        Icon(Icons.workspace_premium_rounded, color: Colors.amber),
        SizedBox(width: 8),
        Expanded(child: Text('1 examen inclus tous les 7 jours avec Premium, puis Pass intensif pour un essai supplémentaire.', style: TextStyle(fontWeight: FontWeight.w800))),
      ]),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _loading ? null : _prepareExam,
        icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.casino_rounded),
        label: const Text('Tirer mon sujet'),
      )),
    ]),
  );

  Widget _preparation() {
    final data = _scenario?.data() ?? {};
    return _panel(
      icon: Icons.timer_rounded,
      title: 'Préparation — 15 minutes',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((data['title'] ?? 'Mise en situation').toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        const SizedBox(height: 8),
        const Text('Prépare ton accueil, le cadre, les questions utiles et ta posture. Le personnage ne doit pas être interrogé avant le début.'),
        const SizedBox(height: 14),
        TextField(controller: _notes, minLines: 8, maxLines: 14, decoration: const InputDecoration(labelText: 'Tes notes de préparation', alignLabelWithHint: true)),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _startInterview, icon: const Icon(Icons.mic_rounded), label: const Text("Démarrer l’entretien de 30 minutes"))),
      ]),
    );
  }

  Widget _writing() => _panel(
    icon: Icons.edit_note_rounded,
    title: 'Écrits professionnels — 20 minutes',
    child: Column(children: [
      const Text('Rédige une synthèse factuelle, puis prépare ton analyse de pratique. Le chronomètre est commun aux deux productions.'),
      const SizedBox(height: 14),
      TextField(controller: _synthesis, minLines: 7, maxLines: 12, decoration: const InputDecoration(labelText: 'Synthèse de l’entretien', alignLabelWithHint: true)),
      const SizedBox(height: 14),
      TextField(controller: _analysis, minLines: 7, maxLines: 12, decoration: const InputDecoration(labelText: 'Analyse de pratique', alignLabelWithHint: true)),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _goToJury, child: const Text('Passer aux questions du jury'))),
    ]),
  );

  Widget _jury() => _panel(
    icon: Icons.groups_rounded,
    title: 'Questions du jury',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Réponds oralement en trois temps : fait observé → intention professionnelle → amélioration.'),
      const SizedBox(height: 12),
      for (var index = 0; index < _juryQuestions.length; index++)
        ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(radius: 15, child: Text('${index + 1}')), title: Text(_juryQuestions[index])),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => setState(() => _stage = _ExamStage.completed), icon: const Icon(Icons.flag_rounded), label: const Text('Terminer l’examen blanc'))),
    ]),
  );

  Widget _completed() => _panel(
    icon: Icons.workspace_premium_rounded,
    title: 'Examen blanc terminé',
    child: Column(children: [
      const Text('Tu as suivi toutes les phases. Reviens sur ton compte rendu de simulation et note trois actions de progression.', textAlign: TextAlign.center),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.home_rounded), label: const Text('Revenir au parcours'))),
    ]),
  );

  Widget _panel({required IconData icon, required String title, required Widget child}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)))]),
        const SizedBox(height: 16), child,
      ]),
    ),
  );
}
