// lib/screens/challenge_quiz.dart
import 'dart:async';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import '../models/challenge_model.dart';
import '../rotating_glow_border.dart';
import '../services/challenge_service.dart';
import '../services/question_service.dart';
import 'challenge_result.dart';

class ChallengeQuizScreen extends StatefulWidget {
  final ChallengeModel challenge;
  const ChallengeQuizScreen({Key? key, required this.challenge})
      : super(key: key);

  @override
  State<ChallengeQuizScreen> createState() => _ChallengeQuizScreenState();
}

class _ChallengeQuizScreenState extends State<ChallengeQuizScreen>
    with WidgetsBindingObserver {
  // ───────── Services & utils ─────────
  final _challengeService = ChallengeService();
  final _questionService  = QuestionService();
  final _audioPlayer      = AudioPlayer();
  final _tts              = FlutterTts();
  final _rand             = Random();

  // ───────── Identifiants ─────────
  late final String uid;
  late final String challengeId;

  // ───────── Données quiz ─────────
  late List<Map<String, dynamic>> _questions;
  int  _currentQuestion = 0;
  int  _score           = 0;
  bool _finished        = false;
  bool _loading         = true;

  // ───────── TTS & timer ─────────
  bool  _ttsEnabled   = false;
  int   _timerSeconds = 25;
  Timer? _timer;
  int   _questionStart = 0; // ms

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    uid         = FirebaseAuth.instance.currentUser!.uid;
    challengeId = widget.challenge.id;

    _tts
      ..setLanguage('fr-FR')
      ..setSpeechRate(0.5);

    _loadQuestions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _audioPlayer.dispose();
    _tts.stop();
    super.dispose();
  }

  // ───────── Charge 10 questions aléatoires ─────────
  Future<void> _loadQuestions() async {
    final raw = await _questionService.getRandomQuestions(
      widget.challenge.chapterId,
      limit: 10,
    );

    // Aucune question → on informe et on sort
    if (raw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune question disponible pour ce chapitre')),
      );
      Navigator.pop(context);
      return;
    }

    _questions = raw.map((q) {
      final opts       = List<String>.from(q['options'] as List);
      final correctIdx = q['correctAnswer'] as int;
      final pts        = (q['points'] as int?) ?? 1;

      // Mélange des réponses pour chaque partie
      final indices    = List<int>.generate(opts.length, (i) => i)..shuffle(_rand);
      final shuffled   = indices.map((i) => opts[i]).toList();
      final newCorrect = indices.indexOf(correctIdx);

      return {
        'question'     : q['question'] as String,
        'options'      : shuffled,
        'correctAnswer': newCorrect,
        'points'       : pts,
      };
    }).toList();

    if (!mounted) return;
    setState(() => _loading = false);
    _startTimer();
    _speakQuestion();
  }

  // ───────── Gestion timer ─────────
  void _startTimer() {
    _timer?.cancel();
    _questionStart = DateTime.now().millisecondsSinceEpoch;
    setState(() => _timerSeconds = 25);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timerSeconds == 0) {
        _answerQuestion(-1);
        t.cancel();
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  // ───────── Validation question ─────────
  Future<void> _answerQuestion(int selectedIndex) async {
    _timer?.cancel();
    final now        = DateTime.now().millisecondsSinceEpoch;
    final timeSpent  = now - _questionStart;
    final bonus      = _timerSeconds; // 0 si déjà écoulé
    final item       = _questions[_currentQuestion];
    final correctIdx = item['correctAnswer'] as int;
    final pts        = item['points'] as int;

    // son + score
    if (selectedIndex == correctIdx) {
      _score += pts + bonus;
      await _audioPlayer.setAsset('assets/sounds/correct.mp3');
    } else {
      await _audioPlayer.setAsset('assets/sounds/incorrect.mp3');
    }
    _audioPlayer.play();

    // maj Firestore (temps)
    await _challengeService.updatePlayerTime(
      challengeId : challengeId,
      uid         : uid,
      timeToAddMs : timeSpent,
    );

    await Future.delayed(const Duration(milliseconds: 800));

    if (_currentQuestion < _questions.length - 1) {
      setState(() => _currentQuestion++);
      _startTimer();
      _speakQuestion();
    } else {
      // fin : score + finished
      await _challengeService.updatePlayerScore(
        challengeId: challengeId,
        uid        : uid,
        score      : _score,
        finished   : true,
      );
      if (!mounted) return;
      setState(() => _finished = true);
    }
  }

  // ───────── TTS ─────────
  void _speakQuestion() {
    if (_ttsEnabled &&
        _currentQuestion < _questions.length &&
        _questions.isNotEmpty) {
      _tts.speak(_questions[_currentQuestion]['question'] as String);
    }
  }

  // ───────── Widgets utilitaires ─────────
  Widget _buildStatCard(String label, String value) => Column(
    children: [
      AutoSizeText(value,
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          maxLines: 1),
      const SizedBox(height: 4),
      AutoSizeText(label,
          style: const TextStyle(fontSize: 16, color: Colors.white70),
          maxLines: 1),
    ],
  );

  Widget _buildHeader() {
    final total = _questions.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.shade700,
            Colors.indigoAccent,
            Colors.indigo.shade800
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const AutoSizeText('DÉFI',
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                maxLines: 1),
            IconButton(
              icon: Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white),
              onPressed: () => setState(() {
                _ttsEnabled = !_ttsEnabled;
                _ttsEnabled ? _speakQuestion() : _tts.stop();
              }),
            ),
          ]),
          const SizedBox(height: 10),
          AutoSizeText('Question ${_currentQuestion + 1}/$total',
              style: const TextStyle(fontSize: 20, color: Colors.white70),
              maxLines: 1),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildStatCard('Score', '$_score pts'),
            _buildStatCard('Temps', '$_timerSeconds s'),
          ]),
        ],
      ),
    );
  }

  Widget _buildQuestion() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    child: RotatingGlowBorder(
      borderWidth: 3,
      borderRadius: 12,
      colors: const [Colors.purpleAccent, Colors.cyanAccent],
      duration: const Duration(seconds: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(blurRadius: 4, color: Colors.grey.shade400)
          ],
        ),
        child: AutoSizeText(
          _questions[_currentQuestion]['question'] as String,
          maxLines: 5,
          minFontSize: 16,
          style:
          const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );

  Widget _buildAnswerButtons(List<String> options) => Column(
    children: List.generate(options.length, (i) {
      return Container(
        margin:
        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: RotatingGlowBorder(
          borderWidth: 2,
          borderRadius: 10,
          colors: const [Colors.orangeAccent, Colors.redAccent],
          duration: const Duration(seconds: 5),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _answerQuestion(i),
            child: Container(
              padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black45.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(2, 2))
                ],
              ),
              child: Center(
                child: AutoSizeText(
                  options[i],
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      );
    }),
  );

  // ───────── Build ─────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: Colors.indigo,
          body: Center(child: CircularProgressIndicator()));
    }

    if (_finished) {
      // On attend l’autre joueur avant d’afficher le résultat
      return StreamBuilder<ChallengeModel>(
        stream: _challengeService.listenToChallenge(challengeId),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Scaffold(
                backgroundColor: Colors.indigo,
                body: Center(child: CircularProgressIndicator()));
          }
          final chall = snap.data!;
          if (chall.players.values.every((p) => p.finished)) {
            return ChallengeResultScreen(challenge: chall);
          }
          return Scaffold(
            backgroundColor: Colors.indigo.shade100,
            body: const Center(
              child: AutoSizeText(
                "En attente de l'autre joueur…",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      );
    }

    final options =
    List<String>.from(_questions[_currentQuestion]['options'] as List);

    return Scaffold(
      backgroundColor: Colors.indigo,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildQuestion(),
              const SizedBox(height: 24),
              _buildAnswerButtons(options),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
