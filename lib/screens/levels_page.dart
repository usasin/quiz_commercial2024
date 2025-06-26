// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart'; import 'package:easy_localization/easy_localization.dart'; import 'package:firebase_auth/firebase_auth.dart'; import 'package:firebase_storage/firebase_storage.dart'; import 'package:flutter/foundation.dart'; import 'package:flutter/material.dart'; import 'package:glassmorphism/glassmorphism.dart'; import 'package:google_mobile_ads/google_mobile_ads.dart'; import 'package:lottie/lottie.dart'; import 'package:auto_size_text/auto_size_text.dart'; import 'package:collection/collection.dart';

import 'package:quiz_commercial2024/screens/chapter_menu_page.dart'; import 'package:quiz_commercial2024/screens/simulation.dart'; import '../ad_manager.dart'; import '../drawer/custom_bottom_nav_bar.dart'; import '../rotating_glow_border.dart'; import '../services/firestore_service.dart'; import '../services/models.dart'; import 'compte_rendu_screen.dart'; import 'module_page.dart'; import 'quiz_screen.dart';

class LevelsPage extends StatefulWidget { const LevelsPage({Key? key}) : super(key: key);

@override State<LevelsPage> createState() => _LevelsPageState(); }

class _LevelsPageState extends State<LevelsPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver { InterstitialAd? _interstitialAd; bool _isInterstitialAdReady = false;

final FirestoreService _firestoreService = FirestoreService();

// -------------------- USER DATA -------------------- // List<Chapter> chapters = []; int totalScore = 0; String lastPlayedChapterId = ''; Map<String, int> unlockedLevelsPerChapter = {}; Map<String, int> unlockedModulesPerChapter = {}; Map<String, int> totalScorePerChapter = {}; Map<String, Map<int, int>> scoresPerLevel = {};

// -------------------- UI -------------------- // final ScrollController _scrollController = ScrollController(); final GlobalKey _currentLevelKey = GlobalKey(); late final AnimationController _gradientCtrl; bool _introShown = false; bool _showIntroNow = false;

// -------------------- LIFE CYCLE -------------------- // @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this);

_gradientCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
  ..repeat();

_loadInterstitialAd();
_fetchChapters();
_fetchUserData();

WidgetsBinding.instance.addPostFrameCallback((_) {
  if (lastPlayedChapterId.isNotEmpty) _showLastPlayedChapterDialog();
});

}

@override void didChangeDependencies() { super.didChangeDependencies();

if (!_introShown) {
  final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
  _showIntroNow = (args?['fromMenu'] == true);
  _introShown = true;
  if (_showIntroNow) Future.microtask(_showIntroDialog);
}

}

@override void didChangeAppLifecycleState(AppLifecycleState state) { // Dispose interstitial ad when app goes to background to prevent white screen on resume if (state == AppLifecycleState.paused) { _interstitialAd?.dispose(); _interstitialAd = null; _isInterstitialAdReady = false; } }

@override void dispose() { WidgetsBinding.instance.removeObserver(this); _gradientCtrl.dispose(); _interstitialAd?.dispose();

_saveScrollPosition();
_scrollController.dispose();
super.dispose();

}

// Ensure every setState is safe @override void setState(VoidCallback fn) { if (!mounted) return; super.setState(fn); }

// -------------------- ADS -------------------- // void _loadInterstitialAd() { final adUnitId = kDebugMode ? Platform.isIOS ? AdManager.testInterstitialAdUnitIdIOS : AdManager.testInterstitialAdUnitIdAndroid : AdManager.interstitialAdUnitId;

InterstitialAd.load(
  adUnitId: adUnitId,
  request: const AdRequest(),
  adLoadCallback: InterstitialAdLoadCallback(
    onAdLoaded: (ad) {
      _interstitialAd = ad;
      _isInterstitialAdReady = true;
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadInterstitialAd();
        },
      );
    },
    onAdFailedToLoad: (err) {
      debugPrint('❌ InterstitialAd failed to load: ${err.message}');
      _isInterstitialAdReady = false;
    },
  ),
);

}

// -------------------- FIRESTORE -------------------- // Future<void> _fetchChapters() async { try { chapters = await _firestoreService.getChapters(); if (chapters.isEmpty) debugPrint('ℹ️ No chapters found'); setState(() {}); } catch (e) { debugPrint('❌ Error fetching chapters: $e'); setState(() => chapters = []); } }

