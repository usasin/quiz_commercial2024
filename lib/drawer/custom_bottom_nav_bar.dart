import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_manager.dart';
import '../rotating_glow_border.dart';

class CustomBottomNavBar extends StatefulWidget {
  final BuildContext parentContext;
  final int currentIndex;
  final GlobalKey<ScaffoldState> scaffoldKey;

  const CustomBottomNavBar({
    required this.parentContext,
    required this.currentIndex,
    required this.scaffoldKey,
    Key? key,
  })  : assert(currentIndex >= 0, 'currentIndex ne doit pas être négatif'),
        super(key: key);

  @override
  _CustomBottomNavBarState createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  static const int _itemCount = 5;

  bool isNavigating = false;
  String lastPlayedChapterId = '';
  Map<String, double> savedScrollPositions = {};

  late InterstitialAd _interstitialAd;
  bool _isInterstitialAdReady = false;

  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();
    _loadUserData();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdManager.interstitialAdUnitId,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          _interstitialAd.fullScreenContentCallback = FullScreenContentCallback(
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

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          lastPlayedChapterId = data['lastChapterId'] ?? '';
          savedScrollPositions = (data['scrollPositions'] as Map?)
              ?.map((k, v) => MapEntry(k as String, (v as num).toDouble())) ??
              {};
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement user data : $e');
    }
  }

  void _onItemTapped(int index) {
    if (isNavigating || !mounted) return;
    setState(() => isNavigating = true);

    final route = _getRouteName(index);
    final args = _getRouteArguments(index);

    void navigate() {
      Navigator.pushReplacementNamed(
        widget.parentContext,
        route,
        arguments: args,
      ).whenComplete(() {
        if (mounted) setState(() => isNavigating = false);
      }).catchError((e) {
        debugPrint('Erreur navigation : $e');
        if (mounted) setState(() => isNavigating = false);
      });
    }

    if (_isInterstitialAdReady) {
      _interstitialAd.show();
      _interstitialAd.fullScreenContentCallback =
          FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              navigate();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              navigate();
            },
          );
    } else {
      navigate();
    }
  }

  String _getRouteName(int index) {
    switch (index) {
      case 0:
        return '/levels';
      case 1:
        return '/lessons';
      case 2:
        return '/leaderboard';
      case 3:
        return '/challenge-menu';
      case 4:
        return '/settings';
      default:
        return '/';
    }
  }

  Map<String, dynamic>? _getRouteArguments(int index) {
    if (index == 0) {
      return {
        'chapterId': lastPlayedChapterId,
        'scrollPosition': savedScrollPositions[lastPlayedChapterId] ?? 0.0,
      };
    }
    return null;
  }

  @override
  void dispose() {
    if (_isInterstitialAdReady) {
      _interstitialAd.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeIndex = widget.currentIndex.clamp(0, _itemCount - 1);

    return BottomNavigationBar(
      currentIndex: safeIndex,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue.shade800,
      unselectedItemColor: Colors.grey,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
      items: List.generate(_itemCount, (i) {
        final selected = i == safeIndex;
        final colors = _colorsForIndex(i, selected);
        return BottomNavigationBarItem(
          icon: _buildIcon(i, colors, selected),
          label: _labelForIndex(i),
        );
      }),
    );
  }

  _Colors _colorsForIndex(int index, bool selected) {
    switch (index) {
      case 3:
        return _Colors(
          selected ? Colors.indigo.shade900 : Colors.indigo.shade200,
          selected ? Colors.indigo.shade400 : Colors.indigo.shade50,
        );
      case 4:
        return _Colors(
          selected ? Colors.black : Colors.grey.shade600,
          selected ? Colors.black54 : Colors.grey.shade400,
        );
      default:
        return _Colors(
          selected ? Colors.blue.shade900 : Colors.grey.shade400,
          selected ? Colors.blue.shade300 : Colors.grey.shade200,
        );
    }
  }

  IconData _iconForIndex(int index) {
    switch (index) {
      case 0:
        return Icons.home;
      case 1:
        return Icons.book;
      case 2:
        return Icons.leaderboard;
      case 3:
        return Icons.sports_esports;
      case 4:
        return Icons.settings;
      default:
        return Icons.home;
    }
  }

  String _labelForIndex(int index) {
    switch (index) {
      case 0:
        return 'Accueil'.tr();
      case 1:
        return 'Apprendre'.tr();
      case 2:
        return 'Top & profil'.tr();
      case 3:
        return 'En ligne'.tr();
      case 4:
        return 'Paramètres'.tr();
      default:
        return 'Accueil'.tr();
    }
  }

  Widget _buildIcon(int index, _Colors colors, bool selected) {
    final circle = Container(
      width: selected ? 60 : 35,
      height: selected ? 60 : 35,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Center(
        child: Icon(
          _iconForIndex(index),
          color: selected ? colors.start : Colors.grey.shade600,
          size: selected ? 30 : 20,
        ),
      ),
    );

    if (selected) {
      return RotatingGlowBorder(
        borderWidth: 2.0,
        colors: [colors.start, colors.end],
        duration: const Duration(seconds: 10),
        child: circle,
      );
    } else {
      return circle;
    }
  }
}

class _Colors {
  final Color start;
  final Color end;
  const _Colors(this.start, this.end);
}
