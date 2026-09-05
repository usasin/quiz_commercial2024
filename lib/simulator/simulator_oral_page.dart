import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../theme/cip_colors.dart' as c;
import '../services/gpt_service.dart';
import '../services/openai_roleplay_service.dart';
import '../services/admob_interstitial_service.dart';
import '../services/usage_meter.dart';
import '../services/ai_training_session_service.dart';
import '../services/app_language.dart';
import '../widgets/simulation_briefing_sheet.dart';
import 'simulator_result_page.dart';

class SimulatorOralPage extends StatefulWidget {
  final String chapterId;
  final String moduleId;
  final String moduleTitle;
  final String scenarioId;
  final String scenarioTitle;
  final String startLine;
  final Map<String, dynamic> persona;

  /// Peut être:
  /// - doc complet: { briefing: {...}, objectives: [...], plan: [...], notExpected: [...], ... }
  /// - OU directement le briefing: { objectives: [...], plan: [...], ... }
  final Map<String, dynamic> briefingData;
  final bool examMode;
  final int examDurationMinutes;
  final String? trainingSessionId;
  final int? trainingMaxTurns;

  const SimulatorOralPage({
    super.key,
    required this.chapterId,
    required this.moduleId,
    required this.moduleTitle,
    required this.scenarioId,
    required this.scenarioTitle,
    required this.startLine,
    required this.persona,
    required this.briefingData,
    required String stepId, // gardé pour compat mais pas utilisé ici
    this.examMode = false,
    this.examDurationMinutes = 30,
    this.trainingSessionId,
    this.trainingMaxTurns,
  });

  @override
  State<SimulatorOralPage> createState() => _SimulatorOralPageState();
}