Future<void> _fetchUserData() async { final user = FirebaseAuth.instance.currentUser; if (user == null) return;

final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
try {
  var userDoc = await userRef.get();
  if (!userDoc.exists || userDoc.data() == null) {
    debugPrint('👤 New user – initialising Firestore doc');
    await userRef.set({
      'totalScore': 0,
      'unlockedLevels': {},
      'unlockedModules': {},
      'scrollPositions': {},
      'lastChapterId': '',
      'chapters': {},
    });
    userDoc = await userRef.get();
  }

  final data = userDoc.data() as Map<String, dynamic>?;
  if (data == null) return;

  final newTotalScore = data['totalScore'] as int? ?? 0;
  final newUnlockedLevelsPerChapter = Map<String, int>.from(data['unlockedLevels'] ?? {});
  final Map<String, int> newUnlockedModulesPerChapter = Map<String, int>.from(data['unlockedModules'] ?? {});
  final Map<String, Map<int, int>> newScoresPerLevel = {};
  final Map<String, int> newTotalScorePerChapter = {};

  if (data['chapters'] is Map) {
    (data['chapters'] as Map).forEach((chapterId, chapterData) {
      if (chapterData is Map && chapterData['levelScores'] is Map) {
        newScoresPerLevel[chapterId] = (chapterData['levelScores'] as Map).map(
          (key, value) => MapEntry(int.parse(key.split(' ')[1]), value as int),
        );
        final chapterTotal = newScoresPerLevel[chapterId]!.values.fold<int>(0, (sum, s) => sum + s);
        newTotalScorePerChapter[chapterId] = chapterTotal;
      }
    });
  }

  lastPlayedChapterId = data['lastChapterId'] as String? ?? '';

  await userRef.update({'unlockedModules': newUnlockedModulesPerChapter});

  setState(() {
    totalScore = newTotalScore;
    unlockedLevelsPerChapter = newUnlockedLevelsPerChapter;
    unlockedModulesPerChapter = newUnlockedModulesPerChapter;
    scoresPerLevel = newScoresPerLevel;
    totalScorePerChapter = newTotalScorePerChapter;
  });
} catch (e) {
  debugPrint('❌ Error fetching user data: $e');
}

}

Future<void> _saveScrollPosition() async { final user = FirebaseAuth.instance.currentUser; if (user == null || !_scrollController.hasClients) return;

try {
  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
    'scrollPositions.${lastPlayedChapterId}': _scrollController.position.pixels,
  });
} catch (e) {
  debugPrint('❌ Error saving scroll position: $e');
}

}

// -------------------- INTRO DIALOG -------------------- // void showIntroDialog() { showDialog( context: context, builder: () => AlertDialog( title: Text('Comment progresser ?'.tr()), content: const Text( '1. Joue un QUIZ 🎯\n' '2. Gagne des LEÇONS 🏆\n' '3. Mets-toi en SITUATION 🤖', style: TextStyle(fontSize: 15), ), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))], ), ); }

void _showLastPlayedChapterDialog() { final lastChap = chapters.firstWhereOrNull((c) => c.id == lastPlayedChapterId); if (lastChap == null) return;

showDialog(
  context: context,
  builder: (_) => AlertDialog(
    title: Text('Reprendre là où vous vous êtes arrêté'.tr()),
    content: Text('${'Vous avez terminé sur le chapitre :'.tr()} ${lastChap.title}'),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
  ),
);

}

// -------------------- IMAGE -------------------- // Future<String> _getImageUrl(String gsUrl) async { try { final ref = FirebaseStorage.instance.refFromURL(gsUrl); return await ref.getDownloadURL(); } catch (e) { debugPrint('❌ Error getting image $e'); rethrow; } }

// -------------------- BUILD -------------------- // final _scaffoldKey = GlobalKey<ScaffoldState>();

@override Widget build(BuildContext context) { // Handle route arguments final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?; final selectedChapterId = args?['chapterId'] as String?; final initialScroll = args?['scrollPosition'] as double? ?? 0.0;

if (chapters.isEmpty) {
  return Scaffold(key: _scaffoldKey, body: const Center(child: CircularProgressIndicator()));
}

final chapter = selectedChapterId != null
    ? chapters.firstWhereOrNull((c) => c.id == selectedChapterId)
    : chapters.firstWhereOrNull((c) => c.id == lastPlayedChapterId) ?? chapters.first;

if (chapter == null) {
  return Scaffold(key: _scaffoldKey, body: Center(child: Text('Aucun chapitre trouvé'.tr())));
}

WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!_scrollController.hasClients) return;
  final isCompleted = (unlockedLevelsPerChapter[chapter.id] ?? 0) > chapter.numberOfQuizzes;
  final target = isCompleted
      ? _scrollController.position.maxScrollExtent
      : (initialScroll - MediaQuery.of(context).size.height / 3)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
  _scrollController.animateTo(target, duration: const Duration(seconds: 2), curve: Curves.easeInOut);
});

