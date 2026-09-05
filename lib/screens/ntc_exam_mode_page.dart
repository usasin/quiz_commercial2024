import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/engagement_service.dart';
import '../services/openai_roleplay_service.dart';
import '../services/ai_training_session_service.dart';
import '../simulator/simulator_oral_page.dart';
import 'intensive_exam_pass_page.dart';

enum _NtcExamStage {
  intro,
  written,
  call,
  negotiation,
  swot,
  jury,
  completed,
}

/// Examen blanc RNCP39063 conçu autour des productions et oraux officiels.
/// Le mode entraînement condense les temps ; le mode officiel conserve les
/// durées de référence utiles sur mobile.
class NtcExamModePage extends StatefulWidget {
  const NtcExamModePage({super.key});

  @override
  State<NtcExamModePage> createState() => _NtcExamModePageState();
}

class _NtcExamModePageState extends State<NtcExamModePage> {
  final _dashboard = TextEditingController();
  final _actionPlan = TextEditingController();
  final _proposal = TextEditingController();
  final _swot = TextEditingController();
  final _juryNotes = TextEditingController();
  final _ai = OpenAiRoleplayService();

  _NtcExamStage _stage = _NtcExamStage.intro;
  QueryDocumentSnapshot<Map<String, dynamic>>? _scenario;
  Timer? _timer;
  int _secondsLeft = 0;
  bool _officialMode = false;
  bool _loading = false;
  bool _correcting = false;
  Map<String, dynamic>? _writtenFeedback;
  Map<String, dynamic>? _callFeedback;
  Map<String, dynamic>? _negotiationFeedback;
  Map<String, dynamic>? _swotFeedback;
  AiTrainingSession? _trainingSession;

  static const _juryQuestions = <String>[
    'Comment avez-vous transformé les données du tableau de bord en priorités commerciales ?',
    'Pourquoi vos cibles et vos canaux de prospection sont-ils cohérents ?',
    'Quels indicateurs permettent de mesurer réellement l’efficacité du plan d’actions ?',
    'Comment avez-vous vérifié la faisabilité et la rentabilité de votre proposition ?',
    'Quels besoins explicites et implicites avez-vous identifiés pendant la découverte ?',
    'Quelles concessions pouviez-vous accorder et quelles contreparties avez-vous demandées ?',
    'Comment avez-vous traité l’objection principale sans dévaloriser l’offre ?',
    'Que montre votre SWOT et quelle décision commerciale en découle ?',
    'Comment sécurisez-vous le suivi, la satisfaction et la fidélisation du client ?',
    'Avec du recul, quelle action modifieriez-vous et sur quelle preuve vous appuyez-vous ?',
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _dashboard.dispose();
    _actionPlan.dispose();
    _proposal.dispose();
    _swot.dispose();
    _juryNotes.dispose();
    super.dispose();
  }

