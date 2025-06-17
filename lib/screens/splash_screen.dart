import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_manager.dart';
import 'levels_page.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  AppOpenAd? _appOpenAd;

  @override
  void initState() {
    super.initState();
    _loadAndShowAppOpenAd();
  }

  void _loadAndShowAppOpenAd() {
    AppOpenAd.load(
      adUnitId: AdManager.appOpenAdUnitId,
      request: AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (AppOpenAd ad) {
          _appOpenAd = ad;
          // Enregistrement des callbacks full-screen
          _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (AppOpenAd ad) {
              // Optionnel : log, analytics…
            },
            onAdDismissedFullScreenContent: (AppOpenAd ad) {
              ad.dispose();
              _goToHome();
            },
            onAdFailedToShowFullScreenContent: (AppOpenAd ad, AdError error) {
              ad.dispose();
              _goToHome();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (LoadAdError error) {
          // Si l’annonce ne charge pas, on passe directement
          _goToHome();
        },
      ),
    );
  }

  void _goToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LevelsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset('assets/images/logo.png', width: 150),
      ),
    );
  }
}