return Scaffold(
  key: _scaffoldKey,
  appBar: _buildAppBar(chapter),
  body: _buildBody(chapter),
  bottomNavigationBar:
      CustomBottomNavBar(parentContext: context, currentIndex: 0, scaffoldKey: _scaffoldKey),
);

}

AppBar buildAppBar(Chapter chapter) { return AppBar( automaticallyImplyLeading: false, centerTitle: true, backgroundColor: Colors.white, elevation: 1, title: AutoSizeText( chapter.title, maxLines: 1, minFontSize: 12, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.blue.shade900), ), actions: [ Padding( padding: const EdgeInsets.only(right: 8.0), child: RotatingGlowBorder( borderWidth: 2, colors: [Colors.blue.shade800, Colors.blueAccent, Colors.blue.shade300], duration: const Duration(seconds: 30), child: TextButton.icon( onPressed: () => Navigator.push( context, MaterialPageRoute(builder: () => const ChapterMenuPage()), ), style: TextButton.styleFrom( backgroundColor: Colors.white, shape: const StadiumBorder(), minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap, ), icon: Icon(Icons.list, color: Colors.blue.shade800, size: 18), label: Text('Parcours'.tr(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade800)), ), ), ), ], ); }

Widget _buildBody(Chapter chapter) { return Container( decoration: const BoxDecoration( gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [ Colors.white, Colors.white38, ]), ), child: SingleChildScrollView( controller: _scrollController, child: Column( children: [ const SizedBox(height: 1), FutureBuilder<String>( future: getImageUrl(chapter.imageUrl), builder: (context, snapshot) { if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); } if (snapshot.hasError || !snapshot.hasData) { return Icon(Icons.broken_image, size: 180, color: Colors.grey.shade400); } return ClipRRect( borderRadius: BorderRadius.circular(15), child: Image.network( snapshot.data!, width: MediaQuery.of(context).size.width * 0.8, height: 200, fit: BoxFit.cover, errorBuilder: (, __, ___) => Icon(Icons.broken_image, size: 180, color: Colors.grey.shade400), ), ); }, ), const SizedBox(height: 10), _buildUserStats(chapter), const SizedBox(height: 10), ..._buildChapterWidgets(chapter), const SizedBox(height: 80), ], ), ), ); }

// ----- USER STATS ----- // Widget _buildUserStats(Chapter chapter) { final chapterScore = totalScorePerChapter[chapter.id] ?? 0; final chapterUnlockedLevels = unlockedLevelsPerChapter[chapter.id] ?? 1; final chapterUnlockedModules = unlockedModulesPerChapter[chapter.id] ?? 0;

return Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(colors: [Colors.white, Colors.blue.shade50], begin: Alignment.topLeft, end: Alignment.bottomRight),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 3, blurRadius: 7, offset: const Offset(0, 3)),
    ],
  ),
  margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: [
      _buildStatItem(icon: Icons.score, iconColor: Colors.blue.shade900, label: 'Score'.tr(), value: '$chapterScore'),
      _buildStatItem(icon: Icons.star, iconColor: Colors.orange.shade900, label: 'Niveaux'.tr(), value: '$chapterUnlockedLevels'),
      _buildStatItem(icon: Icons.book, iconColor: Colors.green.shade900, label: 'Modules'.tr(), value: '$chapterUnlockedModules'),
    ],
  ),
);

}

Widget _buildStatItem({required IconData icon, required Color iconColor, required String label, required String value}) { return AnimatedBuilder( animation: _gradientCtrl, builder: (context, child) { final t = _gradientCtrl.value; final stops = [(t - 0.3).clamp(0.0, 1.0), t, (t + 0.3).clamp(0.0, 1.0)]; final grad = LinearGradient(colors: [iconColor.withOpacity(0.6), iconColor, iconColor.withOpacity(0.6)], stops: stops, begin: Alignment.topLeft, end: Alignment.bottomRight); return Column( children: [ Container( padding: const EdgeInsets.all(3), decoration: BoxDecoration(shape: BoxShape.circle, gradient: grad), child: CircleAvatar( radius: 26, backgroundColor: Colors.white, child: ShaderMask(shaderCallback: (rect) => grad.createShader(rect), blendMode: BlendMode.srcIn, child: Icon(icon, size: 35)), ), ), const SizedBox(height: 8), ShaderMask(shaderCallback: (rect) => grad.createShader(rect), blendMode: BlendMode.srcIn, child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))), const SizedBox(height: 4), ShaderMask(shaderCallback: (rect) => grad.createShader(rect), blendMode: BlendMode.srcIn, child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))), ], ); }, ); }

