import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../drawer/custom_bottom_nav_bar.dart';
import '../logo_widget.dart';
import '../services/firestore_service.dart';
import '../services/models.dart';
import 'compte_rendu_screen.dart';
import 'module_page.dart';
import 'quiz_screen.dart';
import 'simulation.dart' as custom_simulation;

import 'simulation_learn.dart';


class LevelsPage extends StatefulWidget {
  const LevelsPage({Key? key}) : super(key: key);

  @override
  _LevelsPageState createState() => _LevelsPageState();
}

class _LevelsPageState extends State<LevelsPage> {
  List<Chapter> chapters = [];
  final FirestoreService _firestoreService = FirestoreService();
  int unlockedLevels = 1;
  int totalScore = 0;
  int unlockedLessons = 0;
  int chapter1Score = 0; // Ajouter les scores pour chaque chapitre
  int chapter2Score = 0;
  int chapter3Score = 0;
  Map<String, int> unlockedLevelsPerChapter = {
  }; // Niveaux débloqués par chapitre
  Map<String, int> totalScorePerChapter = {}; // Score total par chapitre
  Map<String, int> unlockedModulesPerChapter = {
  }; // Modules débloqués par chapitre
  ScrollController _scrollController = ScrollController();
  String lastPlayedChapterId = '';

  @override
  void initState() {
    super.initState();
    _fetchChapters();
    _fetchUserData();
  }

