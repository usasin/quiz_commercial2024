import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../rotating_glow_border.dart';
import '../services/engagement_service.dart';
import '../services/review_service.dart';
import '../services/admob_interstitial_service.dart';
import '../services/localized_firestore.dart';
import '../services/app_language.dart';
import '../simulator/simulator_hub_page.dart';

/// Palette CIP
const cipBlue = Color(0xFF5AACDB);
const cipGreen = Color(0xFF3CC398);
const cipPeach = Color(0xFFFBA49B);

class QuizScreen extends StatefulWidget {
  final String chapterId;
  final String? moduleId;
  final int level; // 1 = easy, 2 = medium, 3 = expert
  final VoidCallback onLevelCompleted;

  /// 🔁 Révision : mélange tous les levels du module (auto)
  final bool isRevision;

  const QuizScreen({
    super.key,
    required this.chapterId,
    this.moduleId,
    required this.level,
    required this.onLevelCompleted,
    this.isRevision = false,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool _loading = true;
  bool _finished = false;

  List<Map<String, dynamic>> _questions = [];
  final List<Map<String, dynamic>> _mistakes = [];
  int _current = 0;
  int _score = 0;

  int? _selected;
  bool _showExplanation = false;

  // Timer & erreurs
  static const int _maxErrors = 3;
  int _wrongCount = 0;
  int _timerSeconds = 25;
  Timer? _timer;

  // Audio & TTS
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool _ttsEnabled = false;
  String? _ttsLanguageCode;

  // ✅ RNG pour shuffle stable
  final Random _rng = Random();

  String get _levelId {
    switch (widget.level) {
      case 2:
        return 'level_medium';
      case 3:
        return 'level_expert';
      default:
        return 'level_easy';
    }
  }

  String get _levelLabel {
    if (widget.isRevision) {
      return context.bilingual(
        fr: 'Mode révision • Mix des niveaux du module',
        en: 'Review mode • Mixed module levels',
      );
    }
    switch (widget.level) {
      case 2:
        return context.bilingual(
          fr: 'Niveau 2 • Intermédiaire',
          en: 'Level 2 • Intermediate',
        );
      case 3:
        return context.bilingual(
          fr: 'Niveau 3 • Expert',
          en: 'Level 3 • Expert',
        );
      default:
        return context.bilingual(fr: 'Niveau 1 • Facile', en: 'Level 1 • Easy');
    }
  }

  Color get _levelColor {
    if (widget.isRevision) return cipPeach;
    switch (widget.level) {
      case 2:
        return cipBlue;
      case 3:
        return cipPeach;
      default:
        return cipGreen;
    }
  }

  @override
  void initState() {
    super.initState();

    _tts.setSpeechRate(0.5);

    // ✅ Précharge l'interstitiel quiz, mais ne l'affiche jamais pendant les questions.
    AdmobInterstitialService.instance.preloadQuiz();

    _loadQuestions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = Localizations.localeOf(context).languageCode;
    if (_ttsLanguageCode == languageCode) return;
    _ttsLanguageCode = languageCode;
    _tts.setLanguage(languageCode == 'en' ? 'en-US' : 'fr-FR');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _playResultSound(bool correct) async {
    try {
      await _player.stop();
      await _player.play(
        AssetSource(correct ? 'sounds/correct.mp3' : 'sounds/wrong.mp3'),
      );
    } catch (_) {}
  }

  Future<void> _speakQuestion(String text) async {
    if (!_ttsEnabled) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _openSource(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
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

  void _maybeAskReviewAfterSuccess() {
    if (_questions.isEmpty) return;
    final ratio = _score / _questions.length;
    if (ratio < 0.70) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReviewService().maybeAskReview();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timerSeconds = 25;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      if (_selected != null) {
        t.cancel();
        return;
      }

      if (_timerSeconds <= 1) {
        setState(() => _timerSeconds = 0);
        t.cancel();

        _wrongCount++;
        _mistakes.add(Map<String, dynamic>.from(_questions[_current]));
        if (_wrongCount >= _maxErrors || _current + 1 >= _questions.length) {
          setState(() => _finished = true);
          _maybeAskReviewAfterSuccess();
        } else {
          setState(() {
            _current++;
            _selected = null;
            _showExplanation = false;
          });
          _startTimer();
        }
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  /// ✅ Shuffle des options + correction de l’index "correct"
  Map<String, dynamic> _shuffleOptionsFixCorrect(Map<String, dynamic> q) {
    final options = List<String>.from(q['options'] ?? const <String>[]);
    if (options.isEmpty) return q;

    int correct = (q['correct'] as int?) ?? 0;
    if (correct < 0) correct = 0;
    if (correct >= options.length) correct = options.length - 1;

    final indices = List<int>.generate(options.length, (i) => i);
    indices.shuffle(_rng);

    final newOptions = indices.map((i) => options[i]).toList();
    final newCorrect = indices.indexOf(correct);

    return {...q, 'options': newOptions, 'correct': newCorrect};
  }

  Future<CollectionReference<Map<String, dynamic>>> _baseLevelsRef() async {
    if (widget.moduleId != null && widget.moduleId!.isNotEmpty) {
      return FirebaseFirestore.instance
          .collection('chapters')
          .doc(widget.chapterId)
          .collection('modules')
          .doc(widget.moduleId)
          .collection('levels');
    }
    return FirebaseFirestore.instance
        .collection('chapters')
        .doc(widget.chapterId)
        .collection('levels');
  }

  Future<void> _loadQuestions() async {
    try {
      final baseLevelsRef = await _baseLevelsRef();

      List<Map<String, dynamic>> data = [];

      if (widget.isRevision) {
        final levelsSnap = await baseLevelsRef.get();
        final levelDocs = levelsSnap.docs
            .where((d) => d.id.startsWith('level_'))
            .toList();

        for (final levelDoc in levelDocs) {
          final qSnap = await levelDoc.reference.collection('questions').get();
          for (final d in qSnap.docs) {
            final q = LocalizedFirestore.data(context, d.data());

            final options = List<String>.from(q['options'] ?? []);
            if (options.isEmpty) continue;

            final correctRaw = q['correctAnswer'];
            final correct = (correctRaw is num)
                ? correctRaw.toInt()
                : int.tryParse(correctRaw?.toString() ?? '0') ?? 0;

            data.add({
              'id': d.id,
              'question': q['question'] ?? '',
              'options': options,
              'correct': correct,
              'explanation': q['explanation'] ?? '',
              'rncpCompetency': q['rncpCompetency'] ?? '',
              'sourceTitle': q['sourceTitle'] ?? '',
              'sourceUrl': q['sourceUrl'] ?? '',
              'sourceLevelId': levelDoc.id,
            });
          }
        }

        data = data.map(_shuffleOptionsFixCorrect).toList();
        data.shuffle(_rng);
      } else {
        final snap = await baseLevelsRef
            .doc(_levelId)
            .collection('questions')
            .get();

        data = snap.docs
            .map((d) {
              final q = LocalizedFirestore.data(context, d.data());
              final options = List<String>.from(q['options'] ?? []);
              final correctRaw = q['correctAnswer'];
              final correct = (correctRaw is num)
                  ? correctRaw.toInt()
                  : int.tryParse(correctRaw?.toString() ?? '0') ?? 0;

              return {
                'id': d.id,
                'question': q['question'] ?? '',
                'options': options,
                'correct': correct,
                'explanation': q['explanation'] ?? '',
                'rncpCompetency': q['rncpCompetency'] ?? '',
                'sourceTitle': q['sourceTitle'] ?? '',
                'sourceUrl': q['sourceUrl'] ?? '',
              };
            })
            .where((m) => (m['options'] as List).isNotEmpty)
            .toList();

        data = data.map(_shuffleOptionsFixCorrect).toList();
        data.shuffle(_rng);
      }

      if (!mounted) return;

      setState(() {
        _questions = data;
        _loading = false;
      });

      if (_questions.isNotEmpty) {
        _startTimer();
        _speakQuestion((_questions[0]['question'] ?? '').toString());
      }
    } catch (e) {
      debugPrint('Erreur Firestore: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectOption(int index) {
    if (_selected != null) return;

    final correct = (_questions[_current]['correct'] as int?) ?? 0;
    final isCorrect = index == correct;

    _timer?.cancel();
    setState(() {
      _selected = index;
      _showExplanation = true;
      if (isCorrect) {
        _score++;
      } else {
        _wrongCount++;
        _mistakes.add(Map<String, dynamic>.from(_questions[_current]));
      }
    });

    _playResultSound(isCorrect);

    // À la troisième erreur, l'explication reste visible. La fin est
    // déclenchée lorsque l'utilisateur appuie sur le bouton suivant.
  }

  void _nextQuestion() {
    if (_wrongCount >= _maxErrors || _current + 1 >= _questions.length) {
      setState(() => _finished = true);
      _maybeAskReviewAfterSuccess();
    } else {
      setState(() {
        _current++;
        _selected = null;
        _showExplanation = false;
      });
      _startTimer();
      _speakQuestion((_questions[_current]['question'] ?? '').toString());
    }
  }

  Future<void> _showQuizTransitionAd() async {
    try {
      await AdmobInterstitialService.instance.showQuizAdIfAvailable();
    } catch (_) {
      // On ne bloque jamais la navigation à cause d'une pub.
    }
  }

  Future<void> _saveQuizResult(bool success, int percent) async {
    if (widget.isRevision) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final now = DateTime.now();

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() as Map<String, dynamic>? ?? {};

        final Map<String, dynamic> levelsResults = Map<String, dynamic>.from(
          data['levelsResults'] ?? {},
        );

        final levelKey =
            '${widget.chapterId}::${widget.moduleId ?? 'noModule'}::${widget.level}';

        final prev = (levelsResults[levelKey] as Map<String, dynamic>?) ?? {};
        final prevBestPercent = (prev['bestPercent'] as num?)?.toInt() ?? 0;
        final prevBestScore = (prev['bestScore'] as num?)?.toInt() ?? 0;

        final newBestPercent = percent > prevBestPercent
            ? percent
            : prevBestPercent;
        final newBestScore = percent > prevBestPercent ? _score : prevBestScore;

        levelsResults[levelKey] = {
          'bestPercent': newBestPercent,
          'bestScore': newBestScore,
        };

        tx.set(ref, {
          'levelsResults': levelsResults,
          'lastScore': _score,
          'lastPercent': percent,
          'lastLevel': widget.level,
          'lastChapterId': widget.chapterId,
          'lastModuleId': widget.moduleId,
          'lastSuccess': success,
          'lastUpdated': FieldValue.serverTimestamp(),
          'lastPlayAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
      });

      // ✅ Gamification : streak + XP + badges
      if (success && percent >= 80) {
        await EngagementService.recordQuizPassedForActivity(
          percent: percent,
          activityId:
              '${widget.chapterId}::${widget.moduleId ?? 'noModule'}::${widget.level}',
        );
      } else {
        // Au moins compter la présence du jour
        await EngagementService.recordAppOpen();
      }
    } catch (e) {
      debugPrint('Erreur saveQuizResult: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: Center(
          child: Text(
            context.bilingual(
              fr: 'Aucune question disponible pour ce niveau.',
              en: 'No questions are available for this level.',
            ),
          ),
        ),
      );
    }

    if (_finished) {
      return _buildResultScreen(context);
    }

    return _buildQuestionScreen(context);
  }

  // ──────────────── ÉCRAN QUESTION ────────────────

  Widget _buildQuestionScreen(BuildContext context) {
    final q = _questions[_current];
    final options = (q['options'] as List).map((e) => e.toString()).toList();
    final correct = (q['correct'] as int?) ?? 0;
    final progress = (_current + 1) / _questions.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), cipBlue, cipGreen],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _levelLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _ttsEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() => _ttsEnabled = !_ttsEnabled);
                        if (_ttsEnabled) {
                          _speakQuestion((q['question'] ?? '').toString());
                        } else {
                          _tts.stop();
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // SCORE & TIMER
                Row(
                  children: [
                    Expanded(
                      child: _bigStatCard(
                        icon: Icons.star_rounded,
                        label: 'Score',
                        value: '$_score',
                        color: cipPeach,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _bigStatCard(
                        icon: Icons.timer_rounded,
                        label: context.bilingual(fr: 'Temps', en: 'Time'),
                        value: '${_timerSeconds}s',
                        color: cipBlue,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: _buildHearts()),
                const SizedBox(height: 16),

                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.15),
                    color: cipGreen,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.bilingual(fr: 'Question', en: 'Question'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${_current + 1} / ${_questions.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Expanded(
                  child: RotatingGlowBorder(
                    borderWidth: 3,
                    borderRadius: 22,
                    colors: const [cipBlue, cipGreen],
                    duration: const Duration(seconds: 4),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cipBlue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: AutoSizeText(
                              (q['question'] ?? '').toString(),
                              maxLines: 3,
                              minFontSize: 13,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          Expanded(
                            child: ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: options.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final isSelected = _selected == i;
                                final isCorrect =
                                    _selected != null && i == correct;
                                final isWrong =
                                    _selected != null &&
                                    isSelected &&
                                    !isCorrect;

                                Color borderColor = const Color(0xFFE5E7EB);
                                Color bgColor = const Color(0xFFF9FAFB);
                                IconData? icon;

                                if (isCorrect) {
                                  borderColor = cipGreen;
                                  bgColor = cipGreen.withOpacity(0.10);
                                  icon = Icons.check_circle_rounded;
                                } else if (isWrong) {
                                  borderColor = cipPeach;
                                  bgColor = cipPeach.withOpacity(0.14);
                                  icon = Icons.cancel_rounded;
                                } else if (isSelected) {
                                  borderColor = cipBlue;
                                  bgColor = cipBlue.withOpacity(0.10);
                                  icon = Icons.help_rounded;
                                }

                                final letter = String.fromCharCode(65 + i);

                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _selectOption(i),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: borderColor.withOpacity(
                                              0.15,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            letter,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: borderColor,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: AutoSizeText(
                                            options[i],
                                            maxLines: 3,
                                            minFontSize: 11,
                                            style: const TextStyle(
                                              color: Color(0xFF111827),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (icon != null) ...[
                                          const SizedBox(width: 6),
                                          Icon(
                                            icon,
                                            size: 18,
                                            color: borderColor,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 8),

                          if (_showExplanation)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: cipBlue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.lightbulb_rounded,
                                    color: cipBlue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      (q['explanation'] ?? '').toString(),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1E3A8A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (_showExplanation &&
                              ((q['rncpCompetency'] ?? '')
                                      .toString()
                                      .isNotEmpty ||
                                  (q['sourceTitle'] ?? '')
                                      .toString()
                                      .isNotEmpty)) ...[
                            const SizedBox(height: 6),
                            Text(
                              [
                                (q['rncpCompetency'] ?? '').toString(),
                                (q['sourceTitle'] ?? '').toString(),
                              ].where((value) => value.isNotEmpty).join(' • '),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if ((q['sourceUrl'] ?? '').toString().isNotEmpty)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => _openSource(
                                    (q['sourceUrl'] ?? '').toString(),
                                  ),
                                  icon: const Icon(
                                    Icons.open_in_new_rounded,
                                    size: 15,
                                  ),
                                  label: Text(
                                    context.bilingual(
                                      fr: 'Voir la source officielle',
                                      en: 'View official source',
                                    ),
                                  ),
                                ),
                              ),
                          ],

                          const SizedBox(height: 10),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _selected == null
                                  ? null
                                  : _nextQuestion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _levelColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                (_wrongCount >= _maxErrors ||
                                        _current + 1 == _questions.length)
                                    ? context.bilingual(
                                        fr: 'Voir le résultat',
                                        en: 'View results',
                                      )
                                    : context.bilingual(
                                        fr: 'Question suivante',
                                        en: 'Next question',
                                      ),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _bigStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHearts() {
    final hearts = List<Widget>.generate(_maxErrors, (i) {
      final lost = i < _wrongCount;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(
          lost ? Icons.favorite_border_rounded : Icons.favorite_rounded,
          color: lost ? Colors.white24 : cipPeach,
          size: 18,
        ),
      );
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: hearts),
    );
  }

  // ──────────────── ÉCRAN RÉSULTAT ────────────────

  Widget _buildResultScreen(BuildContext context) {
    final percent = (_score / _questions.length * 100).round();
    final success = percent >= 80 && _wrongCount < _maxErrors;

    // Révision (inchangé)
    if (widget.isRevision) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [cipBlue, cipPeach],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 120,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.bilingual(
                        fr: 'Révision terminée 👌',
                        en: 'Review completed 👌',
                      ),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.bilingual(
                        fr: 'Tu peux rejouer la révision ou revenir au module.',
                        en: 'You can replay the review or return to the module.',
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _resultStatsCard(percent),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _finished = false;
                          _current = 0;
                          _score = 0;
                          _wrongCount = 0;
                          _selected = null;
                          _showExplanation = false;
                          _questions = _questions
                              .map(_shuffleOptionsFixCorrect)
                              .toList();
                          _questions.shuffle(_rng);
                        });
                        _startTimer();
                        _speakQuestion(
                          (_questions[0]['question'] ?? '').toString(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: cipBlue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        context.bilingual(
                          fr: 'Rejouer la révision',
                          en: 'Replay review',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        context.bilingual(
                          fr: 'Revenir au module',
                          en: 'Return to module',
                        ),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Quiz normal
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: success
                ? [cipGreen, cipBlue]
                : [cipPeach, Colors.deepOrange],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    success
                        ? Icons.emoji_events_rounded
                        : Icons.sentiment_dissatisfied_rounded,
                    color: Colors.white,
                    size: 120,
                  ),
                  const SizedBox(height: 20),

                  // ✅ Texte spécial si Level 3 validé
                  Text(
                    success
                        ? (widget.level == 3
                              ? context.bilingual(
                                  fr: 'Bravo ! Niveau Expert validé 🎯',
                                  en: 'Well done! Expert level completed 🎯',
                                )
                              : context.bilingual(
                                  fr: 'Bravo !',
                                  en: 'Well done!',
                                ))
                        : context.bilingual(
                            fr: 'Ce n’est pas grave 😌',
                            en: 'Keep going 😌',
                          ),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    success
                        ? (widget.level == 3
                              ? context.bilingual(
                                  fr: 'La Simulation IA est maintenant débloquée.\nContinue avec la mise en situation.',
                                  en: 'The AI simulation is now unlocked.\nContinue with the role-play scenario.',
                                )
                              : context.bilingual(
                                  fr: 'Tu as validé ce niveau.',
                                  en: 'You completed this level.',
                                ))
                        : context.bilingual(
                            fr: 'Rejoue encore une fois pour le maîtriser.',
                            en: 'Try again to master this level.',
                          ),
                    style: const TextStyle(fontSize: 15, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),
                  _resultStatsCard(percent),

                  const SizedBox(height: 28),

                  // ✅ ACTIONS
                  if (success && widget.level == 3) ...[
                    // Bouton Simulation IA (prioritaire)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _saveQuizResult(success, percent);

                          widget.onLevelCompleted();

                          await _showQuizTransitionAd();
                          if (!mounted) return;

                          final mid = widget.moduleId;
                          if (mid == null || mid.isEmpty) {
                            if (mounted) Navigator.pop(context);
                            return;
                          }

                          if (!mounted) return;

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SimulatorHubPage(
                                chapterId: widget.chapterId,
                                moduleId: mid,
                                moduleTitle: 'Module',
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: cipGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.smart_toy_rounded),
                        label: Text(
                          context.bilingual(
                            fr: 'Aller à la Simulation IA',
                            en: 'Go to AI simulation',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Revenir module (simple)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () async {
                          await _saveQuizResult(success, percent);
                          widget.onLevelCompleted();
                          await _showQuizTransitionAd();
                          if (!mounted) return;
                          Navigator.pop(
                            context,
                          ); // revient au précédent (souvent Lessons)
                        },
                        child: Text(
                          context.bilingual(
                            fr: 'Revenir au module',
                            en: 'Return to module',
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ] else ...[
                    // comportement standard (N1->N2->N3)
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _saveQuizResult(success, percent);

                        if (success) {
                          widget.onLevelCompleted();

                          await _showQuizTransitionAd();
                          if (!mounted) return;

                          if (widget.level < 3) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QuizScreen(
                                  chapterId: widget.chapterId,
                                  moduleId: widget.moduleId,
                                  level: widget.level + 1,
                                  onLevelCompleted: widget.onLevelCompleted,
                                ),
                              ),
                            );
                          } else {
                            // (normalement jamais ici car géré au-dessus)
                            Navigator.pop(context);
                          }
                        } else {
                          final retryQuestions = _mistakes.isNotEmpty
                              ? _mistakes
                                    .map(
                                      (item) => Map<String, dynamic>.from(item),
                                    )
                                    .toList()
                              : _questions
                                    .map(
                                      (item) => Map<String, dynamic>.from(item),
                                    )
                                    .toList();
                          setState(() {
                            _finished = false;
                            _current = 0;
                            _score = 0;
                            _wrongCount = 0;
                            _selected = null;
                            _showExplanation = false;
                            _questions = retryQuestions
                                .map(_shuffleOptionsFixCorrect)
                                .toList();
                            _questions.shuffle(_rng);
                            _mistakes.clear();
                          });
                          _startTimer();
                          _speakQuestion(
                            (_questions[0]['question'] ?? '').toString(),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: success ? cipGreen : Colors.deepOrange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: Icon(
                        success
                            ? (widget.level < 3
                                  ? Icons.arrow_forward_rounded
                                  : Icons.check_rounded)
                            : Icons.refresh_rounded,
                      ),
                      label: Text(
                        success
                            ? (widget.level < 3
                                  ? context.bilingual(
                                      fr: 'Niveau suivant',
                                      en: 'Next level',
                                    )
                                  : context.bilingual(
                                      fr: 'Terminer le module',
                                      en: 'Complete module',
                                    ))
                            : (_mistakes.isEmpty
                                  ? context.bilingual(
                                      fr: 'Rejouer le niveau',
                                      en: 'Replay level',
                                    )
                                  : context.bilingual(
                                      fr: 'Revoir mes erreurs',
                                      en: 'Review my mistakes',
                                    )),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        context.bilingual(
                          fr: 'Revenir au module',
                          en: 'Return to module',
                        ),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultStatsCard(int percent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Text(
            'Score: $_score / ${_questions.length}',
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            '$percent %',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${context.bilingual(fr: 'Erreurs', en: 'Mistakes')}: $_wrongCount / $_maxErrors',
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