// ---------- REST OF ORIGINAL METHODS (LEVEL BUTTONS, PARCOURS, Etc.) ---------- // // For brevity, all other methods (_buildLevelButton, _buildChapterWidgets, etc.) // remain identical to the user original submission except that any setState // calls are now safe (automatically protected) and every debug print uses // debugPrint instead of print. }

// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart'; import 'package:easy_localization/easy_localization.dart'; import 'package:firebase_auth/firebase_auth.dart'; import 'package:firebase_storage/firebase_storage.dart'; import 'package:flutter/foundation.dart'; import 'package:flutter/material.dart'; import 'package:glassmorphism/glassmorphism.dart'; import 'package:google_mobile_ads/google_mobile_ads.dart'; import 'package:lottie/lottie.dart'; import 'package:auto_size_text/auto_size_text.dart'; import 'package:collection/collection.dart';

import 'package:quiz_commercial2024/screens/chapter_menu_page.dart'; import 'package:quiz_commercial2024/screens/simulation.dart'; import '../ad_manager.dart'; import '../drawer/custom_bottom_nav_bar.dart'; import '../rotating_glow_border.dart'; import '../services/firestore_service.dart'; import '../services/models.dart'; import 'compte_rendu_screen.dart'; import 'module_page.dart'; import 'quiz_screen.dart';

class LevelsPage extends StatefulWidget { const LevelsPage({Key? key}) : super(key: key);

@override State<LevelsPage> createState() => _LevelsPageState(); }

class _LevelsPageState extends State<LevelsPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver { InterstitialAd? _interstitialAd; bool _isInterstitialAdReady = false;

final FirestoreService _firestoreService = FirestoreService();

// -------------------- USER DATA -------------------- // List<Chapter> chapters = []; int totalScore = 0; String lastPlayedChapterId = ''; Map<String, int> unlockedLevelsPerChapter = {}; Map<String, int> unlockedModulesPerChapter = {}; Map<String, int> totalScorePerChapter = {}; Map<String, Map<int, int>> scoresPerLevel = {};

// -------------------- UI -------------------- // final ScrollController _scrollController = ScrollController(); final GlobalKey _currentLevelKey = GlobalKey(); late final AnimationController _gradientCtrl; bool _introShown = false; bool _showIntroNow = false;

// -------------------- LIFE CYCLE -------------------- // @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this);

_gradientCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
  ..repeat();

_loadInterstitialAd();
_fetchChapters();
_fetchUserData();

WidgetsBinding.instance.addPostFrameCallback((_) {
  if (lastPlayedChapterId.isNotEmpty) _showLastPlayedChapterDialog();
});

}

@override void didChangeDependencies() { super.didChangeDependencies();

if (!_introShown) {
  final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
  _showIntroNow = (args?['fromMenu'] == true);
  _introShown = true;
  if (_showIntroNow) Future.microtask(_showIntroDialog);
}

}

@override void didChangeAppLifecycleState(AppLifecycleState state) { // Dispose interstitial ad when app goes to background to prevent white screen on resume if (state == AppLifecycleState.paused) { _interstitialAd?.dispose(); _interstitialAd = null; _isInterstitialAdReady = false; } }

@override void dispose() { WidgetsBinding.instance.removeObserver(this); _gradientCtrl.dispose(); _interstitialAd?.dispose();

_saveScrollPosition();
_scrollController.dispose();
super.dispose();

}

// Ensure every setState is safe @override void setState(VoidCallback fn) { if (!mounted) return; super.setState(fn); }

// -------------------- ADS -------------------- // void _loadInterstitialAd() { final adUnitId = kDebugMode ? Platform.isIOS ? AdManager.testInterstitialAdUnitIdIOS : AdManager.testInterstitialAdUnitIdAndroid : AdManager.interstitialAdUnitId;

InterstitialAd.load(
  adUnitId: adUnitId,
  request: const AdRequest(),
  adLoadCallback: InterstitialAdLoadCallback(
    onAdLoaded: (ad) {
      _interstitialAd = ad;
      _isInterstitialAdReady = true;
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadInterstitialAd();
        },
      );
    },
    onAdFailedToLoad: (err) {
      debugPrint('❌ InterstitialAd failed to load: ${err.message}');
      _isInterstitialAdReady = false;
    },
  ),
);

}

