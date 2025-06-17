import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lottie/lottie.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:quiz_commercial2024/screens/chapter_menu_page.dart';
import 'package:quiz_commercial2024/screens/simulation.dart';
import 'package:shimmer/shimmer.dart';
import '../ad_manager.dart';
import '../drawer/custom_bottom_nav_bar.dart';
import '../rotating_glow_border.dart';
import '../services/firestore_service.dart';
import '../services/models.dart';
import 'compte_rendu_screen.dart';
import 'module_page.dart';
import 'quiz_screen.dart';
import 'package:collection/collection.dart';

class LevelsPage extends StatefulWidget {
  const LevelsPage({Key? key}) : super(key: key);

  @override
  _LevelsPageState createState() => _LevelsPageState();
}

class _LevelsPageState extends State<LevelsPage> with SingleTickerProviderStateMixin {
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
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
  };// Modules débloqués par chapitre
  Map<String, double> savedScrollPositions = {}; // Ajouté ici
  ScrollController _scrollController = ScrollController();
  String lastPlayedChapterId = '';
  bool _introShown   = false;   // flag unique
  bool _showIntroNow = false;   // indique si on doit afficher le pop-up
  final GlobalKey _currentLevelKey = GlobalKey(); // Suivi du niveau "ici"
  Map<String, Map<int, int>> scoresPerLevel = {}; // Ajouté pour stocker les scores
  late final AnimationController _gradientCtrl;
  
  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();
    // → 2) Init du controller : tourne en boucle
    _gradientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _fetchChapters();
    _fetchUserData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (lastPlayedChapterId.isNotEmpty) {
        _showLastPlayedChapterDialog();
      }
    });
  }
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdManager.interstitialAdUnitId,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd(); // recharge pour la prochaine fois
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (err) {
          debugPrint('Échec chargement InterstitialAd: ${err.message}');
          _isInterstitialAdReady = false;
        },
      ),
    );
  }
