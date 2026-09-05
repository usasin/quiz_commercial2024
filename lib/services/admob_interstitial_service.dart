import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'usage_meter.dart';

/// Service AdMob centralisé.
///
/// Objectif : éviter les pubs au milieu du quiz ou pendant l'oral.
/// Les interstitiels s'affichent uniquement aux transitions naturelles :
/// - après un quiz réussi, avant de passer au niveau suivant / simulation / retour module ;
/// - à la fermeture de la page de résultat de simulation.
class AdmobInterstitialService {
  AdmobInterstitialService._();

  static final AdmobInterstitialService instance = AdmobInterstitialService._();

  // ✅ IDs réels AdMob
  static const String _realQuizInterstitialId =
      'ca-app-pub-1360261396564293/4898629147';
  static const String _realSimulationInterstitialId =
      'ca-app-pub-1360261396564293/8806084564';
  static const String _realIosInterstitialId =
      'ca-app-pub-1360261396564293/9243822789';

  // ✅ ID test officiel Google pour éviter les soucis en debug
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';

  InterstitialAd? _quizAd;
  InterstitialAd? _simulationAd;

  bool _loadingQuiz = false;
  bool _loadingSimulation = false;
  DateTime? _lastShownAt;

  String get _quizAdUnitId =>
      kReleaseMode
          ? (defaultTargetPlatform == TargetPlatform.iOS
              ? _realIosInterstitialId
              : _realQuizInterstitialId)
          : _testInterstitialId;

  String get _simulationAdUnitId =>
      kReleaseMode
          ? (defaultTargetPlatform == TargetPlatform.iOS
              ? _realIosInterstitialId
              : _realSimulationInterstitialId)
          : _testInterstitialId;

  Future<bool> _shouldHideForPremium() async {
    try {
      final meter = UsageMeter();
      await meter.initIfNeeded();
      return await meter.isPremium();
    } catch (_) {
      return false;
    }
  }

  bool get _cooldownOk {
    final last = _lastShownAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= const Duration(seconds: 75);
  }

  Future<void> preloadAll() async {
    await Future.wait([
      preloadQuiz(),
      preloadSimulation(),
    ]);
  }

  Future<void> preloadQuiz() async {
    if (_quizAd != null || _loadingQuiz) return;
    if (await _shouldHideForPremium()) return;

    _loadingQuiz = true;
    await InterstitialAd.load(
      adUnitId: _quizAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _quizAd = ad;
          _loadingQuiz = false;
        },
        onAdFailedToLoad: (error) {
          _quizAd = null;
          _loadingQuiz = false;
          debugPrint('AdMob quiz interstitial failed: ${error.code} - ${error.message}');
        },
      ),
    );
  }

  Future<void> preloadSimulation() async {
    if (_simulationAd != null || _loadingSimulation) return;
    if (await _shouldHideForPremium()) return;

    _loadingSimulation = true;
    await InterstitialAd.load(
      adUnitId: _simulationAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _simulationAd = ad;
          _loadingSimulation = false;
        },
        onAdFailedToLoad: (error) {
          _simulationAd = null;
          _loadingSimulation = false;
          debugPrint('AdMob simulation interstitial failed: ${error.code} - ${error.message}');
        },
      ),
    );
  }

  Future<void> showQuizAdIfAvailable() async {
    await _show(
      currentAd: _quizAd,
      clearAd: () => _quizAd = null,
      preloadNext: preloadQuiz,
    );
  }

  Future<void> showSimulationAdIfAvailable() async {
    await _show(
      currentAd: _simulationAd,
      clearAd: () => _simulationAd = null,
      preloadNext: preloadSimulation,
    );
  }

  Future<void> _show({
    required InterstitialAd? currentAd,
    required VoidCallback clearAd,
    required Future<void> Function() preloadNext,
  }) async {
    if (await _shouldHideForPremium()) return;

    // Évite de mettre trop de pubs si l'utilisateur enchaîne très vite.
    if (!_cooldownOk) {
      unawaited(preloadNext());
      return;
    }

    final ad = currentAd;
    if (ad == null) {
      unawaited(preloadNext());
      return;
    }

    final completer = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _lastShownAt = DateTime.now();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        clearAd();
        unawaited(preloadNext());
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        clearAd();
        debugPrint('AdMob interstitial show failed: ${error.code} - ${error.message}');
        unawaited(preloadNext());
        if (!completer.isCompleted) completer.complete();
      },
    );

    await ad.show();
    await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
  }

  void dispose() {
    _quizAd?.dispose();
    _simulationAd?.dispose();
    _quizAd = null;
    _simulationAd = null;
  }
}
