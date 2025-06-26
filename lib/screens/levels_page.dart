// levels_page.dart – version fusionnée et complète
// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lottie/lottie.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:collection/collection.dart';

import 'package:quiz_commercial2024/screens/chapter_menu_page.dart';
import 'package:quiz_commercial2024/screens/simulation.dart';
import '../ad_manager.dart';
import '../drawer/custom_bottom_nav_bar.dart';
import '../rotating_glow_border.dart';
import '../services/firestore_service.dart';
import '../services/models.dart';
import 'compte_rendu_screen.dart';
import 'module_page.dart';
import 'quiz_screen.dart';

class LevelsPage extends StatefulWidget {
  const LevelsPage({Key? key}) : super(key: key);

  @override
  State<LevelsPage> createState() => _LevelsPageState();
}

class _LevelsPageState extends State<LevelsPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ────────────────────────── ADS ──────────────────────────
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

  // ────────────────────────── DATA ─────────────────────────
  final FirestoreService _firestoreService = FirestoreService();
  List<Chapter> chapters = [];
  int totalScore = 0;
  String lastPlayedChapterId = '';
  Map<String, int> unlockedLevelsPerChapter = {};
  Map<String, int> unlockedModulesPerChapter = {};
  Map<String, int> totalScorePerChapter = {};
  Map<String, Map<int, int>> scoresPerLevel = {};

  // ────────────────────────── UI  ──────────────────────────
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _gradientCtrl;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _introShown = false;

  // ─────────────────────── LIFE CYCLE ──────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _gradientCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();

    _loadInterstitialAd();
    _fetchChapters();
    _fetchUserData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _isInterstitialAdReady = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_introShown) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final bool fromMenu = args?['fromMenu'] == true;
      _introShown = true;
      if (fromMenu) Future.microtask(_showIntroDialog);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gradientCtrl.dispose();
    _interstitialAd?.dispose();
    _saveScrollPosition();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    if (!mounted) return;
    super.setState(fn);
  }

  // ────────────────────────── ADS ──────────────────────────
  void _loadInterstitialAd() {
    final adUnitId = kDebugMode
        ? (Platform.isIOS
            ? AdManager.testInterstitialAdUnitIdIOS
            : AdManager.testInterstitialAdUnitIdAndroid)
        : AdManager.interstitialAdUnitId;

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (err) {
          debugPrint('❌ Interstitial failed: \${err.message}');
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  // ─────────────────────── FIRESTORE ───────────────────────
  Future<void> _fetchChapters() async {
    try {
      chapters = await _firestoreService.getChapters();
      setState(() {});
    } catch (e) {
      debugPrint('❌ fetchChapters: \$e');
      setState(() => chapters = []);
    }
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    try {
      var doc = await ref.get();
      if (!doc.exists || doc.data() == null) {
        await ref.set({
          'totalScore': 0,
          'unlockedLevels': {},
          'unlockedModules': {},
          'scrollPositions': {},
          'lastChapterId': '',
          'chapters': {},
        });
        doc = await ref.get();
      }

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      totalScore = data['totalScore'] as int? ?? 0;
      unlockedLevelsPerChapter = Map<String, int>.from(data['unlockedLevels'] ?? {});
      unlockedModulesPerChapter = Map<String, int>.from(data['unlockedModules'] ?? {});
      lastPlayedChapterId = data['lastChapterId'] as String? ?? '';

      // scores & totals
      scoresPerLevel = {};
      totalScorePerChapter = {};
      if (data['chapters'] is Map) {
        (data['chapters'] as Map).forEach((chapId, chapData) {
          if (chapData is Map && chapData['levelScores'] is Map) {
            final map = (chapData['levelScores'] as Map).map(
              (k, v) => MapEntry(int.parse(k.split(' ')[1]), v as int),
            );
            scoresPerLevel[chapId] = map;
            totalScorePerChapter[chapId] =
                map.values.fold(0, (sum, e) => sum + e);
          }
        });
      }

      setState(() {});
    } catch (e) {
      debugPrint('❌ fetchUserData: \$e');
    }
  }

  Future<void> _saveScrollPosition() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !_scrollController.hasClients) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'scrollPositions.\$lastPlayedChapterId':
            _scrollController.position.pixels,
      });
    } catch (e) {
      debugPrint('❌ saveScroll: \$e');
    }
  }

  // ─────────────────────── INTRO POPUP ─────────────────────
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  // ---------------- UTIL ----------------
  Future<String> _getImageUrl(String gsUrl) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(gsUrl);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('❌ getImageUrl: \$e');
      rethrow;
    }
  }

  // ───────────────────────── BUILD ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? selectedChapId = args?['chapterId'];
    final double initialScroll = args?['scrollPosition'] ?? 0.0;

    if (chapters.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final Chapter chapter = selectedChapId != null
        ? chapters.firstWhereOrNull((c) => c.id == selectedChapId) ?? chapters.first
        : chapters.firstWhereOrNull((c) => c.id == lastPlayedChapterId) ?? chapters.first;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final bool done =
          (unlockedLevelsPerChapter[chapter.id] ?? 0) > chapter.numberOfQuizzes;
      final target = done
          ? _scrollController.position.maxScrollExtent
          : (initialScroll - MediaQuery.of(context).size.height / 3)
              .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        target,
        duration: const Duration(seconds: 2),
        curve: Curves.easeInOut,
      );
    });

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(chapter),
      body: _buildBody(chapter),
      bottomNavigationBar: CustomBottomNavBar(
        parentContext: context,
        currentIndex: 0,
        scaffoldKey: _scaffoldKey,
      ),
    );
  }

  // ─────────────────────── BUILD PARTS ─────────────────────
  PreferredSizeWidget _buildAppBar(Chapter chapter) {
    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: true,
      backgroundColor: Colors.white,
      elevation: 1,
      title: AutoSizeText(
        chapter.title,
        maxLines: 1,
        minFontSize: 12,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
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
            colors: [
              Colors.blue.shade800,
              Colors.blueAccent,
              Colors.blue.shade300,
            ],
            duration: const Duration(seconds: 30),
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChapterMenuPage()),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(Icons.list, color: Colors.blue.shade800, size: 18),
              label: Text('Parcours'.tr(),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(Chapter chapter) {
    return Container(
      decoration: const BoxDecoration(
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
            FutureBuilder<String>(
              future: _getImageUrl(chapter.imageUrl),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError || !snap.hasData) {
                  return const Icon(Icons.broken_image, size: 180);
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    snap.data!,
                    width: MediaQuery.of(context).size.width * .8,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _buildUserStats(chapter),
            const SizedBox(height: 10),
            ..._buildChapterWidgets(chapter),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ───── USER STATS ─────
  Widget _buildUserStats(Chapter chapter) {
    final int score = totalScorePerChapter[chapter.id] ?? 0;
    final int lvl = unlockedLevelsPerChapter[chapter.id] ?? 1;
    final int mods = unlockedModulesPerChapter[chapter.id] ?? 0;

    Widget stat(IconData icon, Color color, String label, String v) {
      return AnimatedBuilder(
        animation: _gradientCtrl,
        builder: (context, child) {
          final t = _gradientCtrl.value;
          final stops = [(t - .3).clamp(0.0, 1.0), t, (t + .3).clamp(0.0, 1.0)];
          final g = LinearGradient(
            colors: [color.withOpacity(.6), color, color.withOpacity(.6)],
            stops: stops,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: g),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white,
                  child: ShaderMask(
                    shaderCallback: g.createShader,
                    blendMode: BlendMode.srcIn,
                    child: Icon(icon, size: 35, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ShaderMask(shaderCallback: g.createShader, blendMode: BlendMode.srcIn, child: Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
              const SizedBox(height: 4),
              ShaderMask(shaderCallback: g.createShader, blendMode: BlendMode.srcIn, child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            ],
          );
        },
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(.3), blurRadius: 7, offset: const Offset(0, 3)),
        ],
      ),
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          stat(Icons.score, Colors.blue.shade900, 'Score'.tr(), '$score'),
          stat(Icons.star, Colors.orange.shade900, 'Niveaux'.tr(), '$lvl'),
          stat(Icons.book, Colors.green.shade900, 'Modules'.tr(), '$mods'),
        ],
      ),
    );
  }

  // ─────────────── BUTTONS, PARCOURS, QUIZ ───────────────

  // 🔹 Glow + animations autour des boutons
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

  // Couleur par groupe de 3 niveaux
  Color _getLevelColor(int group) {
    switch (group) {
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

  // Décalage horizontal pour créer l’effet de zig‑zag
  EdgeInsets _getPaddingForButton(int level) {
    const off = 40.0;
    switch (level % 8) {
      case 0:
        return const EdgeInsets.only(right: off * 3);
      case 1:
        return EdgeInsets.zero;
      case 2:
        return const EdgeInsets.only(left: off * 3);
      case 3:
        return const EdgeInsets.only(left: off * 5.5);
      case 4:
        return const EdgeInsets.only(left: off * 3);
      case 5:
        return EdgeInsets.zero;
      case 6:
        return const EdgeInsets.only(right: off * 3);
      case 7:
        return const EdgeInsets.only(right: off * 5.5);
      default:
        return EdgeInsets.zero;
    }
  }

  // Bouton unique d’un Quiz
  Widget _buildLevelButton(int level, Chapter chap, bool unlocked) {
    final isNext = level == (unlockedLevelsPerChapter[chap.id] ?? 1);
    final baseColor = isNext
        ? Colors.blue.shade400
        : unlocked
            ? _getLevelColor(((level - 1) ~/ 3) + 1).withOpacity(.3)
            : Colors.grey.shade400;

    final btn = Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text('Q$level',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: unlocked ? Colors.white : Colors.grey.shade700)),
      ),
    );

    return Padding(
      padding: _getPaddingForButton(level).add(const EdgeInsets.symmetric(vertical: 8)),
      child: InkWell(
        onTap: unlocked
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizScreen(
                      level: level,
                      chapterId: chap.id,
                      onLevelCompleted: () {},
                    ),
                  ),
                )
            : null,
        child: _getButtonWithOptionalLottie(level, btn),
      ),
    );
  }

  // Boutons Simulation + Compte‑rendu
  Widget _buildSimulationButtons(Chapter chap) {
    final quizzesDone = unlockedLevelsPerChapter[chap.id] ?? 1;
    final unlocked = quizzesDone >= chap.numberOfQuizzes;

    Widget smallBtn(IconData icn, String txt, Color c, VoidCallback onTap) =>
        Opacity(
          opacity: unlocked ? 1 : .4,
          child: ElevatedButton.icon(
            onPressed: unlocked ? onTap : null,
            icon: Icon(icn),
            label: Text(txt),
            style: ElevatedButton.styleFrom(backgroundColor: c),
          ),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        smallBtn(Icons.school, 'IA'.tr(), Colors.blue.shade300, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => SimulationScreen(chapterId: chap.id, guided: true)));
        }),
        smallBtn(Icons.mic, 'Libre'.tr(), Colors.orange.shade300, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => SimulationScreen.free(chapterId: chap.id)));
        }),
        smallBtn(Icons.article, 'CR'.tr(), Colors.green.shade400, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => CompteRenduScreen(chapterId: chap.id)));
        }),
      ],
    );
  }

  // ----- Parcours helpers -----
  EdgeInsets _getPaddingForParcoursNumber(int level) {
    const off = 40.0;
    switch (level % 8) {
      case 0:
        return const EdgeInsets.only(right: off * 1.5);
      case 1:
        return const EdgeInsets.only(left: off * 1.5);
      case 2:
        return const EdgeInsets.only(left: off * 4.5);
      case 3:
        return const EdgeInsets.only(left: off * 4.5);
      case 4:
        return const EdgeInsets.only(left: off * 1.5);
      case 5:
        return const EdgeInsets.only(right: off * 1.5);
      case 6:
        return const EdgeInsets.only(right: off * 4.5);
      case 7:
        return const EdgeInsets.only(right: off * 4.5);
      default:
        return EdgeInsets.zero;
    }
  }

  Widget _buildAnimatedParcoursContainer(bool unlocked, String desc, int num) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: unlocked ? Colors.blue.shade200 : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: AutoSizeText(desc.isNotEmpty ? desc : 'Module $num',
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: unlocked ? Colors.blueGrey.shade800 : Colors.grey.shade700)),
      ),
    );
  }

  Widget _buildParcoursNumberWidget(int num, int level, bool unlocked, String chapId) {
    return Padding(
      padding: _getPaddingForParcoursNumber(level),
      child: InkWell(
        onTap: unlocked
            ? () => _handleModuleTap(num, chapId)()
            : null,
        child: _buildAnimatedParcoursContainer(unlocked, '', num),
      ),
    );
  }

  List<Widget> _buildLevelAndParcoursWidgets(Chapter chap) {
    final list = <Widget>[];
    list.add(_buildParcoursNumberWidget(1, 0, true, chap.id));
    int parcours = 2;
    for (int i = 0; i < chap.numberOfQuizzes; i++) {
      final unlocked = i + 1 <= (unlockedLevelsPerChapter[chap.id] ?? 1);
      list.add(_buildLevelButton(i + 1, chap, unlocked));
      if ((i + 1) % 3 == 0) {
        final ok = (scoresPerLevel[chap.id]?[i + 1] ?? 0) >= 80;
        list.add(_buildParcoursNumberWidget(parcours, i + 1, ok, chap.id));
        if (ok) _updateUnlockedModules(chap.id, parcours);
        parcours++;
      }
    }
    return list;
  }

  List<Widget> _buildChapterWidgets(Chapter chap) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                ..._buildLevelAndParcoursWidgets(chap),
                const SizedBox(height: 15),
                _buildSimulationButtons(chap),
              ],
            ),
          ),
        ),
      )
    ];
  }

  // ----- Update Firestore when modules unlocked -----
  void _updateUnlockedModules(String chapId, int num) {
    final current = unlockedModulesPerChapter[chapId] ?? 1;
    if (num <= current) return;
    FirebaseAuth.instance.currentUser?.let((user) async {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'unlockedModules.$chapId': num});
      setState(() => unlockedModulesPerChapter[chapId] = num);
    });
  }

  // ----- Module tap -----
  GestureTapCallback _handleModuleTap(int num, String chapId) => () async {
        final q = await FirebaseFirestore.instance
            .collection('lessons')
            .where('parcoursNumber', isEqualTo: num)
            .where('chapterId', isEqualTo: chapId)
            .limit(1)
            .get();
        if (q.docs.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ModulePage(
              parcoursNumber: num,
              moduleId: q.docs.first.id,
              chapterId: chapId,
            ),
          ),
        );
      };

} // ← FIN DE _LevelsPageState