// -------------------- FIRESTORE -------------------- // Future<void> _fetchChapters() async { try { chapters = await _firestoreService.getChapters(); if (chapters.isEmpty) debugPrint('ℹ️ No chapters found'); setState(() {}); } catch (e) { debugPrint('❌ Error fetching chapters: $e'); setState(() => chapters = []); } }

Future<void> _fetchUserData() async { final user = FirebaseAuth.instance.currentUser; if (user == null) return;

final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
try {
  var userDoc = await userRef.get();
  if (!userDoc.exists || userDoc.data() == null) {
    debugPrint('👤 New user – initialising Firestore doc');
    await userRef.set({
      'totalScore': 0,
      'unlockedLevels': {},
      'unlockedModules': {},
      'scrollPositions': {},
      'lastChapterId': '',
      'chapters': {},
    });
    userDoc = await userRef.get();
  }

  final data = userDoc.data() as Map<String, dynamic>?;
  if (data == null) return;

  final newTotalScore = data['totalScore'] as int? ?? 0;
  final newUnlockedLevelsPerChapter = Map<String, int>.from(data['unlockedLevels'] ?? {});
  final Map<String, int> newUnlockedModulesPerChapter = Map<String, int>.from(data['unlockedModules'] ?? {});
  final Map<String, Map<int, int>> newScoresPerLevel = {};
  final Map<String, int> newTotalScorePerChapter = {};

  if (data['chapters'] is Map) {
    (data['chapters'] as Map).forEach((chapterId, chapterData) {
      if (chapterData is Map && chapterData['levelScores'] is Map) {
        newScoresPerLevel[chapterId] = (chapterData['levelScores'] as Map).map(
          (key, value) => MapEntry(int.parse(key.split(' ')[1]), value as int),
        );
        final chapterTotal = newScoresPerLevel[chapterId]!.values.fold<int>(0, (sum, s) => sum + s);
        newTotalScorePerChapter[chapterId] = chapterTotal;
      }
    });
  }

  lastPlayedChapterId = data['lastChapterId'] as String? ?? '';

  await userRef.update({'unlockedModules': newUnlockedModulesPerChapter});

  setState(() {
    totalScore = newTotalScore;
    unlockedLevelsPerChapter = newUnlockedLevelsPerChapter;
    unlockedModulesPerChapter = newUnlockedModulesPerChapter;
    scoresPerLevel = newScoresPerLevel;
    totalScorePerChapter = newTotalScorePerChapter;
  });
} catch (e) {
  debugPrint('❌ Error fetching user data: $e');
}

}

Future<void> _saveScrollPosition() async { final user = FirebaseAuth.instance.currentUser; if (user == null || !_scrollController.hasClients) return;

try {
  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
    'scrollPositions.${lastPlayedChapterId}': _scrollController.position.pixels,
  });
} catch (e) {
  debugPrint('❌ Error saving scroll position: $e');
}

}

// -------------------- INTRO DIALOG -------------------- // void showIntroDialog() { showDialog( context: context, builder: () => AlertDialog( title: Text('Comment progresser ?'.tr()), content: const Text( '1. Joue un QUIZ 🎯\n' '2. Gagne des LEÇONS 🏆\n' '3. Mets-toi en SITUATION 🤖', style: TextStyle(fontSize: 15), ), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))], ), ); }

void _showLastPlayedChapterDialog() { final lastChap = chapters.firstWhereOrNull((c) => c.id == lastPlayedChapterId); if (lastChap == null) return;

showDialog(
  context: context,
  builder: (_) => AlertDialog(
    title: Text('Reprendre là où vous vous êtes arrêté'.tr()),
    content: Text('${'Vous avez terminé sur le chapitre :'.tr()} ${lastChap.title}'),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
  ),
);

}

// -------------------- IMAGE -------------------- // Future<String> _getImageUrl(String gsUrl) async { try { final ref = FirebaseStorage.instance.refFromURL(gsUrl); return await ref.getDownloadURL(); } catch (e) { debugPrint('❌ Error getting image $e'); rethrow; } }

// -------------------- BUILD -------------------- // final _scaffoldKey = GlobalKey<ScaffoldState>();

