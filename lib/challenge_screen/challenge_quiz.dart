import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/challenge_model.dart';
import '../services/challenge_service.dart';
import '../services/question_service.dart';
import 'challenge_result.dart';
import '../rotating_glow_border.dart';

class ChallengeQuizScreen extends StatefulWidget {
  final ChallengeModel challenge;
  const ChallengeQuizScreen({Key? key, required this.challenge}) : super(key: key);

  @override
  State<ChallengeQuizScreen> createState() => _ChallengeQuizScreenState();
}

class _ChallengeQuizScreenState extends State<ChallengeQuizScreen> with WidgetsBindingObserver {
  final _challengeService = ChallengeService();
  final _questionService = QuestionService();
  final _audioPlayer = AudioPlayer();
  final _tts = FlutterTts();
  final _rand = Random();

  late String uid;
  late String challengeId;
  late List<Map<String, dynamic>> _questions;

  int _currentQuestion = 0;
  int _score = 0;
  bool _finished = false;
  bool _loading = true;
  bool _ttsEnabled = false;
  int _timerSeconds = 25;
  Timer? _timer;
  int _questionStart = 0; // timestamp en ms

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    uid = FirebaseAuth.instance.currentUser!.uid;
    challengeId = widget.challenge.id;
    _tts.setLanguage('fr-FR');
    _tts.setSpeechRate(0.5);
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

  Future<void> _loadQuestions() async {
    final raw = await _questionService.getQuestions(
      chapterId: widget.challenge.chapterId,
      levelId: widget.challenge.levelId,
    );
    _questions = raw.map((q) {
      final opts = List<String>.from(q['options'] as List);
      final correctIdx = q['correctAnswer'] as int;
      final pts = (q['points'] as int?) ?? 1;
      final indices = List<int>.generate(opts.length, (i) => i)..shuffle(_rand);
      final shuffled = indices.map((i) => opts[i]).toList();
      final newCorrect = indices.indexOf(correctIdx);
      return {
        'question': q['question'] as String,
        'options': shuffled,
        'correctAnswer': newCorrect,
        'points': pts,
      };
    }).toList();

    setState(() => _loading = false);
    _startTimer();
    _speakQuestion();
  }

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

  Future<void> _answerQuestion(int selectedIndex) async {
    _timer?.cancel();
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeSpent = now - _questionStart;          // ms
    final bonus = (_timerSeconds > 0) ? _timerSeconds : 0; // secondes restantes

    final item = _questions[_currentQuestion];
    final correctIndex = item['correctAnswer'] as int;
    final pts = item['points'] as int;

    if (selectedIndex == correctIndex) {
      _score += pts + bonus;                         // on ajoute bonus
      await _audioPlayer.setAsset('assets/sounds/correct.mp3');
    } else {
      await _audioPlayer.setAsset('assets/sounds/incorrect.mp3');
    }
    _audioPlayer.play();

    // on met à jour le temps cumulé dans Firestore
    await _challengeService.updatePlayerTime(
      challengeId: challengeId,
      uid: uid,
      timeToAddMs: timeSpent,
    );

    await Future.delayed(const Duration(milliseconds: 800));

    if (_currentQuestion < _questions.length - 1) {
      setState(() => _currentQuestion++);
      _startTimer();
      _speakQuestion();
    } else {
      // dernier envoi du score + mark finished
      await _challengeService.updatePlayerScore(
        challengeId: challengeId,
        uid: uid,
        score: _score,
        finished: true,
      );
      setState(() => _finished = true);
    }
  }

  void _speakQuestion() {
    if (_ttsEnabled) {
      _tts.speak(_questions[_currentQuestion]['question'] as String);
    }
  }

  Widget _buildHeader() {
    final total = _questions.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.indigoAccent, Colors.indigo.shade800],
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
            const AutoSizeText(
              'DÉFI',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
              maxLines: 1,
            ),
            IconButton(
              icon: Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off, color: Colors.white),
              onPressed: () => setState(() {
                _ttsEnabled = !_ttsEnabled;
                _ttsEnabled ? _speakQuestion() : _tts.stop();
              }),
            ),
          ]),
          const SizedBox(height: 10),
          AutoSizeText(
            'Question ${_currentQuestion + 1}/$total',
            style: const TextStyle(fontSize: 20, color: Colors.white70),
            maxLines: 1,
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildStatCard('Score', '$_score pts'),
            _buildStatCard('Temps', '$_timerSeconds s'),
          ]),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) => Column(children: [
    AutoSizeText(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1),
    const SizedBox(height: 4),
    AutoSizeText(label, style: const TextStyle(fontSize: 16, color: Colors.white70), maxLines: 1),
  ]);

  Widget _buildQuestion() {
    final text = _questions[_currentQuestion]['question'] as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: RotatingGlowBorder(
        borderWidth: 3,
        borderRadius: 12,
        colors: [Colors.purpleAccent, Colors.cyanAccent],
        duration: const Duration(seconds: 4),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(blurRadius: 4, color: Colors.grey.shade400)],
          ),
          child: AutoSizeText(
            text,
            maxLines: 5,
            minFontSize: 16,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerButtons(List<String> options) => Column(
    children: List.generate(options.length, (i) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: RotatingGlowBorder(
          borderWidth: 2,
          borderRadius: 10,
          colors: [Colors.orangeAccent, Colors.redAccent],
          duration: const Duration(seconds: 5),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _answerQuestion(i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: Colors.black45.withOpacity(0.3), blurRadius: 4, offset: const Offset(2, 2))
                ],
              ),
              child: Center(
                child: AutoSizeText(
                  options[i],
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      );
    }),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Colors.indigo, body: Center(child: CircularProgressIndicator()));
    }
    if (_finished) {
      return StreamBuilder<ChallengeModel>(
        stream: _challengeService.listenToChallenge(challengeId),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Scaffold(backgroundColor: Colors.indigo, body: Center(child: CircularProgressIndicator()));
          }
          final challenge = snap.data!;
          if (challenge.players.values.every((p) => p.finished)) {
            return ChallengeResultScreen(challenge: challenge);
          }
          return Scaffold(
            backgroundColor: Colors.indigo.shade100,
            body: const Center(
              child: AutoSizeText("En attente de l'autre joueur...", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          );
        },
      );
    }

    final options = List<String>.from(_questions[_currentQuestion]['options'] as List);
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
