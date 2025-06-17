import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:quiz_commercial2024/screens/simulation.dart';

import '../drawer/custom_bottom_nav_bar.dart';
import '../rotating_glow_border.dart';
import '../services/lesson_utils.dart';
import 'compte_rendu_screen.dart';
import '../ad_manager.dart';

class LessonsScreen extends StatefulWidget {
  final VoidCallback? onItemTapped;

  LessonsScreen({this.onItemTapped});

  @override
  _LessonsScreenState createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, int> unlockedLevelsPerChapter = {};
  Map<String, int> unlockedModulesPerChapter = {};
  Map<String, Map<int, int>> scoresPerChapter = {};

  String? _lastChapterId;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

  @override
  void initState() {
    super.initState();
    _initializeUserData();
    _loadInterstitialAd();
  }

  Future<String> getDownloadUrl(String gsUrl) async {
    final ref = FirebaseStorage.instance.refFromURL(gsUrl);
    return await ref.getDownloadURL();
  }

  Future<void> _initializeUserData() async {
    Map<String, dynamic> data = await fetchUnlockedData();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>? ?? {};
        setState(() {
          unlockedLevelsPerChapter = Map<String,int>.from(data['unlockedLevels'] ?? {});
          unlockedModulesPerChapter = Map<String,int>.from(data['unlockedModules'] ?? {});
          scoresPerChapter = Map<String,Map<int,int>>.from(data['scoresPerChapter'] ?? {});
          _lastChapterId = userData['lastChapterId'] as String?;
        });
      }
    }
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdManager.interstitialAdUnitId,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (_) {
              ad.dispose();
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (_, __) {
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (_) {
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final effectiveChapterId = (args != null && args['chapterId'] != null)
        ? args['chapterId'] as String
        : _lastChapterId;

    return Scaffold(
      key: _scaffoldKey,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 45),
            // Lottie animée
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,4))],
              ),
              child: ClipOval(
                child: Lottie.asset('assets/animation_book1.json', fit: BoxFit.cover),
              ),
            ),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: GlassmorphicContainer(
                width: double.infinity,
                height: 80,
                borderRadius: 20,
                blur: 12,
                alignment: Alignment.center,
                border: 2,
                linearGradient: LinearGradient(
                  colors: [Colors.white, Colors.blue.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderGradient: LinearGradient(
                  colors: [Colors.blue.shade100, Colors.blue.shade200],
                ),
                child: Center(
                  child: AutoSizeText(
                    'Amusez-vous avec nos quizz pour ouvrir les portes de nouvelles leçons passionnantes !'.tr(),
                    style: TextStyle(fontSize: 14, color: Colors.blue.shade800),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('chapters')
                    .orderBy('numberOfQuizzes')
                    .get(),
                builder: (ctx, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Erreur de chargement'.tr()));
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  var chapters = snap.data!.docs;
                  if (effectiveChapterId != null) {
                    chapters.sort((a,b) => a.id == effectiveChapterId ? -1 : b.id == effectiveChapterId ? 1 : 0);
                  }
                  return ListView.separated(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    itemCount: chapters.length,
                    separatorBuilder: (_,__) => SizedBox(height: 16),
                    itemBuilder: (_,i) {
                      final doc = chapters[i];
                      final data = doc.data();
                      final chapterId = doc.id;
                      final title = data['title'] ?? '';
                      final logo = data['logo'] ?? '';
                      final nbQuiz = data['numberOfQuizzes'] ?? 0;

                      final unlockedLv = unlockedLevelsPerChapter[chapterId] ?? 0;
                      final scores = scoresPerChapter[chapterId] ?? {};
                      // Déblocage = même condition que levels_page.dart
                      final isSimUnlocked = unlockedLv >= nbQuiz;
                      final isHighlighted = chapterId == effectiveChapterId;

                      Widget card = _buildChapterCard(
                          chapterId, title, logo, nbQuiz,
                          unlockedLv, isSimUnlocked, scores
                      );

                      return isHighlighted
                          ? RotatingGlowBorder(
                        borderWidth: 3,
                        colors: [Colors.orangeAccent, Colors.blueAccent, Colors.cyanAccent],
                        duration: Duration(seconds: 2),
                        child: card,
                      )
                          : card;
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        parentContext: context,
        currentIndex: 1,
        scaffoldKey: _scaffoldKey,
      ),
    );
  }

  Widget _buildChapterCard(
      String chapterId,
      String title,
      String logo,
      int numberOfQuizzes,
      int unlockedLevels,
      bool isSimulationsUnlocked,
      Map<int,int> scoresForChapter,
      ) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Row(
              children: [
                logo.isNotEmpty
                    ? FutureBuilder<String>(
                  future: getDownloadUrl('gs://quiz-commercial.appspot.com/$logo'),
                  builder:(c,s) {
                    if (s.connectionState==ConnectionState.waiting)
                      return SizedBox(width:70,height:70,child:CircularProgressIndicator());
                    if (s.hasError || !s.hasData)
                      return Icon(Icons.broken_image, size:70, color:Colors.grey);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(s.data!, width:70, height:70, fit:BoxFit.cover),
                    );
                  },
                )
                    : Icon(Icons.book, size:70, color:Colors.orange.shade400),
                SizedBox(width:16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AutoSizeText(title,
                          style: TextStyle(fontSize:20, fontWeight: FontWeight.bold, color:Colors.blue.shade800),
                          maxLines:1),
                      SizedBox(height:4),
                      AutoSizeText('Nombre de Quiz : $numberOfQuizzes',
                          style: TextStyle(fontSize:16, fontWeight: FontWeight.w600, color:Colors.yellow.shade700),
                          maxLines:1),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height:16),
            // Liste des modules (identique à avant)
            FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('lessons')
                  .where('chapterId', isEqualTo: chapterId)
                  .get(),
              builder:(c,sn) {
                if (sn.hasError) return Text('Erreur modules'.tr());
                if (sn.connectionState==ConnectionState.waiting)
                  return CircularProgressIndicator();
                var modules = sn.data!.docs;
                modules.sort((a,b) => (a.data()['lessonNumber'] as int).compareTo(b.data()['lessonNumber'] as int));
                return Column(
                  children: modules.asMap().entries.map((e) => buildLessonCard(
                      context,e.value,unlockedLevels,unlockedModulesPerChapter[chapterId]??0,scoresForChapter,chapterId,e.key
                  )).toList(),
                );
              },
            ),
            SizedBox(height:8),
            _buildSimulationButtons(chapterId, isSimulationsUnlocked),
            if (!isSimulationsUnlocked)
              Padding(
                padding: EdgeInsets.only(top:8),
                child: AutoSizeText(
                  'Terminez le dernier niveau avec un score minimum de 80 pour débloquer ces fonctionnalités'.tr(),
                  style: TextStyle(color: Colors.red.shade700, fontSize:14),
                  maxLines:2, textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationButtons(String chapterId, bool isUnlocked) {
    return Column(
      children: [
        _animationButton(
          icon: Icons.school,
          text: 'Apprendre avec IA'.tr(),
          isUnlocked: isUnlocked,
          onTap: () => _goToSimulation(chapterId, guided: true),
          color: Colors.blue.shade300,
          unlockedTextColor: Colors.blue.shade900,
          unlockedIconColor: Colors.blue.shade800,
          tooltip: 'Terminez le chapitre pour débloquer'.tr(),
        ),
        SizedBox(height:5),
        _animationButton(
          icon: Icons.mic,
          text: 'Mode Libre'.tr(),
          isUnlocked: isUnlocked,
          onTap: () => _goToSimulation(chapterId, guided: false),
          color: Colors.orange.shade200,
          unlockedTextColor: Colors.orange.shade900,
          unlockedIconColor: Colors.orange.shade800,
          tooltip: 'Terminez le chapitre pour débloquer'.tr(),
        ),
        SizedBox(height:5),
        _animationButton(
          icon: Icons.article,
          text: 'Compte Rendu'.tr(),
          isUnlocked: isUnlocked,
          onTap: () => _goToCompteRendu(chapterId),
          color: Colors.green.shade400,
          unlockedTextColor: Colors.green.shade900,
          unlockedIconColor: Colors.green.shade800,
          tooltip: 'Terminez le chapitre pour débloquer'.tr(),
        ),
      ],
    );
  }

  Widget _animationButton({
    required IconData icon,
    required String text,
    required bool isUnlocked,
    required VoidCallback onTap,
    required Color color,
    required Color unlockedTextColor,
    required Color unlockedIconColor,
    required String tooltip,
  }) {
    return InkWell(
      onTap: isUnlocked ? () {
        if (_isInterstitialAdReady && _interstitialAd != null) {
          _interstitialAd!.show();
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (_) {
              _interstitialAd!.dispose();
              _loadInterstitialAd();
              onTap();
            },
            onAdFailedToShowFullScreenContent: (_, __) {
              _interstitialAd!.dispose();
              _loadInterstitialAd();
              onTap();
            },
          );
        } else {
          onTap();
        }
      } : null,
      child: Tooltip(
        message: isUnlocked ? '' : tooltip,
        child: GlassmorphicContainer(
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
            colors: isUnlocked
                ? [color, color.withOpacity(0.7)]
                : [Colors.grey.shade400, Colors.grey.shade400],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size:28, color: isUnlocked ? unlockedIconColor : Colors.grey.shade600),
              SizedBox(width:8),
              Shimmer.fromColors(
                baseColor: isUnlocked ? unlockedTextColor : Colors.grey.shade600,
                highlightColor: Colors.white,
                child: AutoSizeText(
                  text,
                  style: TextStyle(fontSize:16, fontWeight:FontWeight.bold, color: isUnlocked ? unlockedTextColor : Colors.grey.shade600),
                  maxLines:1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToSimulation(String chapterId, { required bool guided }) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => guided
          ? SimulationScreen(chapterId: chapterId, guided: true)
          : SimulationScreen.free(chapterId: chapterId),
    ));
  }

  void _goToCompteRendu(String chapterId) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CompteRenduScreen(chapterId: chapterId),
    ));
  }
}