@override Widget build(BuildContext context) { // Handle route arguments final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?; final selectedChapterId = args?['chapterId'] as String?; final initialScroll = args?['scrollPosition'] as double? ?? 0.0;

if (chapters.isEmpty) {
  return Scaffold(key: _scaffoldKey, body: const Center(child: CircularProgressIndicator()));
}

final chapter = selectedChapterId != null
    ? chapters.firstWhereOrNull((c) => c.id == selectedChapterId)
    : chapters.firstWhereOrNull((c) => c.id == lastPlayedChapterId) ?? chapters.first;

if (chapter == null) {
  return Scaffold(key: _scaffoldKey, body: Center(child: Text('Aucun chapitre trouvé'.tr())));
}

WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!_scrollController.hasClients) return;
  final isCompleted = (unlockedLevelsPerChapter[chapter.id] ?? 0) > chapter.numberOfQuizzes;
  final target = isCompleted
      ? _scrollController.position.maxScrollExtent
      : (initialScroll - MediaQuery.of(context).size.height / 3)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
  _scrollController.animateTo(target, duration: const Duration(seconds: 2), curve: Curves.easeInOut);
});

return Scaffold(
  key: _scaffoldKey,
  appBar: _buildAppBar(chapter),
  body: _buildBody(chapter),
  bottomNavigationBar:
      CustomBottomNavBar(parentContext: context, currentIndex: 0, scaffoldKey: _scaffoldKey),
);

}

AppBar buildAppBar(Chapter chapter) { return AppBar( automaticallyImplyLeading: false, centerTitle: true, backgroundColor: Colors.white, elevation: 1, title: AutoSizeText( chapter.title, maxLines: 1, minFontSize: 12, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.blue.shade900), ), actions: [ Padding( padding: const EdgeInsets.only(right: 8.0), child: RotatingGlowBorder( borderWidth: 2, colors: [Colors.blue.shade800, Colors.blueAccent, Colors.blue.shade300], duration: const Duration(seconds: 30), child: TextButton.icon( onPressed: () => Navigator.push( context, MaterialPageRoute(builder: () => const ChapterMenuPage()), ), style: TextButton.styleFrom( backgroundColor: Colors.white, shape: const StadiumBorder(), minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap, ), icon: Icon(Icons.list, color: Colors.blue.shade800, size: 18), label: Text('Parcours'.tr(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade800)), ), ), ), ], ); }

Widget _buildBody(Chapter chapter) { return Container( decoration: const BoxDecoration( gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [ Colors.white, Colors.white38, ]), ), child: SingleChildScrollView( controller: _scrollController, child: Column( children: [ const SizedBox(height: 1), FutureBuilder<String>( future: getImageUrl(chapter.imageUrl), builder: (context, snapshot) { if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); } if (snapshot.hasError || !snapshot.hasData) { return Icon(Icons.broken_image, size: 180, color: Colors.grey.shade400); } return ClipRRect( borderRadius: BorderRadius.circular(15), child: Image.network( snapshot.data!, width: MediaQuery.of(context).size.width * 0.8, height: 200, fit: BoxFit.cover, errorBuilder: (, __, ___) => Icon(Icons.broken_image, size: 180, color: Colors.grey.shade400), ), ); }, ), const SizedBox(height: 10), _buildUserStats(chapter), const SizedBox(height: 10), ..._buildChapterWidgets(chapter), const SizedBox(height: 80), ], ), ), ); }

// ----- USER STATS ----- // Widget _buildUserStats(Chapter chapter) { final chapterScore = totalScorePerChapter[chapter.id] ?? 0; final chapterUnlockedLevels = unlockedLevelsPerChapter[chapter.id] ?? 1; final chapterUnlockedModules = unlockedModulesPerChapter[chapter.id] ?? 0;

return Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(colors: [Colors.white, Colors.blue.shade50], begin: Alignment.topLeft, end: Alignment.bottomRight),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 3, blurRadius: 7, offset: const Offset(0, 3)),
    ],
  ),
  margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: [
      _buildStatItem(icon: Icons.score, iconColor: Colors.blue.shade900, label: 'Score'.tr(), value: '$chapterScore'),
      _buildStatItem(icon: Icons.star, iconColor: Colors.orange.shade900, label: 'Niveaux'.tr(), value: '$chapterUnlockedLevels'),
      _buildStatItem(icon: Icons.book, iconColor: Colors.green.shade900, label: 'Modules'.tr(), value: '$chapterUnlockedModules'),
    ],
  ),
);

}