class _SimulatorOralPageState extends State<SimulatorOralPage>
    with TickerProviderStateMixin {
  final _recorder = AudioRecorder();
  final _scroll = ScrollController();
  late final GptService _gpt;
  final _tts = FlutterTts();
  late final OpenAiRoleplayService _svc;
  String _languageCode = 'fr';
  bool _bootStarted = false;

  bool _loading = false;
  bool _recording = false;
  bool _finishing = false;
  bool _simulationCreditSpent = false;
  bool _audioWarningShown = false;
  String _loadingLabel = '';
  String? _trainingSessionId;
  int _trainingMaxTurns = 5;
  bool _accessLoading = true;
  String? _accessError;
  Timer? _examTimer;
  Timer? _recordingTimer;
  int _examSecondsLeft = 0;

  final List<Map<String, String>> _history = [];
  final List<_Msg> _ui = [];

  AnimationController? _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // ✅ Précharge la pub de fin de simulation, sans l'afficher pendant l'oral.
    AdmobInterstitialService.instance.preloadSimulation();

    if (widget.examMode) _startExamTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _languageCode = Localizations.localeOf(context).languageCode;
    if (_bootStarted) return;
    _bootStarted = true;
    _gpt = GptService(languageCode: _languageCode);
    _svc = OpenAiRoleplayService(languageCode: _languageCode);
    _boot();
  }

  void _startExamTimer() {
    _examSecondsLeft = widget.examDurationMinutes * 60;
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_examSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _examSecondsLeft = 0);
        if (!_finishing) _finish();
      } else {
        setState(() => _examSecondsLeft--);
      }
    });
  }

  String get _examClock {
    final minutes = (_examSecondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_examSecondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _boot() async {
    try {
      _trainingSessionId = widget.trainingSessionId;
      _trainingMaxTurns = widget.trainingMaxTurns ?? 5;
      if (_trainingSessionId == null || _trainingSessionId!.isEmpty) {
        final session = widget.examMode
            ? await AiTrainingSessionService.startExam(
                scenarioId: widget.scenarioId,
                track: widget.briefingData['track']?.toString(),
              )
            : await AiTrainingSessionService.startGuided(
                scenarioId: widget.scenarioId,
                track: widget.briefingData['track']?.toString(),
              );
        _trainingSessionId = session.id;
        _trainingMaxTurns = session.maxTurns;
      }
      if (!mounted) return;
      setState(() {
        _accessLoading = false;
        _ui.add(_Msg(role: 'assistant', text: widget.startLine));
        _history.add({'role': 'assistant', 'content': widget.startLine});
      });
      unawaited(_playSpeech(widget.startLine));
    } on AiTrainingAccessException catch (error) {
      if (!mounted) return;
      setState(() {
        _accessLoading = false;
        _accessError = error.localizedMessage(_languageCode);
      });
    }
  }

  int get _userTurns => _history.where((item) => item['role'] == 'user').length;

  Future<void> _playSpeech(String text) async {
    try {
      await _tts.setLanguage(_languageCode == 'en' ? 'en-US' : 'fr-FR');
      await _tts.setSpeechRate(.46);
      await _tts.setPitch(1.0);
      await _tts.speak(text);
    } catch (e) {
      debugPrint("Audio error: $e");
      if (mounted && !_audioWarningShown) {
        _audioWarningShown = true;
        _snack(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _spendSimulationCreditAfterSuccess() async {
    if (_simulationCreditSpent) return;
    _simulationCreditSpent = true;
    try {
      await UsageMeter().spendSimCredit(1);
    } catch (e) {
      debugPrint('Simulation credit sync error: $e');
    }
  }

  void _showBriefing() {
    final Map<String, dynamic> root = Map<String, dynamic>.from(
      widget.briefingData,
    );

    final Map<String, dynamic> brief = (root['briefing'] is Map)
        ? Map<String, dynamic>.from(root['briefing'])
        : <String, dynamic>{};

    List<String> _ls(dynamic v) =>
        (v is List) ? v.map((e) => e.toString()).toList() : <String>[];

    final objectives = _ls(root['objectives'] ?? brief['objectives']);
    final plan = _ls(root['plan'] ?? brief['plan']);
    final starterPhrases = _ls(
      root['starterPhrases'] ?? brief['starterPhrases'],
    );
    final pitfalls = _ls(root['pitfalls'] ?? brief['pitfalls']);

    final title =
        root['title']?.toString() ??
        brief['title']?.toString() ??
        widget.scenarioTitle;

    final duration =
        root['duration']?.toString() ??
        brief['duration']?.toString() ??
        "3-5 min";

    final List<Map<String, dynamic>> exampleList = [];
    final ex = brief['example'] ?? root['example'];
    if (ex is List) {
      for (final item in ex) {
        if (item is Map) {
          exampleList.add({
            'role':
                item['role']?.toString() ??
                context.bilingual(fr: 'Formateur', en: 'Trainer'),
            "text": item['text']?.toString() ?? "",
          });
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) => SimulationBriefingSheet(
        title: title,
        duration: duration,
        objectives: objectives,
        plan: plan,
        starterPhrases: starterPhrases,
        pitfalls: pitfalls,
        example: exampleList,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_accessLoading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    if (_accessError != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            context.bilingual(fr: 'Entraînement guidé', en: 'Guided practice'),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.task_alt_rounded, size: 52),
                  const SizedBox(height: 16),
                  Text(
                    _accessError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      context.bilingual(
                        fr: 'Revenir à mon parcours',
                        en: 'Return to my learning track',
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.black45),
          onPressed: _showBriefing,
        ),
        title: null,
        actions: [
          if (widget.examMode)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _examSecondsLeft < 300
                      ? Colors.red.shade50
                      : c.cipBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _examClock,
                  style: TextStyle(
                    color: _examSecondsLeft < 300 ? Colors.red : c.cipBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          TextButton(
            onPressed: (_loading || _finishing) ? null : _finish,
            child: Text(
              context.bilingual(fr: 'TERMINER', en: 'FINISH'),
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
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
                  widget.scenarioTitle,
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
          if (!widget.examMode)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.cipBlue.withOpacity(.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.cipBlue.withOpacity(.16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.bilingual(
                      fr: 'SIMULATION GUIDÉE',
                      en: 'GUIDED SIMULATION',
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _GuideStep(
                          number: '1',
                          label: context.bilingual(fr: 'Écoute', en: 'Listen'),
                          icon: Icons.hearing_rounded,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _GuideStep(
                          number: '2',
                          label: context.bilingual(
                            fr: 'Réponds',
                            en: 'Respond',
                          ),
                          icon: Icons.mic_rounded,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _GuideStep(
                          number: '3',
                          label: context.bilingual(
                            fr: 'Ton bilan',
                            en: 'Feedback',
                          ),
                          icon: Icons.assessment_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.bilingual(
                      fr: 'Touchez le micro, parlez, puis touchez à nouveau pour envoyer. Après quelques échanges, appuyez sur TERMINER pour recevoir votre bilan.',
                      en: 'Tap the microphone, speak, then tap again to send. After a few exchanges, tap FINISH to receive your feedback.',
                    ),
                    style: const TextStyle(fontSize: 11.5, height: 1.35),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${context.bilingual(fr: 'Échanges', en: 'Exchanges')} : $_userTurns / $_trainingMaxTurns',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: c.cipBlue,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _ui.length + (_loading ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _ui.length) return _buildShimmer();
                return _buildBubble(_ui[i]);
              },
            ),
          ),
          _buildBottomMicArea(),
        ],
      ),
    );
  }

  Widget _buildBottomMicArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        30,
        20,
        30,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20),
        ],
      ),
      child: Center(
        child: GestureDetector(
          onTap: _loading ? null : _toggleRecord,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (_recording) ...List.generate(2, (i) => _ripple(i)),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: _recording ? Colors.redAccent : c.cipBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _recording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_loading) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(height: 8),
                Text(
                  _loadingLabel.isEmpty
                      ? context.bilingual(
                          fr: 'Traitement en cours…',
                          en: 'Processing…',
                        )
                      : _loadingLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ] else
                Text(
                  _recording
                      ? context.bilingual(
                          fr: 'Parlez… puis touchez pour arrêter',
                          en: 'Speak… then tap to stop',
                        )
                      : context.bilingual(
                          fr: 'Touchez pour parler',
                          en: 'Tap to speak',
                        ),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(_Msg msg) {
    final isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isUser ? c.cipBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5),
          ],
        ),
        child: Text(
          msg.text,
          style: TextStyle(color: isUser ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    if (_shimmerCtrl == null) return const SizedBox();
    return FadeTransition(
      opacity: _shimmerCtrl!,
      child: Container(
        width: 80,
        height: 30,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }

  Widget _ripple(int i) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 1.8),
      duration: Duration(milliseconds: 1000 + (i * 300)),
      builder: (context, val, child) => Container(
        width: 80 * val,
        height: 80 * val,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.redAccent.withOpacity((2 - val).clamp(0, 1)),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      _recordingTimer?.cancel();
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _loading = true;
        _loadingLabel = context.bilingual(
          fr: 'Transcription de votre réponse…',
          en: 'Transcribing your response…',
        );
      });

      if (path == null) {
        setState(() {
          _loading = false;
          _loadingLabel = '';
        });
        _snack(
          context.bilingual(
            fr: "L'enregistrement n'a pas pu être récupéré. Réessaie.",
            en: 'The recording could not be retrieved. Try again.',
          ),
        );
        return;
      }

      try {
        final text = await _gpt.transcribeAudio(
          File(path),
          examMode: widget.examMode,
          sessionId: _trainingSessionId,
        );
        if (!mounted) return;

        setState(() {
          _ui.add(_Msg(role: 'user', text: text));
          _history.add({'role': 'user', 'content': text});
          _loadingLabel = context.bilingual(
            fr: 'Réponse du personnage…',
            en: 'The character is responding…',
          );
        });
        _jumpDown();

        // ✅ IMPORTANT : on envoie scenarioData => GPT reste dans objectives/plan/notExpected
        final reply = await _svc.send(
          scenarioId: widget.scenarioId,
          persona: widget.persona,
          history: _history,
          userMessage: text,
          scenarioData: widget.briefingData,
          track: widget.briefingData['track']?.toString(),
          examMode: widget.examMode,
          sessionId: _trainingSessionId,
        );
        if (!mounted) return;

        setState(() {
          _loading = false;
          _loadingLabel = '';
          _ui.add(_Msg(role: 'assistant', text: reply));
          _history.add({'role': 'assistant', 'content': reply});
        });
        await _spendSimulationCreditAfterSuccess();
        _jumpDown();
        unawaited(_playSpeech(reply));
      } catch (e) {
        debugPrint("send error: $e");
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadingLabel = '';
        });
        _snack(e.toString().replaceFirst('Exception: ', ''));
      }
    } else {
      if (_userTurns >= _trainingMaxTurns) {
        _snack(
          context.bilingual(
            fr: 'La mise en situation est complète. Termine pour recevoir ton bilan.',
            en: 'The scenario is complete. Finish to receive your feedback.',
          ),
        );
        return;
      }
      try {
        if (await Permission.microphone.request().isGranted) {
          if (!mounted) return;
          final dir = await getTemporaryDirectory();
          final path =
              '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _recorder.start(const RecordConfig(), path: path);
          if (mounted) {
            setState(() => _recording = true);
            _recordingTimer?.cancel();
            _recordingTimer = Timer(
              Duration(seconds: widget.examMode ? 90 : 60),
              () {
                if (mounted && _recording && !_loading) {
                  unawaited(_toggleRecord());
                }
              },
            );
          }
        } else {
          if (mounted) {
            _snack(
              context.bilingual(
                fr: 'Autorise le microphone pour répondre à la simulation.',
                en: 'Allow microphone access to respond to the simulation.',
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Recorder start error: $e');
        if (mounted) {
          _snack(
            context.bilingual(
              fr: "Le microphone n'a pas pu démarrer. Réessaie.",
              en: 'The microphone could not start. Try again.',
            ),
          );
        }
      }
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    if (_history.length < 3) {
      _snack(
        context.bilingual(
          fr: 'Échange encore trop court : réponds au moins une fois avant de terminer.',
          en: 'The exchange is still too short: respond at least once before finishing.',
        ),
      );
      return;
    }

    _finishing = true;
    _examTimer?.cancel();
    setState(() {
      _loading = true;
      _loadingLabel = context.bilingual(
        fr: 'Préparation de votre bilan…',
        en: 'Preparing your feedback…',
      );
    });
    try {
      // ✅ IMPORTANT : on envoie scenarioData au coach aussi
      final feedback = await _svc.coachFeedback(
        scenarioId: widget.scenarioId,
        persona: widget.persona,
        transcript: _history,
        scenarioData: widget.briefingData,
        track: widget.briefingData['track']?.toString(),
        examMode: widget.examMode,
        sessionId: _trainingSessionId,
      );

      if (!mounted) return;

      if (widget.examMode) {
        Navigator.pop(context, {
          'feedback': feedback,
          'transcript': List<Map<String, String>>.from(_history),
        });
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SimulatorResultPage(
            chapterId: widget.chapterId,
            moduleId: widget.moduleId,
            moduleTitle: widget.moduleTitle,
            scenarioId: widget.scenarioId,
            scenarioTitle: widget.scenarioTitle,
            persona: widget.persona,
            transcript: _history,
            feedback: feedback,
            service: _svc,
            scenarioData: widget.briefingData,
            trainingSessionId: _trainingSessionId,
          ),
        ),
      );
    } catch (e) {
      debugPrint("coach error: $e");
      if (mounted) {
        _snack(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      _finishing = false;
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingLabel = '';
        });
      }
    }
  }

  void _jumpDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  });

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  void dispose() {
    _recorder.dispose();
    _recordingTimer?.cancel();
    _examTimer?.cancel();
    _tts.stop();
    _shimmerCtrl?.dispose();
    _scroll.dispose();
    super.dispose();
  }
}

class _GuideStep extends StatelessWidget {
  final String number;
  final String label;
  final IconData icon;

  const _GuideStep({
    required this.number,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: c.cipBlue),
          const SizedBox(height: 3),
          Text(
            '$number. $label',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Msg {
  final String role;
  final String text;
  _Msg({required this.role, required this.text});
}
