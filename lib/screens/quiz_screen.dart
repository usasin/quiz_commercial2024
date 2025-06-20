import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../congratulations_page.dart';
import '../drawer/dashed_border_painter.dart';
import '../failure_page.dart';
import '../firebase_storage_service.dart';
import '../rotating_glow_border.dart';
import '../services/score_utils.dart';

class Question {
  String questionText;
  List<String> options;
  int correctAnswer;
  String imagePath;
  String explanation;

  Question({
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.imagePath,
    required this.explanation,
  });
}

class QuizScreen extends StatefulWidget {
  final int level;
  final VoidCallback onLevelCompleted;
  final String chapterId;

  const QuizScreen({
    Key? key,
    required this.level,
    required this.chapterId,
    required this.onLevelCompleted,
  }) : super(key: key);

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentScore = 0;
  int _currentIndex = 0;
  int _currentLevel = 0;
  bool _showExplanation = true;
  bool? isCorrect;
  final AudioPlayer audioPlayer = AudioPlayer();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamController<int>? _timerStreamController;
  Timer? _timer;
  final _auth = FirebaseAuth.instance;
  bool hasAnswered = false;
  bool _soundEnabled = true;
  final double glowWidth = 3.0;
  // Variable pour contrôler si le quiz est encore actif
  bool _quizActive = true;

