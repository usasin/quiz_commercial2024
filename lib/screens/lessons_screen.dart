import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'simulation.dart' as custom_simulation;
import '../drawer/custom_bottom_nav_bar.dart';
import '../services/lesson_utils.dart';
import 'compte_rendu_screen.dart';
import 'simulation_learn.dart';

class LessonsScreen extends StatefulWidget {
  final VoidCallback? onItemTapped;

  LessonsScreen({this.onItemTapped});

  @override
  _LessonsScreenState createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, int> chapterScores = {}; // Score total pour chaque chapitre
  final int chapterReportUnlockScore = 1700; // Score pour débloquer les compte rendus

  @override
  void initState() {
    super.initState();
    _initializeChapterScores();
  }

  Future<void> _initializeChapterScores() async {
    Map<String, int> scores = await fetchChapterScores();
    setState(() {
      chapterScores = scores;
    });
  }

  Future<Map<String, int>> fetchChapterScores() async {
    final user = FirebaseAuth.instance.currentUser;
    Map<String, int> chapterScores = {};

    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();

        if (data != null && data.containsKey('chapters')) {
          final chaptersData = data['chapters'] as Map<String, dynamic>;

          for (var chapterId in chaptersData.keys) {
            final chapterData = chaptersData[chapterId] as Map<String, dynamic>;
            final chapterTotalScore = int.tryParse(chapterData['totalScore'].toString()) ?? 0;
            chapterScores[chapterId] = chapterTotalScore;
          }
        }
      }
    }

    return chapterScores;
  }

  bool _isReportUnlocked(int chapterScore) {
    return chapterScore >= chapterReportUnlockScore;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white70, Colors.white, Colors.white],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 45),
            Container(
              height: 120,
              width: 120,
              child: Lottie.asset('assets/animation_book1.json', fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.brown.shade50,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: Offset(4, 6),
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.blue.shade50],
                ),
              ),
              child: Center(
                child: Text(
                  'Amusez-vous avec nos quizz pour ouvrir les portes de nouvelles leçons passionnantes !',
                  style: TextStyle(fontSize: 14, color: Colors.blue.shade800, fontWeight: FontWeight.normal),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Expanded(
              child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('chapters')
                    .orderBy('numberOfQuizzes', descending: false)
                    .get(),
                builder: (context, chapterSnapshot) {
                  if (chapterSnapshot.hasError) {
                    print('Erreur: ${chapterSnapshot.error}');
                    return const Center(child: Text('Une erreur s\'est produite'));
                  }

                  if (chapterSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final chapters = chapterSnapshot.data!.docs;
                  // Trier les chapitres par score décroissant
                  final sortedChapters = chapters..sort((a, b) {
                    final scoreA = chapterScores[a.id] ?? 0;
                    final scoreB = chapterScores[b.id] ?? 0;
                    return scoreB.compareTo(scoreA); // Score décroissant
                  });

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('lessons')
                        .orderBy('lessonNumber', descending: false)
                        .snapshots(),
                    builder: (context, lessonSnapshot) {
                      if (lessonSnapshot.hasError) {
                        print('Erreur: ${lessonSnapshot.error}');
                        return const Center(child: Text('Une erreur s\'est produite'));
                      }

                      if (lessonSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> chapterModules = {};

                      for (var doc in lessonSnapshot.data!.docs) {
                        final module = doc as QueryDocumentSnapshot<Map<String, dynamic>>;
                        final chapterId = module.data()['chapterId'] as String? ?? 'unknown';
                        if (!chapterModules.containsKey(chapterId)) {
                          chapterModules[chapterId] = [];
                        }
                        chapterModules[chapterId]!.add(module);
                      }

                      List<Widget> widgets = [];

                      for (var chapterDoc in chapters) {
                        final chapterData = chapterDoc.data();
                        final chapterId = chapterDoc.id;
                        final chapterTitle = chapterData['title'] ?? 'Titre du chapitre';
                        final chapterLogo = chapterData['logo'] ?? '';
                        final numberOfQuizzes = chapterData['numberOfQuizzes'] ?? 0;

                        int chapterScore = chapterScores[chapterId] ?? 0;

                        widgets.add(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 10),
                              chapterLogo.isNotEmpty
                                  ? Image.asset(
                                'assets/$chapterLogo',
                                height: 70,
                                width: 330,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.broken_image, size: 70, color: Colors.grey);
                                },
                              )
                                  : Icon(Icons.book, size: 70, color: Colors.orange.shade400),
                              const SizedBox(height: 10),
                              Text(
                                chapterTitle,
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Nombre de Quiz: $numberOfQuizzes',
                                style: TextStyle(fontSize: 16, color: Colors.yellow.shade700),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              // Les modules de ce chapitre
                              ...chapterModules[chapterId]!.asMap().entries.map((entry) {
                                int moduleIndex = entry.key;
                                var module = entry.value;

                                return buildLessonCard(
                                  context,
                                  module,
                                  chapterScore,
                                  chapterId,
                                  moduleIndex,
                                );
                              }).toList(),
                              const SizedBox(height: 10),
                              // Bouton "Compte Rendu" débloqué par le score
                              Column(
                                children: [
                                  // Carte pour "Apprendre avec IA"
                                  // Carte pour "Apprendre avec IA"
                                  Card(
                                    color: _isReportUnlocked(chapterScore) ? Colors.blue.shade50 : Colors.grey.shade300,
                                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: _isReportUnlocked(chapterScore) ? Colors.blue.shade400 : Colors.grey,
                                        width: 3,
                                      ),
                                    ),
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.school,
                                        color: _isReportUnlocked(chapterScore) ? Colors.blue.shade400 : Colors.grey,
                                      ),
                                      title: Center(
                                        child: Text(
                                          'Apprendre avec IA',
                                          style: TextStyle(
                                            color: _isReportUnlocked(chapterScore) ? Colors.blue.shade800 : Colors.grey.shade600,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      onTap: _isReportUnlocked(chapterScore)
                                          ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SimulationLearn(chapterId: chapterId),
                                          ),
                                        );
                                      }
                                          : null,
                                    ),
                                  ),

// Carte pour "Mode Libre"
                                  Card(
                                    color: _isReportUnlocked(chapterScore) ? Colors.orange.shade50 : Colors.grey.shade300,
                                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: _isReportUnlocked(chapterScore) ? Colors.orange.shade400 : Colors.grey,
                                        width: 3,
                                      ),
                                    ),
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.mic,
                                        color: _isReportUnlocked(chapterScore) ? Colors.orange.shade400 : Colors.grey,
                                      ),
                                      title: Center(
                                        child: Text(
                                          'Mode Libre',
                                          style: TextStyle(
                                            color: _isReportUnlocked(chapterScore) ? Colors.orange.shade800 : Colors.grey.shade600,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      onTap: _isReportUnlocked(chapterScore)
                                          ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => custom_simulation.Simulation(chapterId: chapterId),
                                          ),
                                        );
                                      }
                                          : null,
                                    ),
                                  ),

// Carte pour "Compte Rendu"
                                  Card(
                                    color: _isReportUnlocked(chapterScore) ? Colors.green.shade50 : Colors.grey.shade300,
                                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: _isReportUnlocked(chapterScore) ? Colors.green.shade400 : Colors.grey,
                                        width: 3,
                                      ),
                                    ),
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.description,
                                        color: _isReportUnlocked(chapterScore) ? Colors.green.shade400 : Colors.grey,
                                      ),
                                      title: Center(
                                        child: Text(
                                          'Compte Rendu',
                                          style: TextStyle(
                                            color: _isReportUnlocked(chapterScore) ? Colors.green.shade800 : Colors.grey.shade600,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      onTap: _isReportUnlocked(chapterScore)
                                          ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CompteRenduScreen(
                                              chapterId: chapterId,

                                            ),
                                          ),
                                        );
                                      }
                                          : null,
                                    ),
                                  ),

                                ],
                              ),


                            ],
                          ),
                        );
                      }

                      return ListView(
                        children: widgets,
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        parentContext: context,
        currentIndex: 2,
        scaffoldKey: _scaffoldKey,
      ),
    );
  }
}