// ─── 2.  didChangeDependencies corrigé ─────────────────────────────
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_introShown) {                                // ← on utilise _introShown
      final args = ModalRoute.of(context)?.settings.arguments
      as Map<String, dynamic>?;

      _showIntroNow = (args?['fromMenu'] == true);     // vient-on du bouton Parcours ?
      _introShown   = true;                            // on ne repassera plus ici

      if (_showIntroNow) {
        // laisse le build() se terminer avant d’ouvrir la boîte
        Future.microtask(_showIntroDialog);
      }
    }
  }
  // ───────── OPTIONNEL : pop-up réutilisable ─────────
  void _showIntroDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Comment progresser ?'.tr()),
        content: const Text(
          '1. Joue un QUIZ 🎯\n'
              '2. Gagne des LEÇONS 🏆\n'
              '3. Mets-toi en SITUATION 🤖',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveScrollPosition() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && _scrollController.hasClients) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'scrollPositions.${lastPlayedChapterId}': _scrollController.position.pixels,
        });
      } catch (error) {
        print("Erreur de sauvegarde : $error");
      }
    }
  }

  @override
  void dispose() {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && _scrollController.hasClients) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'scrollPositions.${lastPlayedChapterId}': _scrollController.position.pixels,
      }).catchError((error) {
        print("Erreur lors de la sauvegarde de la position : $error");
      });
    }
    _gradientCtrl.dispose();   // → 3) On arrête l’animation
    _saveScrollPosition();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToUnlockedLevel(String chapterId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      int nextLevel = unlockedLevelsPerChapter[chapterId] ?? 1;

      // 🔍 Trouver le widget du niveau débloqué
      final RenderObject? renderObject = _currentLevelKey.currentContext?.findRenderObject();

      if (renderObject is RenderBox && _scrollController.hasClients) {
        final double widgetPosition = renderObject.localToGlobal(Offset.zero).dy;
        final double screenHeight = MediaQuery.of(context).size.height;
        final double widgetHeight = renderObject.size.height;
        final double maxScrollExtent = _scrollController.position.maxScrollExtent;

        // 📌 Correction améliorée pour un centrage précis (+ ajustement de 150px)
        final double targetScrollOffset = (_scrollController.position.pixels + widgetPosition) - (screenHeight / 2) + (widgetHeight / 2) - 200;

        // 🚀 Correction supplémentaire : S'assurer qu'on ne dépasse pas la fin du scroll
        double clampedPosition = targetScrollOffset.clamp(0.0, maxScrollExtent);

        // 🔥 Animation plus rapide et fluide
        _scrollController.animateTo(
          clampedPosition,
          duration: const Duration(milliseconds: 600), // Accélération de l'animation
          curve: Curves.easeInOut, // Effet naturel et fluide
        );

        print("📜 Scroll ajusté avec précision pour Level $nextLevel à position $clampedPosition");
      } else {
        print("⚠️ Impossible de trouver la position du niveau débloqué !");
      }
    });
  }

  void _fetchChapters() async {
    try {
      chapters = await _firestoreService.getChapters();
      if (chapters.isEmpty) {
        print("Aucun chapitre trouvé.");
      } else {
        print("Chapitres récupérés : ${chapters.map((c) => c.title).toList()}");
      }
      setState(() {}); // Mettre à jour l'état
    } catch (error) {
      print("Erreur lors de la récupération des chapitres : $error");
      setState(() {
        chapters = [];
      });
    }
  }

  void _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      print("❌ Aucun utilisateur authentifié.");
      return;
    }

    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      DocumentSnapshot userDoc = await userRef.get();

      if (!userDoc.exists || userDoc.data() == null) {
        print("🔹 L'utilisateur est nouveau, initialisation des données...");
        await userRef.set({
          'totalScore': 0,
          'unlockedLevels': {},
          'unlockedModules': {},
          'scrollPositions': {},
          'lastChapterId': chapters.isNotEmpty ? chapters.first.id : '',
          'chapters': {},
        });
        userDoc = await userRef.get();
      }

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        // ✅ 1️⃣ Total Score Général
        int newTotalScore = userData['totalScore'] is int ? userData['totalScore'] : 0;

        // ✅ 2️⃣ Chargement des Scores par Chapitre
        Map<String, Map<int, int>> newScoresPerLevel = {};
        Map<String, int> newTotalScorePerChapter = {};

        if (userData['chapters'] is Map) {
          (userData['chapters'] as Map).forEach((chapterId, chapterData) {
            if (chapterData is Map && chapterData['levelScores'] is Map) {
              newScoresPerLevel[chapterId] = (chapterData['levelScores'] as Map).map(
                    (key, value) => MapEntry(int.parse(key.split(' ')[1]), value as int),
              );

              // ✅ Addition des scores des niveaux pour calculer le total du chapitre
              int chapterTotal = newScoresPerLevel[chapterId]!.values.fold(0, (sum, score) => sum + score);
              newTotalScorePerChapter[chapterId] = chapterTotal;
            }
          });
        }

        // ✅ 3️⃣ Chargement des Niveaux Débloqués
        Map<String, int> newUnlockedLevelsPerChapter = {};
        if (userData['unlockedLevels'] is Map) {
          newUnlockedLevelsPerChapter = Map<String, int>.from(userData['unlockedLevels']);
        }


        // ✅ 4️⃣ Chargement des Modules Débloqués (🔴 Correction ici 🔴)
        Map<String, int> newUnlockedModulesPerChapter = {};
        for (Chapter chapter in chapters) {
          int levelsUnlocked = newUnlockedLevelsPerChapter[chapter.id] ?? 0;
          int modulesUnlocked = 1; // Le premier module est toujours débloqué

          for (int i = 3; i <= levelsUnlocked; i += 3) {
            if ((newScoresPerLevel[chapter.id]?[i] ?? 0) >= 80) {
              modulesUnlocked++; // ✅ Ajouter un module SEULEMENT si le niveau correspondant a un score ≥ 80
            }
          }

          newUnlockedModulesPerChapter[chapter.id] = modulesUnlocked;
        }

        // ✅ 5️⃣ Dernier Chapitre Joué
        lastPlayedChapterId = userData['lastChapterId'] ?? (chapters.isNotEmpty ? chapters.first.id : '');

        // ✅ 6️⃣ Mise à jour Firestore si nécessaire
        await userRef.update({
          'unlockedModules': newUnlockedModulesPerChapter, // 🔥 Mettre à jour les modules débloqués
        });

        // ✅ 7️⃣ Mise à jour de l’état (UI)
        setState(() {
          totalScore = newTotalScore;
          scoresPerLevel = newScoresPerLevel;
          unlockedLevelsPerChapter = newUnlockedLevelsPerChapter;
          unlockedModulesPerChapter = newUnlockedModulesPerChapter;
          totalScorePerChapter = newTotalScorePerChapter; // ✅ Score total par chapitre
        });

        print("✅ Mise à jour réussie !");
        print("📌 Niveaux débloqués : $newUnlockedLevelsPerChapter");
        print("📌 Modules débloqués : $newUnlockedModulesPerChapter");
      } else {
        print("❌ Les données de l'utilisateur sont nulles ou le document n'existe pas.");
      }
    } catch (error) {
      print("❌ Erreur lors de la récupération des données utilisateur : $error");
    }
  }

  void _updateUnlockedModules(String chapterId, int parcoursNumber) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      int currentUnlockedModules = unlockedModulesPerChapter[chapterId] ?? 0;

      // 🔥 Vérification du déblocage
      print("🔍 Déblocage des modules : Actuel = $currentUnlockedModules, Nouveau = $parcoursNumber");

      if (parcoursNumber > currentUnlockedModules) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'chapters.$chapterId.unlockedModules': parcoursNumber,
        });

        setState(() {
          unlockedModulesPerChapter[chapterId] = parcoursNumber;
        });

        print("✅ Module $parcoursNumber débloqué pour $chapterId !");
      } else {
        print("❌ Le module $parcoursNumber est déjà débloqué.");
      }
    }
  }

  void _showLastPlayedChapterDialog() {
    Chapter? lastPlayedChapter = chapters.firstWhereOrNull(
          (chapter) => chapter.id == lastPlayedChapterId,
    );

    if (lastPlayedChapter != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Reprendre là où vous vous êtes arrêté".tr()),
            content: Text(
                "${"Vous avez terminé sur le chapitre :".tr()} ${lastPlayedChapter.title}"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK".tr()),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildSimulationButtons(Chapter chapter) {
    // nombre de quiz déjà validés
    int quizzesCompleted      = unlockedLevelsPerChapter[chapter.id] ?? 1;
    bool isSimulationUnlocked = quizzesCompleted >= chapter.numberOfQuizzes;

    return Column(
      children: [
        /* ──────────── Bouton « Apprendre avec IA »  (mode guidé) ──────────── */
        InkWell(
          onTap: isSimulationUnlocked
              ? () {
            if (_isInterstitialAdReady && _interstitialAd != null) {
              _interstitialAd!.show();
              // Quand l’ad est fermé, on navigue :
              _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  ad.dispose();
                  _loadInterstitialAd();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SimulationScreen(
                        chapterId: chapter.id,
                        guided: true,
                      ),
                    ),
                  );
                },
                onAdFailedToShowFullScreenContent: (ad, err) {
                  ad.dispose();
                  _loadInterstitialAd();
                  // en cas d’erreur d’affichage, on navigue quand même
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SimulationScreen(
                        chapterId: chapter.id,
                        guided: true,
                      ),
                    ),
                  );
                },
              );
            } else {
              // Si l’ad n’est pas prête, on navigue directement
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SimulationScreen(
                    chapterId: chapter.id,
                    guided: true,
                  ),
                ),
              );
            }
          }
              : null,
          child: Tooltip(
            message: isSimulationUnlocked
                ? ""
                : "Terminez le chapitre pour débloquer".tr(),
            child: _buildButton(
              isUnlocked: isSimulationUnlocked,
              icon: Icons.school,
              text: "Apprendre avec IA".tr(),
              color: Colors.blue.shade300,
              unlockedTextColor: Colors.blue.shade900,
              unlockedIconColor: Colors.blue.shade800,
            ),
          ),
        ),
        const SizedBox(height: 5),

        /* ──────────── Bouton « Mode libre »  (guided = false) ──────────── */
        InkWell(
          onTap: isSimulationUnlocked
              ? () {
            if (_isInterstitialAdReady && _interstitialAd != null) {
              _interstitialAd!.show();
              _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  ad.dispose();
                  _loadInterstitialAd();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SimulationScreen.free(
                        chapterId: chapter.id,
                      ),
                    ),
                  );
                },
                onAdFailedToShowFullScreenContent: (ad, err) {
                  ad.dispose();
                  _loadInterstitialAd();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SimulationScreen.free(
                        chapterId: chapter.id,
                      ),
                    ),
                  );
                },
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SimulationScreen.free(
                    chapterId: chapter.id,
                  ),
                ),
              );
            }
          }
              : null,
          child: Tooltip(
            message: isSimulationUnlocked
                ? ""
                : "Terminez le chapitre pour débloquer".tr(),
            child: _buildButton(
              isUnlocked: isSimulationUnlocked,
              icon: Icons.mic,
              text: "Mode libre".tr(),
              color: Colors.orange.shade200,
              unlockedTextColor: Colors.orange.shade900,
              unlockedIconColor: Colors.orange.shade800,
            ),
          ),
        ),
        const SizedBox(height: 5),

        /* ──────────── Bouton « Compte-rendu » ──────────── */
        InkWell(
          onTap: isSimulationUnlocked
              ? () {
            if (_isInterstitialAdReady && _interstitialAd != null) {
              _interstitialAd!.show();
              _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  ad.dispose();
                  _loadInterstitialAd();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CompteRenduScreen(
                        chapterId: chapter.id,
                      ),
                    ),
                  );
                },
                onAdFailedToShowFullScreenContent: (ad, err) {
                  ad.dispose();
                  _loadInterstitialAd();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CompteRenduScreen(
                        chapterId: chapter.id,
                      ),
                    ),
                  );
                },
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CompteRenduScreen(
                    chapterId: chapter.id,
                  ),
                ),
              );
            }
          }
              : null,
          child: Tooltip(
            message: isSimulationUnlocked
                ? ""
                : "Terminez le chapitre pour débloquer".tr(),
            child: _buildButton(
              isUnlocked: isSimulationUnlocked,
              icon: Icons.article,
              text: "Compte Rendu".tr(),
              color: Colors.green.shade400,
              unlockedTextColor: Colors.green.shade900,
              unlockedIconColor: Colors.green.shade800,
            ),
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
    return GlassmorphicContainer(
      width: double.infinity,
      height: 60,
      borderRadius: 15,
      blur: 12,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        colors: isUnlocked
            ? [color.withOpacity(0.3), color.withOpacity(0.1)]
            : [Colors.grey.shade300.withOpacity(0.3), Colors.grey.shade200.withOpacity(0.1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.5),
          Colors.white.withOpacity(0.5),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 28,
            color: isUnlocked ? unlockedIconColor : Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Shimmer.fromColors(
            baseColor: isUnlocked ? unlockedTextColor : Colors.grey.shade600,
            highlightColor: Colors.white,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? unlockedTextColor : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Future<String> _getImageUrl(String gsUrl) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(gsUrl);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Erreur lors de la récupération de l'URL : $e");
      throw e;
    }
  }
  void _handleLevelTap(BuildContext context, int level, Chapter chapter, bool isUnlocked) {
    if (isUnlocked) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizScreen(
            level: level,
            chapterId: chapter.id,
            onLevelCompleted: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

                int currentUnlockedLevel = unlockedLevelsPerChapter[chapter.id] ?? 1;

                if (level == 1) {
                  int nextUnlockedLevel = 2;
                  int unlockedModules = (nextUnlockedLevel ~/ 3) + 1;

                  await userRef.update({
                    'unlockedLevels.${chapter.id}': nextUnlockedLevel,
                    'chapters.${chapter.id}.unlockedModules': unlockedModules,
                  });

                  setState(() {
                    unlockedLevelsPerChapter[chapter.id] = nextUnlockedLevel;
                    unlockedModulesPerChapter[chapter.id] = unlockedModules;
                  });

                  // 📜 🔥 Scroll vers le niveau débloqué
                  _scrollToUnlockedLevel(chapter.id);

                  print("✅ Déblocage immédiat du module après le 1er niveau !");
                } else {
                  if (level == currentUnlockedLevel) {
                    await userRef.update({
                      'unlockedLevels.${chapter.id}': FieldValue.increment(1),
                    });
                    setState(() {
                      unlockedLevelsPerChapter[chapter.id] = currentUnlockedLevel + 1;
                    });

                    // 📜 🔥 Scroll vers le niveau débloqué
                    _scrollToUnlockedLevel(chapter.id);
                  }
                }

                await userRef.update({
                  'chapters.${chapter.id}.levelScores.Level $level': 80,
                });

                double currentScrollPosition = _scrollController.position.pixels;
                await userRef.update({
                  'lastChapterId': chapter.id,
                  'scrollPositions.${chapter.id}': currentScrollPosition,
                });

                setState(() {
                  lastPlayedChapterId = chapter.id;
                });

                print("✅ Niveau $level terminé, Firestore mis à jour !");
              }
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ce niveau est verrouillé. Veuillez terminer le niveau précédent.'.tr()),
      ));
    }
  }

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Widget _buildLevelButton(int level, Chapter chapter, bool isUnlocked) {
    final bool isNext = level == (unlockedLevelsPerChapter[chapter.id] ?? 1);
    final Color baseColor = isNext
        ? Colors.blue.shade400
        : isUnlocked
        ? _getLevelColor((level - 1) ~/ 3 + 1).withOpacity(0.3)
        : Colors.grey.shade400;

    // 1) Le bouton animé en dégradé circulant
    Widget animatedButton = AnimatedBuilder(
      animation: _gradientCtrl,
      builder: (context, child) {
        final t = _gradientCtrl.value;
        final stops = [
          (t - 0.3).clamp(0.0, 1.0),
          t,
          (t + 0.3).clamp(0.0, 1.0),
        ];
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isUnlocked
                  ? [
                baseColor.withOpacity(1),
                baseColor.withOpacity(0.6),
                baseColor.withOpacity(1),
              ]
                  : [
                Colors.grey.shade400,
                Colors.grey.shade300,
                Colors.grey.shade400,
              ],
              stops: stops,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.05),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Lottie “ici” au centre si c’est le prochain
          if (isNext)
            Center(
              child: Lottie.asset(
                'assets/Animation continue.json',
                width: 100,
                height: 90,
                fit: BoxFit.contain,
              ),
            ),

          // Sinon icône check / radio_button / lock
          if (!isNext)
            Center(
              child: Icon(
                isUnlocked
                    ? (level < (unlockedLevelsPerChapter[chapter.id] ?? 1)
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked)
                    : Icons.lock,
                size: 42,
                color: isUnlocked ? Colors.green.shade600 : Colors.grey.shade600,
              ),
            ),

          // Bandeau blanc translucide en bas avec “Quiz N”
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              alignment: Alignment.center,
              child: Text(
                'Quiz $level',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isUnlocked ? Colors.blueGrey.shade800 : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // 2) On enveloppe uniquement le contour du bouton si c'est le prochain
    Widget withGlow = isNext
        ? RotatingGlowBorder(
      borderWidth: 3.0,
      colors: [Colors.orangeAccent, Colors.blueAccent, Colors.cyanAccent],
      duration: const Duration(seconds: 2),
      child: Padding(
        padding: const EdgeInsets.all(4.0), // ← décalage intérieur égal à borderWidth
        child: animatedButton,              // ← ton bouton sans modification
      ),
    )
        : animatedButton;


    // 3) Clip pour ne pas décaler le layout
    Widget clipped = ClipRRect(
      borderRadius: BorderRadius.circular(16 + (isNext ? 4 : 0)),
      child: withGlow,
    );

    // 4) Padding + InkWell + Opacité
    Widget tappable = Padding(
      padding: _getPaddingForButton(level).add(const EdgeInsets.symmetric(vertical: 8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isUnlocked ? () => _handleLevelTap(context, level, chapter, isUnlocked) : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: isUnlocked ? 1 : 0.5,
          child: clipped,
        ),
      ),
    );

    // 5) On garde enfin les animations “sales” / “quiz” autour
    return _getButtonWithOptionalLottie(level, tappable);
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
                colors: [Colors.lightBlue.shade50, Colors.white,Colors.lightBlue.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : LinearGradient(
                colors: [Colors.brown.shade50, Colors.white,Colors.brown.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parcours affichés directement
                  Column(
                    children: [

                      ..._buildLevelAndParcoursWidgets(chapter),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // Boutons pour simulations et autres actions
                  _buildSimulationButtons(chapter),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildLevelAndParcoursWidgets(Chapter chapter) {
    List<Widget> levelAndParcoursWidgets = [];

    // ✅ Afficher le premier module dès le début (toujours débloqué)
    levelAndParcoursWidgets.add(
      _buildParcoursNumberWidget(
        1, // Module 1 affiché dès le départ
        0, // Niveau 0 (départ)
        true, // Toujours débloqué
        chapter.id,
      ),
    );

    int parcoursNumber = 2; // ✅ Commence au module 2 car module 1 est déjà là

    for (int i = 0; i < chapter.numberOfQuizzes; i++) {
      bool isUnlocked = i + 1 <= (unlockedLevelsPerChapter[chapter.id] ?? 1);

      // Ajouter le bouton pour chaque niveau
      levelAndParcoursWidgets.add(
        _buildLevelButton(i + 1, chapter, isUnlocked),
      );

      // ✅ Ajouter un parcours tous les 3 niveaux (déblocage à partir du module 2)
      if ((i + 1) % 3 == 0) {
        // Vérifier si le score du dernier niveau est >= 80 pour débloquer le module
        bool isParcoursUnlocked = (scoresPerLevel[chapter.id]?[i + 1] ?? 0) >= 80;

        // ✅ Ajouter le module suivant (parcoursNumber commence à 2)
        levelAndParcoursWidgets.add(
          _buildParcoursNumberWidget(
            parcoursNumber,
            i + 1,
            isParcoursUnlocked,
            chapter.id,
          ),
        );

        // ✅ Débloquer le module si le niveau 3, 6, 9... a un score >= 80
        if (isParcoursUnlocked) {
          _updateUnlockedModules(chapter.id, parcoursNumber);
        }

        parcoursNumber++; // ✅ Passer au module suivant
      }
    }

    return levelAndParcoursWidgets;
  }

  Widget _buildParcoursNumberWidget(int num, int level, bool unlocked, String chapId) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('lessons')
          .where('parcoursNumber', isEqualTo: num)
          .where('chapterId', isEqualTo: chapId)
          .limit(1)
          .get(),
      builder: (ctx, snap) {
        String desc = '';
        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          final m = snap.data!.docs.first.data() as Map<String, dynamic>;
          desc = (m['title'] ?? m['description'] ?? '').toString();
        }

        return Padding(
          padding: _getPaddingForParcoursNumber(level),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: unlocked ? _handleModuleTap(num, chapId) : null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: unlocked ? 1 : 0.45,
              child: AnimatedBuilder(
                animation: _gradientCtrl,
                builder: (context, child) {
                  final t = _gradientCtrl.value;
                  final stops = [
                    (t - 0.3).clamp(0.0, 1.0),
                    t,
                    (t + 0.3).clamp(0.0, 1.0),
                  ];
                  return Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: unlocked
                            ? [
                          Colors.blue.shade300.withOpacity(0.7),
                          Colors.blue.shade300.withOpacity(0.4),
                          Colors.blue.shade300.withOpacity(0.7),
                        ]
                            : [
                          Colors.grey.shade400,
                          Colors.grey.shade300,
                          Colors.grey.shade400,
                        ],
                        stops: stops,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Lottie.asset('assets/animation_book1.json', fit: BoxFit.cover),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              color: Colors.white.withOpacity(.8),
                              child: AutoSizeText(
                                desc.isNotEmpty ? desc : 'Module $num',
                                maxLines: 1,
                                minFontSize: 8,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: unlocked ? Colors.blueGrey.shade800 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }


  GestureTapCallback _handleModuleTap(int num, String chapId) => () async {
    final q = await FirebaseFirestore.instance
        .collection('lessons')
        .where('parcoursNumber', isEqualTo: num)
        .where('chapterId', isEqualTo: chapId)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ModulePage(parcoursNumber: num, moduleId: q.docs.first.id, chapterId: chapId)));
  };

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

  @override
  Widget build(BuildContext context) {
    // Arguments de la route
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? selectedChapterId = args?['chapterId']; // Chapitre sélectionné
    final double initialScrollPosition = args?['scrollPosition'] ?? 0.0;

    // Affichage de l'indicateur de chargement si les chapitres sont vides
    if (chapters.isEmpty) {
      return Scaffold(
        key: _scaffoldKey,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Sélection du chapitre à afficher
    final chapterToDisplay = selectedChapterId != null
        ? chapters.firstWhereOrNull((chapter) => chapter.id == selectedChapterId)
        : chapters.firstWhereOrNull((chapter) => chapter.id == lastPlayedChapterId) ??
        chapters.first; // Par défaut, on affiche le premier chapitre

    // Sauvegarder le dernier chapitre sélectionné (si différent du dernier joué)
    if (selectedChapterId != null && selectedChapterId != lastPlayedChapterId) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'lastChapterId': selectedChapterId,
        }).catchError((error) {
          print("Erreur lors de la mise à jour du chapitre sélectionné : $error");
        });
      }
    }

    // Gestion du cas où aucun chapitre n'est disponible
    if (chapterToDisplay == null) {
      return Scaffold(
        key: _scaffoldKey,
        body: Center(child: Text('Aucun chapitre trouvé.').tr()),
      );
    }

    // Gestion du défilement initial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final isChapterCompleted = (unlockedLevelsPerChapter[chapterToDisplay.id] ?? 0) >
            chapterToDisplay.numberOfQuizzes;

        final double targetScrollPosition = isChapterCompleted
            ? _scrollController.position.maxScrollExtent // Défiler jusqu'à la fin si terminé
            : (initialScrollPosition - MediaQuery.of(context).size.height / 3)
            .clamp(0.0, _scrollController.position.maxScrollExtent); // Sinon centrer la vue

        // Défilement fluide
        _scrollController.animateTo(
          targetScrollPosition,
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
        );
      }
    });
    // Interface principale
    return Scaffold(
      key: _scaffoldKey,
      // ─── 1.  APPBAR (remplace l’ancien) ───────────────────────────────────────────
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,                               // ← titre centré
        backgroundColor: Colors.white,
        elevation: 1,
        title: AutoSizeText(
          chapterToDisplay.title,
          maxLines: 1,
          minFontSize: 12,
          overflow: TextOverflow.ellipsis,
          style:  TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade900,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: RotatingGlowBorder(
              borderWidth: 2,
              colors: [Colors.blue.shade800, Colors.blueAccent, Colors.blue.shade300],
              duration: const Duration(seconds: 30),

              // ↘ bouton plus compact
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChapterMenuPage()),
                  );
                },

                // ↓ minSize & padding réduits
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  minimumSize: const Size(0, 32),               // hauteur mini
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,   // largeur
                    vertical: 4,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),

                icon: Icon(Icons.list, color: Colors.blue.shade800, size: 18),

                // ↓ texte plus petit
                label: Text(
                  "Parcours".tr(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            ),
          ),
        ],

      ),


      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white38],
          ),
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              const SizedBox(height: 1),
              // Affichage de l'image dynamique à la place du logo
              FutureBuilder<String>(
                future: _getImageUrl(chapterToDisplay.imageUrl), // Charger l'image depuis Firestore
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(), // Afficher un indicateur de chargement pendant le fetch
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Icon(
                      Icons.broken_image,
                      size: 180, // Taille de l'icône
                      color: Colors.grey,
                    );
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(15), // Bordures arrondies
                    child: Image.network(
                      snapshot.data!, // URL de l'image
                      width: MediaQuery.of(context).size.width * 0.8, // Largeur dynamique
                      height: 200, // Hauteur fixe
                      fit: BoxFit.cover, // Adapte l'image au conteneur
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              // Statistiques utilisateur
              _buildUserStats(chapterToDisplay),


              const SizedBox(height: 10),
              // Contenu des chapitres
              ..._buildChapterWidgets(chapterToDisplay),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      // Barre de navigation
      bottomNavigationBar: CustomBottomNavBar(
        parentContext: context,
        currentIndex: 0,
        scaffoldKey: _scaffoldKey,
      ),
      // Bouton Leaderboard

    );
  }




  Widget _buildUserStats(Chapter chapter) {
    // Scores et niveaux spécifiques au chapitre sélectionné
    int chapterScore          = totalScorePerChapter[chapter.id]         ?? 0;
    int chapterUnlockedLevels = unlockedLevelsPerChapter[chapter.id]    ?? 1;
    int chapterUnlockedModules= unlockedModulesPerChapter[chapter.id]   ?? 0;

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
            iconColor: Colors.blue.shade900,
            label: "Score".tr(),
            value: chapterScore.toString(),
          ),
          _buildStatItem(
            icon: Icons.star,
            iconColor: Colors.orange.shade900,
            label: "Niveaux".tr(),
            value: chapterUnlockedLevels.toString(),
          ),
          _buildStatItem(
            icon: Icons.book,
            iconColor: Colors.green.shade900,
            label: "Modules".tr(),
            value: chapterUnlockedModules.toString(),
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
    return AnimatedBuilder(
      animation: _gradientCtrl,
      builder: (context, child) {
        final t = _gradientCtrl.value;
        final stops = [
          (t - 0.3).clamp(0.0, 1.0),
          t,
          (t + 0.3).clamp(0.0, 1.0),
        ];
        final gradient = LinearGradient(
          colors: [
            iconColor.withOpacity(0.6),
            iconColor,
            iconColor.withOpacity(0.6),
          ],
          stops: stops,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1) Contour circulaire animé
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: gradient,
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                // 2) Icône en ShaderMask pour appliquer le dégradé
                child: ShaderMask(
                  shaderCallback: (rect) => gradient.createShader(rect),
                  blendMode: BlendMode.srcIn,
                  child: Icon(icon, size: 35, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 3) Valeur (Score/Niveaux/Modules) en dégradé
            ShaderMask(
              shaderCallback: (bounds) =>
                  gradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
              blendMode: BlendMode.srcIn,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // 4) Label en dégradé (plus discret)
            ShaderMask(
              shaderCallback: (bounds) =>
                  gradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
              blendMode: BlendMode.srcIn,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

}