  String get _clock {
    final hours = _secondsLeft ~/ 3600;
    final minutes = ((_secondsLeft % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  void _startTimer(int minutes) {
    _timer?.cancel();
    setState(() => _secondsLeft = minutes * 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<bool> _startExamSession(String scenarioId) async {
    try {
      _trainingSession = await AiTrainingSessionService.startExam(
        scenarioId: scenarioId,
        track: 'ntc',
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
          .collection('chapters')
          .doc('NTC_CERT')
          .collection('modules')
          .doc('NTC_CERT_E2')
          .collection('simulations')
          .get();
      final candidates = snap.docs
          .where((doc) => doc.data()['examScenario'] == true)
          .toList();
      if (candidates.isEmpty) {
        throw Exception('Aucun sujet NTC publié dans Firestore.');
      }
      _scenario = candidates[Random().nextInt(candidates.length)];
      if (!await _startExamSession(_scenario!.id)) return;
      _dashboard.clear();
      _actionPlan.clear();
      _proposal.clear();
      _swot.clear();
      _juryNotes.clear();
      _writtenFeedback = null;
      _callFeedback = null;
      _negotiationFeedback = null;
      _swotFeedback = null;
      setState(() => _stage = _NtcExamStage.written);
      _startTimer(_officialMode ? 240 : 35);
    } catch (error) {
      if (mounted) {
        _snack(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _scenarioData =>
      _scenario?.data() ?? <String, dynamic>{};

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<String> _list(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }

  String _formatMap(dynamic value) {
    final data = _map(value);
    if (data.isEmpty) return 'Données non communiquées.';
    return data.entries.map((entry) => '• ${entry.key} : ${entry.value}').join('\n');
  }

  bool get _writtenReady =>
      _dashboard.text.trim().length >= 100 &&
      _actionPlan.text.trim().length >= 100 &&
      _proposal.text.trim().length >= 120;

  Future<void> _correctWritten() async {
    if (!_writtenReady) {
      _snack('Développe les trois productions avant de demander la correction.');
      return;
    }
    setState(() => _correcting = true);
    try {
      final result = await _ai.correctProfessionalWriting(
        kind: 'commercial_case',
        scenarioId: _scenario?.id ?? 'ntc_exam',
        persona: _map(_scenarioData['persona']),
        scenarioData: _scenarioData,
        track: 'ntc',
        examMode: true,
        sessionId: _trainingSession?.id,
        text: '''ANALYSE DU TABLEAU DE BORD
${_dashboard.text.trim()}

PLAN D'ACTIONS COMMERCIALES
${_actionPlan.text.trim()}

PROPOSITION TECHNIQUE ET COMMERCIALE
${_proposal.text.trim()}''',
      );
      if (!mounted) return;
      setState(() => _writtenFeedback = result);
      _snack('Correction IA disponible. Tu peux encore améliorer tes écrits.');
    } catch (error) {
      if (mounted) {
        _snack(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _correcting = false);
    }
  }

  Map<String, dynamic> _oralScenario({required bool negotiation}) {
    final data = Map<String, dynamic>.from(_scenarioData);
    data['track'] = 'ntc';
    data['rncpReference'] = 'RNCP39063';
    data['diplomaTitle'] = 'Négociateur technico-commercial';
    data['actor'] = negotiation ? 'décideur client' : 'prospect B2B au téléphone';
    data['title'] = negotiation
        ? 'Négociation de la proposition commerciale'
        : 'Appel de prospection et prise de rendez-vous';
    final objectives = negotiation
        ? _list(data['negotiationObjectives'])
        : _list(data['callObjectives']);
    if (objectives.isNotEmpty) data['objectives'] = objectives;
    return data;
  }

  Future<Map<String, dynamic>?> _runOral({required bool negotiation}) async {
    final data = _oralScenario(negotiation: negotiation);
    final startLine = (negotiation
            ? data['negotiationStartLine']
            : data['callStartLine'])
        ?.toString();
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SimulatorOralPage(
          chapterId: 'NTC_CERT',
          moduleId: 'NTC_CERT_E2',
          moduleTitle: 'Examen blanc RNCP39063',
          scenarioId:
              '${_scenario?.id ?? 'NTC'}_${negotiation ? 'NEGOCIATION' : 'APPEL'}',
          scenarioTitle: data['title'].toString(),
          startLine: startLine?.trim().isNotEmpty == true
              ? startLine!
              : 'Bonjour, je vous écoute.',
          persona: _map(data['persona']),
          briefingData: data,
          stepId: negotiation ? 'negociation' : 'prospection',
          examMode: true,
          examDurationMinutes:
              negotiation ? (_officialMode ? 60 : 18) : (_officialMode ? 15 : 8),
          trainingSessionId: _trainingSession?.id,
          trainingMaxTurns: min(9, _trainingSession?.maxTurns ?? 9),
        ),
      ),
    );
    if (result == null) return null;
    return _map(result['feedback']);
  }

  Future<void> _startCall() async {
    if (!_writtenReady) {
      _snack('Complète l’analyse, le plan d’actions et la proposition.');
      return;
    }
    _timer?.cancel();
    setState(() => _stage = _NtcExamStage.call);
    final feedback = await _runOral(negotiation: false);
    if (!mounted) return;
    if (feedback == null) {
      setState(() => _stage = _NtcExamStage.written);
      return;
    }
    _callFeedback = feedback;
    setState(() => _stage = _NtcExamStage.negotiation);
  }

  Future<void> _startNegotiation() async {
    final feedback = await _runOral(negotiation: true);
    if (!mounted || feedback == null) return;
    _negotiationFeedback = feedback;
    setState(() => _stage = _NtcExamStage.swot);
    _startTimer(_officialMode ? 20 : 10);
  }

  Future<void> _correctSwot() async {
    if (_swot.text.trim().length < 160) {
      _snack('Développe les quatre parties de la SWOT et la décision associée.');
      return;
    }
    setState(() => _correcting = true);
    try {
      final result = await _ai.correctProfessionalWriting(
        kind: 'swot',
        scenarioId: _scenario?.id ?? 'ntc_exam',
        persona: _map(_scenarioData['persona']),
        scenarioData: _scenarioData,
        track: 'ntc',
        examMode: true,
        sessionId: _trainingSession?.id,
        text: _swot.text.trim(),
      );
      if (!mounted) return;
      setState(() => _swotFeedback = result);
      _snack('Analyse SWOT corrigée.');
    } catch (error) {
      if (mounted) {
        _snack(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _correcting = false);
    }
  }

  void _goToJury() {
    if (_swot.text.trim().length < 160) {
      _snack('Présente les forces, faiblesses, opportunités, menaces et une décision.');
      return;
    }
    _timer?.cancel();
    setState(() => _stage = _NtcExamStage.jury);
  }

  int _score(Map<String, dynamic>? feedback) {
    if (feedback == null) return 0;
    return (feedback['score'] as num?)?.toInt() ??
        (feedback['note'] as num?)?.toInt() ??
        0;
  }

  void _complete() {
    final oralAverage = ((_score(_callFeedback) +
                _score(_negotiationFeedback)) /
            2)
        .round();
    unawaited(
      EngagementService.recordSimulationCompleted(
        oralScore: oralAverage,
        activityId: 'ntc_exam_${_scenario?.id ?? 'completed'}',
      ),
    );
    setState(() => _stage = _NtcExamStage.completed);
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Examen blanc NTC'),
        actions: [
          if (_stage == _NtcExamStage.written ||
              _stage == _NtcExamStage.swot)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  _clock,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          children: [
            _timeline(),
            const SizedBox(height: 18),
            if (_stage == _NtcExamStage.intro) _intro(),
            if (_stage == _NtcExamStage.written) _written(),
            if (_stage == _NtcExamStage.call)
              const Center(child: CircularProgressIndicator()),
            if (_stage == _NtcExamStage.negotiation) _negotiation(),
            if (_stage == _NtcExamStage.swot) _swotStage(),
            if (_stage == _NtcExamStage.jury) _jury(),
            if (_stage == _NtcExamStage.completed) _completed(),
          ],
        ),
      ),
    );
  }

  Widget _timeline() {
    const labels = ['Sujet', 'Écrits', 'Appel', 'Négo', 'SWOT', 'Jury', 'Bilan'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = index <= _stage.index;
          return SizedBox(
            width: 68,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: active
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade300,
                  child: index < _stage.index
                      ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: active ? Colors.white : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                ),
                const SizedBox(height: 5),
                Text(
                  labels[index],
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _intro() => _panel(
        icon: Icons.workspace_premium_rounded,
        title: 'Simulation RNCP39063 de bout en bout',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Un sujet unique alimente toutes les étapes : tableau de bord, plan d’actions, proposition commerciale, appel, négociation, SWOT et jury.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ChoiceChip(
                  selected: !_officialMode,
                  label: const Text('Entraînement guidé • ~1 h 20'),
                  onSelected: (_) => setState(() => _officialMode = false),
                ),
                ChoiceChip(
                  selected: _officialMode,
                  label: const Text('Conditions longues • RNCP'),
                  onSelected: (_) => setState(() => _officialMode = true),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Le mode long reprend les principales durées officielles. Tu peux quitter une phase lorsque ton travail est terminé.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Premium inclut un examen tous les 7 jours. Le Pass intensif permet de recommencer immédiatement un examen complet.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _prepareExam,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.casino_rounded),
                label: const Text('Tirer un sujet professionnel'),
              ),
            ),
          ],
        ),
      );

  Widget _scenarioCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (_scenarioData['title'] ?? 'Étude de cas commerciale').toString(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text((_scenarioData['context'] ?? '').toString()),
            const SizedBox(height: 12),
            const Text('TABLEAU DE BORD', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            SelectableText(_formatMap(_scenarioData['dashboard'])),
            const SizedBox(height: 12),
            const Text('CONTRAINTES', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            for (final item in _list(_scenarioData['constraints'])) Text('• $item'),
          ],
        ),
      );

  Widget _written() => _panel(
        icon: Icons.analytics_rounded,
        title: _officialMode
            ? 'Étude de cas écrite — 4 heures'
            : 'Étude de cas guidée — 35 minutes',
        child: Column(
          children: [
            _scenarioCard(),
            const SizedBox(height: 14),
            _field(
              _dashboard,
              '1. Analyse du tableau de bord',
              'Calcule les écarts, hiérarchise les causes et formule un diagnostic commercial…',
            ),
            const SizedBox(height: 12),
            _field(
              _actionPlan,
              '2. Plan d’actions commerciales',
              'Objectifs SMART, cibles, canaux, calendrier, moyens, KPI et actions correctives…',
            ),
            const SizedBox(height: 12),
            _field(
              _proposal,
              '3. Proposition technique et commerciale',
              'Besoins, solution, bénéfices, périmètre, prix, conditions, rentabilité et prochaine étape…',
              minLines: 9,
            ),
            if (_writtenFeedback != null) ...[
              const SizedBox(height: 14),
              _feedbackCard('Correction des écrits', _writtenFeedback!),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _correcting ? null : _correctWritten,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(_correcting ? 'Analyse…' : 'Correction IA'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startCall,
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Passer à l’appel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _negotiation() => _panel(
        icon: Icons.handshake_rounded,
        title: 'Négociation commerciale',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tu as obtenu le rendez-vous. Prépare ta découverte, ton argumentation, tes marges de manœuvre et les contreparties à demander.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 12),
            for (final item in _list(_scenarioData['negotiationBrief']))
              Text('• $item'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startNegotiation,
                icon: const Icon(Icons.mic_rounded),
                label: Text(
                  _officialMode
                      ? 'Lancer la négociation • 60 min'
                      : 'Lancer la négociation • 18 min',
                ),
              ),
            ),
          ],
        ),
      );

  Widget _swotStage() => _panel(
        icon: Icons.grid_view_rounded,
        title: 'Analyse SWOT et décision',
        child: Column(
          children: [
            Text(
              (_scenarioData['swotPrompt'] ??
                      'Construis la SWOT de l’entreprise puis propose une décision commerciale argumentée.')
                  .toString(),
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 14),
            _field(
              _swot,
              'Forces • Faiblesses • Opportunités • Menaces',
              'Présente au moins deux éléments par case, puis relie-les à une décision concrète…',
              minLines: 12,
            ),
            if (_swotFeedback != null) ...[
              const SizedBox(height: 14),
              _feedbackCard('Correction SWOT', _swotFeedback!),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _correcting ? null : _correctSwot,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Correction IA'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _goToJury,
                    child: const Text('Passer au jury'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _jury() => _panel(
        icon: Icons.groups_rounded,
        title: 'Questions du jury NTC',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Réponds avec la méthode : décision → preuve du cas → résultat attendu → limite ou amélioration.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < _juryQuestions.length; index++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 15, child: Text('${index + 1}')),
                title: Text(_juryQuestions[index]),
              ),
            const SizedBox(height: 10),
            _field(
              _juryNotes,
              'Tes preuves et réponses clés',
              'Note les chiffres, décisions et arguments que tu veux défendre devant le jury…',
              minLines: 8,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _complete,
                icon: const Icon(Icons.flag_rounded),
                label: const Text('Terminer et afficher le bilan'),
              ),
            ),
          ],
        ),
      );

  Widget _completed() {
    final callScore = _score(_callFeedback);
    final negotiationScore = _score(_negotiationFeedback);
    final writtenScore = _score(_writtenFeedback);
    final swotScore = _score(_swotFeedback);
    return _panel(
      icon: Icons.emoji_events_rounded,
      title: 'Examen blanc terminé',
      child: Column(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _scoreChip('Écrits', writtenScore),
              _scoreChip('Appel', callScore),
              _scoreChip('Négociation', negotiationScore),
              _scoreChip('SWOT', swotScore),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Ton bilan relie maintenant les productions écrites, les deux oraux et la soutenance. Reprends en priorité les axes signalés par le coach.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5),
          ),
          if (_callFeedback != null) ...[
            const SizedBox(height: 14),
            _feedbackCard('Appel de prospection', _callFeedback!),
          ],
          if (_negotiationFeedback != null) ...[
            const SizedBox(height: 12),
            _feedbackCard('Négociation', _negotiationFeedback!),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.home_rounded),
              label: const Text('Revenir au parcours NTC'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    int minLines = 7,
  }) =>
      TextField(
        controller: controller,
        minLines: minLines,
        maxLines: minLines + 8,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: true,
        ),
      );

  Widget _feedbackCard(String title, Map<String, dynamic> feedback) {
    final positives = _list(feedback['strengths'] ?? feedback['ok']);
    final improvements =
        _list(feedback['improvements'] ?? feedback['a_corriger']);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              Text('${_score(feedback)}/100',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          if (positives.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Points solides', style: TextStyle(fontWeight: FontWeight.w800)),
            for (final item in positives.take(4)) Text('• $item'),
          ],
          if (improvements.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Priorités', style: TextStyle(fontWeight: FontWeight.w800)),
            for (final item in improvements.take(4)) Text('• $item'),
          ],
        ],
      ),
    );
  }

  Widget _scoreChip(String label, int score) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$label ${score > 0 ? '$score/100' : 'non noté'}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      );

  Widget _panel({
    required IconData icon,
    required String title,
    required Widget child,
  }) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      );
}