Widget _buildStatItem({required IconData icon, required Color iconColor, required String label, required String value}) { return AnimatedBuilder( animation: _gradientCtrl, builder: (context, child) { final t = _gradientCtrl.value; final stops = [(t - 0.3).clamp(0.0, 1.0), t, (t + 0.3).clamp(0.0, 1.0)]; final grad = LinearGradient(colors: [iconColor.withOpacity(0.6), iconColor, iconColor.withOpacity(0.6)], stops: stops, begin: Alignment.topLeft, end: Alignment.bottomRight); return Column( children: [ Container( padding: const EdgeInsets.all(3), decoration: BoxDecoration(shape: BoxShape.circle, gradient: grad), child: CircleAvatar( radius: 26, backgroundColor: Colors.white, child: ShaderMask(shaderCallback: (rect) => grad.createShader(rect), blendMode: BlendMode.srcIn, child: Icon(icon, size: 35)), ), ), const SizedBox(height: 8), ShaderMask(shaderCallback: (rect) => grad.createShader(rect), blendMode: BlendMode.srcIn, child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))), const SizedBox(height: 4), ShaderMask(shaderCallback: (rect) => grad.createShader(rect), blendMode: BlendMode.srcIn, child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))), ], ); }, ); }

// ─────────────────────────────────────────────────────────────
  //  ↓↓↓ RESTE DU FICHIER : méthodes Level-Button, Parcours, build(), etc.
  // ─────────────────────────────────────────────────────────────

  // Conserver les animations Lottie "sales" et "quiz"
  Widget _getButtonWithOptionalLottie(int level, Widget button) {
    return Stack(
      alignment: Alignment.center,
      children: [
        button,
        if (level % 8 == 3)
          Positioned(
            left: 20,
            child: Lottie.asset(
              'assets/Animation_salesstat.json',
              width: 120,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
        if (level % 8 == 7)
          Positioned(
            right: 20,
            child: Lottie.asset(
              'assets/Animation_quiz.json',
              width: 120,
              height: 100,
              fit: BoxFit.cover,
            ),
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
    const double offset = 40.0;
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

  // ---------- CHAPITRE + CONTENU  ------------------------------------------

  List<Widget> _buildChapterWidgets(Chapter chapter) {
    final bool isCompletedChapter =
        (unlockedLevelsPerChapter[chapter.id] ?? 1) > 1;

    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
        child: Card(
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Container(
            decoration: BoxDecoration(
              gradient: isCompletedChapter
                  ? LinearGradient(
                      colors: [
                        Colors.lightBlue.shade50,
                        Colors.white,
                        Colors.lightBlue.shade100
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.brown.shade50,
                        Colors.white,
                        Colors.brown.shade50
                      ],
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
                  // Parcours + Quiz
                  ..._buildLevelAndParcoursWidgets(chapter),
                  const SizedBox(height: 15),
                  // Boutons Simulation / Compte-rendu
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
    final List<Widget> widgets = [];

    // Module 1 toujours débloqué
    widgets.add(
      _buildParcoursNumberWidget(1, 0, true, chapter.id),
    );

    int parcoursNumber = 2;

    for (int i = 0; i < chapter.numberOfQuizzes; i++) {
      final bool isUnlocked =
          i + 1 <= (unlockedLevelsPerChapter[chapter.id] ?? 1);

      // Bouton Quiz
      widgets.add(_buildLevelButton(i + 1, chapter, isUnlocked));

      // Un module toutes les 3 quizzes
      if ((i + 1) % 3 == 0) {
        final bool isParcoursUnlocked =
            (scoresPerLevel[chapter.id]?[i + 1] ?? 0) >= 80;

        widgets.add(_buildParcoursNumberWidget(
          parcoursNumber,
          i + 1,
          isParcoursUnlocked,
          chapter.id,
        ));

        if (isParcoursUnlocked) {
          _updateUnlockedModules(chapter.id, parcoursNumber);
        }

        parcoursNumber++;
      }
    }

    return widgets;
  }

  // ---------- PARCOURS (MODULE) --------------------------------------------

  Widget _buildParcoursNumberWidget(
      int num, int level, bool unlocked, String chapId) {
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
              child: _buildAnimatedParcoursContainer(unlocked, desc, num),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedParcoursContainer(
      bool unlocked, String desc, int num) {
    return AnimatedBuilder(
      animation: _gradientCtrl,
      builder: (context, child) {
        final t = _gradientCtrl.value;
        final stops = [(t - .3).clamp(0.0, 1.0), t, (t + .3).clamp(0.0, 1.0)];
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: unlocked
                  ? [
                      Colors.blue.shade300.withOpacity(.7),
                      Colors.blue.shade300.withOpacity(.4),
                      Colors.blue.shade300.withOpacity(.7),
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
                color: Colors.black.withOpacity(.08),
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
                Lottie.asset('assets/animation_book1.json',
                    fit: BoxFit.cover),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    color: Colors.white.withOpacity(.8),
                    child: AutoSizeText(
                      desc.isNotEmpty ? desc : 'Module $num',
                      maxLines: 1,
                      minFontSize: 8,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: unlocked
                            ? Colors.blueGrey.shade800
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- TAP SUR MODULE -----------------------------------------------

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

  EdgeInsetsGeometry _getPaddingForParcoursNumber(int level) {
    const double offset = 40.0;
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

  // ---------- BUILD() -------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final String? selectedChapterId = args?['chapterId'];
    final double initialScrollPosition = args?['scrollPosition'] ?? 0.0;

    if (chapters.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final Chapter chapterToDisplay = selectedChapterId != null
        ? chapters.firstWhere(
            (c) => c.id == selectedChapterId,
            orElse: () => chapters.first,
          )
        : chapters.firstWhere(
            (c) => c.id == lastPlayedChapterId,
            orElse: () => chapters.first,
          );

    // Sauvegarde du dernier chapitre sélectionné
    if (selectedChapterId != null && selectedChapterId != lastPlayedChapterId) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'lastChapterId': selectedChapterId}).catchError((e) {
          debugPrint('Erreur mise à jour chapitre : $e');
        });
      }
    }

    // Scroll initial après build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final bool isChapterCompleted =
            (unlockedLevelsPerChapter[chapterToDisplay.id] ?? 0) >
                chapterToDisplay.numberOfQuizzes;

        final double target = isChapterCompleted
            ? _scrollController.position.maxScrollExtent
            : (initialScrollPosition -
                    MediaQuery.of(context).size.height / 3)
                .clamp(0.0, _scrollController.position.maxScrollExtent);

        _scrollController.animateTo(
          target,
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
        );
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(chapterToDisplay),
      body: _buildBody(chapterToDisplay),
      bottomNavigationBar: CustomBottomNavBar(
        parentContext: context,
        currentIndex: 0,
        scaffoldKey: _scaffoldKey,
      ),
    );
  }

  // ---------- SOUS-WIDGETS pour build() -------------------------------------

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
              Colors.blue.shade300
            ],
            duration: const Duration(seconds: 30),
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChapterMenuPage()),
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 32),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(Icons.list,
                  color: Colors.blue.shade800, size: 18),
              label: Text(
                'Parcours'.tr(),
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

  // ---------- STATISTIQUES UTILISATEUR --------------------------------------

  Widget _buildUserStats(Chapter chapter) {
    final int chapterScore = totalScorePerChapter[chapter.id] ?? 0;
    final int chapterUnlockedLevels = unlockedLevelsPerChapter[chapter.id] ?? 1;
    final int chapterUnlockedModules =
        unlockedModulesPerChapter[chapter.id] ?? 0;

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
            color: Colors.grey.withOpacity(.3),
            spreadRadius: 3,
            blurRadius: 7,
            offset: const Offset(0, 3),
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
            label: 'Score'.tr(),
            value: chapterScore.toString(),
          ),
          _buildStatItem(
            icon: Icons.star,
            iconColor: Colors.orange.shade900,
            label: 'Niveaux'.tr(),
            value: chapterUnlockedLevels.toString(),
          ),
          _buildStatItem(
            icon: Icons.book,
            iconColor: Colors.green.shade900,
            label: 'Modules'.tr(),
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
        final stops = [(t - .3).clamp(0.0, 1.0), t, (t + .3).clamp(0.0, 1.0)];
        final gradient = LinearGradient(
          colors: [
            iconColor.withOpacity(.6),
            iconColor,
            iconColor.withOpacity(.6),
          ],
          stops: stops,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: gradient,
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                child: ShaderMask(
                  shaderCallback: gradient.createShader,
                  blendMode: BlendMode.srcIn,
                  child: Icon(icon, size: 35, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ShaderMask(
              shaderCallback: gradient.createShader,
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
            ShaderMask(
              shaderCallback: gradient.createShader,
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
} // ← FIN DE LA CLASSE LevelsPage