  // Instance pour la synthèse vocale
  final FlutterTts flutterTts = FlutterTts();
  // Pour éviter de relire la même question plusieurs fois
  bool _questionSpoken = false;

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.level;
    _quizActive = true;
    _startTimer();
    _loadShowExplanationSetting();
    _loadSoundSetting();
  }

  @override
  void dispose() {
    _quizActive = false;
    _timer?.cancel();
    _timerStreamController?.close();
    audioPlayer.stop();
    flutterTts.stop();
    super.dispose();
  }

  /// Permet de lire un texte à voix haute si le son est activé.
  /// On vérifie aussi que le widget est toujours monté et que le quiz est actif.
  Future<void> _speak(String text) async {
    if (!_soundEnabled || !mounted || !_quizActive) return;
    await flutterTts.speak(text);
  }

  void onQuestionAnswered() {
    hasAnswered = true;
  }

  int obtenirChapitrePourNiveau(int niveau) {
    return (niveau - 1) ~/ 12 + 1; // Ajustement pour chapitres de 12 niveaux chacun
  }

  void onTimeElapsed() {
    if (!hasAnswered) return;
    hasAnswered = false;
  }

  String obtenirCollectionIdPourNiveau(int chapitre, int niveau) {
    String levelName = 'Level $niveau';
    return 'chapters/chapitre$chapitre/levels/$levelName/questions';
  }

  void _loadSoundSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
    });
  }

  void _loadShowExplanationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showExplanation = prefs.getBool('showExplanation') ?? true;
    });
  }

  /// Passe à la question suivante.
  /// Si c'est la dernière question, on arrête le quiz.
  void _nextQuestion() async {
    await flutterTts.stop();
    await audioPlayer.stop();

    if (_currentIndex < 9) { // 10 questions par niveau
      setState(() {
        _currentIndex++;
        _questionSpoken = false;
      });
      hasAnswered = false;
      _timer?.cancel();
      _startTimer();
    } else {
      // Fin du quiz : on désactive le quiz pour éviter tout déclenchement ultérieur
      _quizActive = false;
      _updateTotalScore();

      if (_currentScore >= 80) {
        widget.onLevelCompleted();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CongratulationsPage(
              level: widget.level,
              levelColor: _getLevelColor(widget.level),
              scaffoldKey: _scaffoldKey,
              score: _currentScore,
              firestoreCollectionId: obtenirCollectionIdPourNiveau(
                  obtenirChapitrePourNiveau(widget.level), widget.level),
            ),
          ),
        ).then((_) {
          setState(() {
            _currentIndex = 0;
            _questionSpoken = false;
          });
          // S'assurer qu'aucun son ne continue
          flutterTts.stop();
          audioPlayer.stop();
        });
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FailurePage(
              score: _currentScore,
              level: widget.level,
              chapterId: widget.chapterId,
            ),
          ),
        ).then((_) {
          flutterTts.stop();
          audioPlayer.stop();
        });
      }
    }
  }

  Color _getLevelColor(int niveau) {
    if (niveau <= 12) {
      return Colors.blue.shade300;
    } else if (niveau <= 24) {
      return Colors.amber.shade300;
    } else if (niveau <= 36) {
      return Colors.red.shade300;
    } else {
      return Colors.deepOrange.shade500;
    }
  }

  /// Gère la réponse de l'utilisateur.
  /// On arrête toute lecture en cours pour éviter les chevauchements.
  Future<void> _handleUserAnswer(String userAnswer, String correctAnswer) async {
    if (!hasAnswered) return;
    await flutterTts.stop();
    await audioPlayer.stop();

    if (userAnswer == correctAnswer) {
      setState(() {
        _currentScore += 10;
        isCorrect = true;
      });
      if (_soundEnabled) {
        await audioPlayer.setAsset('assets/sounds/correct.mp3');
        await audioPlayer.play();
        // Attendre que le son se termine (ajustez la durée en fonction de votre fichier sonore)
        await Future.delayed(Duration(milliseconds: 500));
        await _speak("Bonne réponse");
      }
    } else {
      setState(() {
        isCorrect = false;
      });
      if (_soundEnabled) {
        await audioPlayer.setAsset('assets/sounds/incorrect.mp3');
        await audioPlayer.play();
        await Future.delayed(Duration(milliseconds: 500));
        await _speak("Mauvaise réponse");
      }
    }
    onQuestionAnswered();
    _timer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('showExplanation', _showExplanation);
  }

  void _startTimer() {
    const timeLimit = 25;
    _timerStreamController = StreamController<int>();
    _timerStreamController?.add(timeLimit);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      int currentTime = timeLimit - timer.tick;
      _timerStreamController?.add(currentTime);

      if (currentTime == 0) {
        timer.cancel();
        onTimeElapsed();
        _nextQuestion();
      }
    });
  }

  void _updateTotalScore() async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(_auth.currentUser?.uid);
    final userDoc = await userRef.get();

    if (userDoc.exists) {
      String chapterId = widget.chapterId;
      String levelKey = 'Level $_currentLevel';

      await updateUserTotalScore(
        _auth.currentUser?.uid ?? '',
        chapterId,
        levelKey,
        _currentScore,
      );

      int newTotalScore = 0;
      Map<String, dynamic> chapters = (await userRef.get()).data()?['chapters'] ?? {};

      chapters.forEach((chapterId, chapterData) {
        if (chapterData is Map<String, dynamic>) {
          int chapterTotalScore = chapterData['totalScore'] as int? ?? 0;
          newTotalScore += chapterTotalScore;
        }
      });

      await userRef.update({
        'totalScore': newTotalScore,
      });

      int currentUnlockedLevels = userDoc.data()?['unlockedLevels'] ?? 1;
      if (_currentLevel == currentUnlockedLevels && _currentScore >= 80) {
        await userRef.update({'unlockedLevels': currentUnlockedLevels + 1});
      }
    } else {
      await userRef.set({
        'totalScore': _currentScore,
        'unlockedLevels': _currentScore >= 80 ? 2 : 1,
        'chapters': {
          widget.chapterId: {
            'levelScores': {'Level $_currentLevel': _currentScore},
            'totalScore': _currentScore,
          }
        }
      });
    }
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return FittedBox(
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(value.toString(),
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> buttonColors = [
      Colors.blue.shade100,
      Colors.indigo.shade100,
      Colors.cyan.shade100,
      Colors.orange.shade100,
    ];
    return Scaffold(
      key: _scaffoldKey,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade100,
              Colors.white,

              Colors.blue.shade50,

            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(35.0),
              child: buildStatsRow(),
            ),
            Expanded(child: buildQuestionsStream(buttonColors)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.settings),
        onPressed: _openSettingsBottomSheet,
      ),
    );
  }

  /// Ouvre une fenêtre modale en bas de l'écran pour régler l'activation du son et de l'affichage de l'explication.
  void _openSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                ),
                child: Wrap(
                  children: [
                    SwitchListTile(
                      title: const Text('Activer le son'),
                      value: _soundEnabled,
                      onChanged: (bool value) async {
                        setModalState(() {
                          _soundEnabled = value;
                        });
                        setState(() {
                          _soundEnabled = value;
                        });
                        final prefs = await SharedPreferences.getInstance();
                        prefs.setBool('soundEnabled', _soundEnabled);
                      },
                    ),
                    SwitchListTile(
                      title: const Text("Afficher l'explication"),
                      value: _showExplanation,
                      onChanged: (bool value) async {
                        setModalState(() {
                          _showExplanation = value;
                        });
                        setState(() {
                          _showExplanation = value;
                        });
                        final prefs = await SharedPreferences.getInstance();
                        prefs.setBool('showExplanation', _showExplanation);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatCard('Score', _currentScore, Colors.blue.shade100),
        _buildStatCard('Progression', _currentIndex + 1, Colors.blue.shade100),
        StreamBuilder<int>(
          stream: _timerStreamController?.stream,
          builder: (context, snapshot) {
            if (snapshot.hasError || !snapshot.hasData) {
              return const SizedBox.shrink();
            }
            return _buildStatCard('Temps'.tr(), snapshot.data ?? 25, Colors.orange);
          },
        ),
      ],
    );
  }

  StreamBuilder<QuerySnapshot> buildQuestionsStream(List<Color> buttonColors) {
    int adjustedLevel = (widget.level - 1) % 36 + 1;
    obtenirChapitrePourNiveau(widget.level);
    String collectionPath = 'chapters/${widget.chapterId}/levels/Level$adjustedLevel/questions';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chapters')
          .doc(widget.chapterId)
          .collection('levels')
          .doc('Level $adjustedLevel')
          .collection('questions')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Erreur lors du chargement des questions : ${snapshot.error}');
          return Center(child: Text('Une erreur s\'est produite'.tr()));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        List<QueryDocumentSnapshot>? questions = snapshot.data?.docs;
        if (questions == null || questions.isEmpty) {
          print('Aucune question trouvée pour le niveau $adjustedLevel');
          return Center(child: Text('Aucune question trouvée'.tr()));
        }
        if (_currentIndex >= questions.length) {
          print('Index actuel $_currentIndex supérieur au nombre de questions ${questions.length}');
          return Center(child: Text('Aucune question trouvée'.tr()));
        }
        final question = questions[_currentIndex];
        final questionData = question.data() as Map<String, dynamic>;
        if (!questionData.containsKey('question') ||
            !questionData.containsKey('options') ||
            !questionData.containsKey('correctAnswer') ||
            !questionData.containsKey('explanation')) {
          print('Document manquant de champs requis: $questionData');
          return const SizedBox.shrink();
        }
        final questionText = questionData['question'] as String;
        final List<dynamic> options = questionData['options'] as List<dynamic>;
        final int correctAnswerIndex = questionData['correctAnswer'] as int;
        if (correctAnswerIndex < 0 || correctAnswerIndex >= options.length) {
          print('Indice de la réponse correcte hors limites: $correctAnswerIndex');
          return const SizedBox.shrink();
        }
        // Mélange des options
        final shuffledResult = shuffleOptions(options.cast<String>(), correctAnswerIndex);
        final shuffledOptions = shuffledResult['shuffledOptions'] as List<String>;
        final newCorrectAnswerIndex = shuffledResult['correctAnswerIndex'] as int;
        final String imagePath = questionData['imagePath'] as String? ?? '';
        final String explanation = questionData['explanation'] as String;
        return buildQuestionWidget(
          questionText,
          shuffledOptions,
          shuffledOptions[newCorrectAnswerIndex],
          imagePath,
          explanation,
          buttonColors,
        );
      },
    );
  }

  /// Fonction pour mélanger les options et recalculer l'indice de la bonne réponse.
  Map<String, dynamic> shuffleOptions(List<String> options, int correctAnswerIndex) {
    final random = Random();
    final indexedOptions = List.generate(options.length, (index) => index);
    indexedOptions.shuffle(random);
    final shuffledOptions = indexedOptions.map((index) => options[index]).toList();
    final newCorrectAnswerIndex = indexedOptions.indexOf(correctAnswerIndex);
    return {
      'shuffledOptions': shuffledOptions,
      'correctAnswerIndex': newCorrectAnswerIndex,
    };
  }

  FutureBuilder<String?> buildQuestionWidget(
      String questionText,
      List<dynamic> options,
      String correctAnswer,
      String? imagePath,
      String explanation,
      List<Color> buttonColors,
      ) {
    return FutureBuilder<String?>(
      future: imagePath != null && imagePath.isNotEmpty
          ? FirebaseStorageService.instance.getDownloadUrl(imagePath)
          : Future.value(null),
      builder: (context, imageUrlSnapshot) {
        String? imageUrl = imageUrlSnapshot.data;
        if (imageUrl != null) {
          print('Image URL: $imageUrl');
        }
        // Lancer le TTS de la question après 700 ms, uniquement si le quiz est actif.
        if (!_questionSpoken && _soundEnabled && mounted && _quizActive) {
          _questionSpoken = true;
          Future.delayed(Duration(milliseconds: 700), () {
            if (mounted && _quizActive) {
              _speak(questionText);
            }
          });
        }
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RotatingGlowBorder(
              borderWidth: glowWidth,
              colors: [Colors.cyanAccent, Colors.indigoAccent, Colors.orangeAccent],
              duration: const Duration(seconds: 30),
              child: Padding(
                padding: EdgeInsets.all(glowWidth), // <-- espace pour laisser passer le glow
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    margin: const EdgeInsets.all(5),
                    padding: const EdgeInsets.all(12),
                    color: Colors.white,  // plein blanc pour l'intérieur
                    child: Column(
                      children: [
                        Text(
                          'Question ${_currentIndex + 1} :',
                          style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          questionText,
                          style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 10.0, bottom: 20.0),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  height: MediaQuery.of(context).size.height * 0.2,
                  width: MediaQuery.of(context).size.width * 0.7,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              )
            else
              const SizedBox(height: 30.0),
            Expanded(
              child: GridView.count(
                crossAxisCount: 1,
                padding: const EdgeInsets.all(8.0),
                mainAxisSpacing: 16.0,
                crossAxisSpacing: 10.0,
                childAspectRatio: 4.0,
                children: options.asMap().entries.map((entry) {
                  int index = entry.key;
                  String option = entry.value;
                  Color buttonColor = buttonColors[index % 4];
                  String letter = String.fromCharCode(65 + index);
                  return GestureDetector(
                    onTap: () async {
                      if (hasAnswered) return; // Empêche les doubles clics.
                      hasAnswered = true;
                      // Arrête la lecture TTS en cours
                      await flutterTts.stop();
                      // Gérer la réponse : jouer le son puis la voix si le son est activé.
                      await _handleUserAnswer(option, correctAnswer);
                      if (_showExplanation) {
                        _showExplanationDialog(explanation);
                      } else {
                        _nextQuestion();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [buttonColor.withOpacity(0.7), buttonColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Container(
                              width: 40.0,
                              height: 40.0,
                              decoration: BoxDecoration(
                                color: buttonColor,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Center(
                                child: Text(
                                  letter,
                                  style: TextStyle(
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10.0),
                            Expanded(
                              child: AutoSizeText(
                                option,
                                style: TextStyle(
                                  fontSize: 18.0,
                                  color: Colors.blue.shade800,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Affiche une boîte de dialogue avec l'explication et un bouton « Continuer ».
  /// La lecture de l'explication est lancée avec un délai de 1500 ms pour laisser le temps au son de réponse de se terminer.
  void _showExplanationDialog(String explanation) {
    if (_soundEnabled) {
      Future.delayed(Duration(milliseconds: 1500), () {
        _speak(explanation);
      });
    }
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          backgroundColor: Colors.brown[200],
          title: Text(
            'Explication'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.teal.shade400,
              fontWeight: FontWeight.bold,
              fontSize: 20.0,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    color: Colors.brown[200],
                    child: Text(
                      explanation,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 18.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (isCorrect != null)
                  Icon(
                    isCorrect! ? Icons.check_circle : Icons.cancel,
                    color: isCorrect! ? Colors.teal : Colors.red,
                    size: 40,
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
          actions: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await flutterTts.stop();
                  _nextQuestion();
                },
                child: Text(
                  'Continuer'.tr(),
                  style: TextStyle(
                    color: Colors.teal,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