  void _fetchChapters() async {
    chapters = await _firestoreService.getChapters();
    setState(() {});
  }

// Récupérer les données utilisateur depuis Firestore et Firebase Auth
  void _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Référence utilisateur dans Firestore
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      try {
        DocumentSnapshot userDoc = await userRef.get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

          // Récupération des données principales
          int newTotalScore = userData['totalScore'] ?? 0;

          // Scores par chapitre
          Map<String, int> newTotalScorePerChapter = Map<String, int>.from(
            userData['chapters']?.map((key, value) => MapEntry(key, value['totalScore'] ?? 0)) ?? {},
          );

          // Niveaux débloqués par chapitre
          Map<String, int> newUnlockedLevelsPerChapter = Map<String, int>.from(
            userData['unlockedLevels'] ?? {},
          );

          // Position de défilement sauvegardée pour chaque chapitre
          Map<String, dynamic> savedScrollPositions = userData['scrollPositions'] ?? {};

          // Modules débloqués par chapitre
          Map<String, int> newUnlockedModulesPerChapter = {};

          // Calcul des modules débloqués pour chaque chapitre
          for (Chapter chapter in chapters) {
            int scoreForCurrentChapter = newTotalScorePerChapter[chapter.id] ?? 0;

            // Si aucun niveau débloqué n'est enregistré pour un chapitre, initialisez à 1
            if (!newUnlockedLevelsPerChapter.containsKey(chapter.id)) {
              newUnlockedLevelsPerChapter[chapter.id] = 1;
            }

            // Calcul des modules débloqués (1 module débloqué tous les 270 points)
            newUnlockedModulesPerChapter[chapter.id] =
            (scoreForCurrentChapter >= 270) ? (scoreForCurrentChapter ~/ 270) : 0;
          }

          // Dernier chapitre joué
          lastPlayedChapterId = userData['lastChapterId'] ?? chapters.first.id;

          // Position de défilement sauvegardée
          double savedScrollPosition = savedScrollPositions[lastPlayedChapterId] ?? 0.0;

          // Mettre à jour l'état de l'application
          setState(() {
            totalScore = newTotalScore;
            totalScorePerChapter = newTotalScorePerChapter;
            unlockedLevelsPerChapter = newUnlockedLevelsPerChapter;
            unlockedModulesPerChapter = newUnlockedModulesPerChapter;
          });

          // Ajuster la position de défilement après chargement
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(savedScrollPosition);
            }
          });
        } else {
          print("Les données de l'utilisateur sont nulles ou le document n'existe pas.");
        }
      } catch (error) {
        print("Erreur lors de la récupération des données utilisateur : $error");
      }
    } else {
      print("Aucun utilisateur authentifié.");
    }
  }




  Widget _buildSimulationButtons(Chapter chapter) {
    int quizzesCompleted = unlockedLevelsPerChapter[chapter.id] ?? 1;
    bool isSimulationUnlocked = quizzesCompleted >= chapter.numberOfQuizzes;

    return Column(
      children: [
        // Bouton "Apprendre avec IA"
        InkWell(
          onTap: isSimulationUnlocked
              ? () =>
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SimulationLearn(chapterId: chapter.id),
                ),
              )
              : null,
          child: _buildButton(
            isUnlocked: isSimulationUnlocked,
            icon: Icons.school,
            text: "Apprendre avec IA",
            color: Colors.blue.shade300,
            unlockedTextColor: Colors.blue.shade900,
            unlockedIconColor: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 5),

        // Bouton "Mode Libre"
        InkWell(
          onTap: isSimulationUnlocked
              ? () =>
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      custom_simulation.Simulation(chapterId: chapter.id),
                ),
              )
              : null,
          child: _buildButton(
            isUnlocked: isSimulationUnlocked,
            icon: Icons.mic,
            text: "Mode libre",
            color: Colors.orange.shade200,
            unlockedTextColor: Colors.orange.shade900,
            unlockedIconColor: Colors.orange.shade800,
          ),
        ),
        const SizedBox(height: 5),

        // Nouveau bouton "Compte Rendu"
        InkWell(
          onTap: isSimulationUnlocked
              ? () =>
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CompteRenduScreen(
                        chapterId: chapter.id,

                      ),
                ),
              )
              : null,
          child: _buildButton(
            isUnlocked: isSimulationUnlocked,
            icon: Icons.article,
            text: "Compte Rendu",
            color: Colors.green.shade400,
            unlockedTextColor: Colors.green.shade900,
            unlockedIconColor: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  Widget _buildButton({
    required bool isUnlocked,
    required IconData icon,
    required String text,
    required Color color,
    required Color unlockedTextColor,
    required Color unlockedIconColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUnlocked
              ? [color.withOpacity(0.7), color.withOpacity(0.4)]
              : [Colors.grey.shade400, Colors.grey.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.4),
            offset: Offset(2, 2),
            blurRadius: 6,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            offset: Offset(-2, -2),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Icon(
                icon,
                size: 30,
                color: isUnlocked ? unlockedIconColor : Colors.grey.shade600,
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isUnlocked ? unlockedTextColor : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Gestion du clic sur un niveau
  void _handleLevelTap(BuildContext context, int level, Chapter chapter,
      bool isUnlocked) {
    if (isUnlocked) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              QuizScreen(
                level: level,
                chapterId: chapter.id,
                onLevelCompleted: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    DocumentReference userRef = FirebaseFirestore.instance
                        .collection('users').doc(user.uid);

                    if (unlockedLevelsPerChapter.containsKey(chapter.id)) {
                      await userRef.update({
                        'unlockedLevels.${chapter.id}': FieldValue.increment(1),
                      });
                    } else {
                      await userRef.update({
                        'unlockedLevels.${chapter.id}': 2,
                      });
                    }

                    double currentScrollPosition = _scrollController.position
                        .pixels;
                    await userRef.update({
                      'lastChapterId': chapter.id,
                      'scrollPositions.${chapter.id}': currentScrollPosition,
                    });

                    setState(() {
                      lastPlayedChapterId = chapter.id;
                      unlockedLevelsPerChapter[chapter.id] =
                          (unlockedLevelsPerChapter[chapter.id] ?? 1) + 1;
                    });
                  }
                },
              ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Ce niveau est verrouillé. Veuillez terminer le niveau précédent.'),
      ));
    }
  }

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _buildLevelButton(int level, Chapter chapter, bool isUnlocked) {
    bool isNextLevelToPlay = (level ==
        (unlockedLevelsPerChapter[chapter.id] ?? 1));
    bool isCompleted = (level < (unlockedLevelsPerChapter[chapter.id] ?? 1));

    BoxShadow shadow = BoxShadow(
      color: Colors.brown.shade50,
      blurRadius: 10.0,
      spreadRadius: 4.0,
    );

    return _getButtonWithOptionalLottie(
      level,
      Padding(
        padding: _getPaddingForButton(level),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            children: [
              // Remplacer l'animation Lottie gagnant par un effet lumineux pour le prochain niveau et le rendre cliquable
              if (isNextLevelToPlay)
                InkWell(
                  onTap: () =>
                      _handleLevelTap(context, level, chapter, isUnlocked),
                  child: AnimatedContainer(
                    duration: Duration(seconds: 1),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.brown.shade50, Colors.green.shade50],
                        // Effet lumineux
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.yellow.shade700.withOpacity(0.6),
                          blurRadius: 15.0,
                          spreadRadius: 6.0,
                        ),
                      ],
                    ),
                    width: 70,
                    height: 70,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.published_with_changes_sharp, size: 40,
                              color: Colors.green),
                          const SizedBox(height: 2),
                          Text(
                            'Quizz $level',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Le bouton de niveau standard avec ou sans verrouillage
              if (!isNextLevelToPlay)
                InkWell(
                  onTap: () =>
                      _handleLevelTap(context, level, chapter, isUnlocked),
                  child: Card(
                    elevation: 5.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: isUnlocked
                            ? LinearGradient(
                          colors: [Colors.white, _getLevelColor(
                              (level - 1) ~/ 3 + 1)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : LinearGradient(
                          colors: [Colors.black87, Colors.black54],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15.0),
                        boxShadow: isNextLevelToPlay ? [shadow] : null,
                      ),
                      child: Center(
                        child: isUnlocked
                            ? (isCompleted
                            ? Icon(Icons.check, size: 40, color: Colors.white)
                            : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.published_with_changes_sharp, size: 25,
                                color: Colors.green.shade100),
                            const SizedBox(height: 8),
                            Text(
                              'Quizz $level',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                          ],
                        ))
                            : Icon(Icons.lock, size: 40, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

// Conserver les animations Lottie "sales" et "quiz"
  Widget _getButtonWithOptionalLottie(int level, Widget button) {
    return Stack(
      alignment: Alignment.center,
      children: [
        button,
        if (level % 8 == 3)
          Positioned(
            left: 20,
            child: Lottie.asset('assets/Animation_salesstat.json',
                width: 120, height: 100, fit: BoxFit.cover),
          ),
        if (level % 8 == 7)
          Positioned(
            right: 20,
            child: Lottie.asset('assets/Animation_quiz.json',
                width: 120, height: 100, fit: BoxFit.cover),
          ),
      ],
    );
  }


  Color _getLevelColor(int levelColor) {
    switch (levelColor) {
      case 1:
        return Colors.blue.shade300;
      case 2:
        return Colors.amber.shade300;
      case 3:
        return Colors.red.shade300;
      case 4:
        return Colors.green.shade300;
      default:
        return Colors.indigo.shade300;
    }
  }

  EdgeInsetsGeometry _getPaddingForButton(int level) {
    double offset = 40.0;
    switch (level % 8) {
      case 0:
        return EdgeInsets.only(right: offset * 3);
      case 1:
        return EdgeInsets.zero;
      case 2:
        return EdgeInsets.only(left: offset * 3);
      case 3:
        return EdgeInsets.only(left: offset * 5.5);
      case 4:
        return EdgeInsets.only(left: offset * 3);
      case 5:
        return EdgeInsets.zero;
      case 6:
        return EdgeInsets.only(right: offset * 3);
      case 7:
        return EdgeInsets.only(right: offset * 5.5);
      default:
        return EdgeInsets.zero;
    }
  }

  List<Widget> _buildChapterWidgets(Chapter chapter) {
    bool isLastPlayedChapter = (chapter.id == lastPlayedChapterId);
    bool isCompletedChapter = (unlockedLevelsPerChapter[chapter.id] ?? 1) > 1;

    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: isCompletedChapter
                  ? LinearGradient(
                colors: [Colors.green.shade50, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : LinearGradient(
                colors: [Colors.brown.shade50, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: ExpansionTile(
              initiallyExpanded: isLastPlayedChapter,
              title: Row(
                children: [
                  Icon(
                    Icons.menu_book,
                    color: Colors.blue.shade800,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AutoSizeText(
                      chapter.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                      maxLines: 1,
                      minFontSize: 12,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              children: <Widget>[
                _buildParcoursNumberWidget(1, 0, true, chapter.id),
                ..._buildLevelAndParcoursWidgets(chapter),
                _buildSimulationButtons(chapter),
                // Remplacer par _buildSimulationButtons
              ],
            ),
          ),
        ),
      ),
    ];
  }


  List<Widget> _buildLevelAndParcoursWidgets(Chapter chapter) {
    List<Widget> levelAndParcoursWidgets = [];
    int parcoursNumber = 1;



    for (int i = 0; i < chapter.numberOfQuizzes; i++) {
      bool isUnlocked = i + 1 <= (unlockedLevelsPerChapter[chapter.id] ?? 1);

      levelAndParcoursWidgets.add(
          _buildLevelButton(i + 1, chapter, isUnlocked));

      if ((i + 1) % 3 == 0) {
        parcoursNumber = (i + 1) ~/ 3 + 1;

        int scoreForCurrentChapter = totalScorePerChapter[chapter.id] ?? 0;

        bool isParcoursUnlocked = (scoreForCurrentChapter ~/ 270) >=
            (parcoursNumber - 1);

        levelAndParcoursWidgets.add(
          _buildParcoursNumberWidget(
              parcoursNumber, i + 1, isParcoursUnlocked, chapter.id),
        );
      }
    }

    return levelAndParcoursWidgets;
  }

  Widget _buildParcoursNumberWidget(int parcoursNumber, int level,
      bool isUnlocked, String chapterId) {
    return Padding(
      padding: _getPaddingForParcoursNumber(level),
      child: InkWell(
        onTap: () async {
          if (isUnlocked) {
            QuerySnapshot snapshot = await FirebaseFirestore.instance
                .collection('lessons')
                .where('parcoursNumber', isEqualTo: parcoursNumber)
                .where('chapterId', isEqualTo: chapterId)
                .limit(1)
                .get();

            if (snapshot.docs.isEmpty) {
              print(
                  "Aucun module trouvé pour parcoursNumber: $parcoursNumber dans le chapitre $chapterId");
              return;
            }

            DocumentSnapshot module = snapshot.docs.first;
            String moduleId = module.id;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ModulePage(
                      parcoursNumber: parcoursNumber,
                      moduleId: moduleId,
                      chapterId: chapterId,
                    ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ce parcours est verrouillé.')),
            );
          }
        },
        child: SizedBox(
          width: 170,
          height: 170,
          child: ColorFiltered(
            colorFilter: isUnlocked
                ? ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                : ColorFilter.mode(Colors.grey, BlendMode.saturation),
            child: Lottie.asset('assets/Animation_gagner.json'),
          ),
        ),
      ),
    );
  }

  EdgeInsetsGeometry _getPaddingForParcoursNumber(int level) {
    double offset = 40.0;
    switch (level % 8) {
      case 0:
        return EdgeInsets.only(right: offset * 1.5);
      case 1:
        return EdgeInsets.only(left: offset * 1.5);
      case 2:
        return EdgeInsets.only(left: offset * 4.5);
      case 3:
        return EdgeInsets.only(left: offset * 4.5);
      case 4:
        return EdgeInsets.only(left: offset * 1.5);
      case 5:
        return EdgeInsets.only(right: offset * 1.5);
      case 6:
        return EdgeInsets.only(right: offset * 4.5);
      case 7:
        return EdgeInsets.only(right: offset * 4.5);
      default:
        return EdgeInsets.zero;
    }
  }

  Widget build(BuildContext context) {
    if (chapters.isEmpty) {
      return Scaffold(
        key: _scaffoldKey,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> children = [];
    for (var chapter in chapters) {
      children.addAll(_buildChapterWidgets(chapter));
    }

    int totalModulesUnlocked = unlockedModulesPerChapter.values.fold(
        0, (sum, value) => sum + value);
    int totalUnlockedLevels = unlockedLevelsPerChapter.values.fold(
        0, (sum, value) => sum + value);

    return Scaffold(
      key: _scaffoldKey,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white38, Colors.white10, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              const SizedBox(height: 50),
              Container(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    LogoWidget(),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              _buildUserStats(
                  totalScore, totalUnlockedLevels, totalModulesUnlocked),
              const SizedBox(height: 20),
              Text(
                "L'Académie des Commerciaux Performants",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                  fontFamily: 'Arial',
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.white,
                      offset: Offset(3, 3),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              ...children,
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        parentContext: context,
        currentIndex: 0,
        scaffoldKey: _scaffoldKey,
      ),
    );
  }


  Widget _buildUserStats(int totalScore, int totalUnlockedLevels, int totalModulesUnlocked) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 3,
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.score,
            iconColor: Colors.blue.shade700,
            label: "Score",
            value: totalScore.toString(),
          ),
          _buildStatItem(
            icon: Icons.star,
            iconColor: Colors.orange.shade700,
            label: "Niveaux",
            value: totalUnlockedLevels.toString(),
          ),
          _buildStatItem(
            icon: Icons.book,
            iconColor: Colors.green.shade700,
            label: "Modules",
            value: totalModulesUnlocked.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Vous avez $value $label.')),
            );
          },
          child: CircleAvatar(
            radius: 30,
            backgroundColor: iconColor.withOpacity(0.2),
            child: Icon(icon, color: iconColor, size: 35),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

 }