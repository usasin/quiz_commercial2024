import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/usage_meter.dart';

/// Bannière AdMob sûre.
///
/// Elle est prévue uniquement pour les pages calmes : accueil / niveaux.
/// Ne pas l'utiliser dans un quiz ou pendant une simulation orale.
class AdmobBanner extends StatefulWidget {
  final EdgeInsetsGeometry margin;
  final bool hideForPremium;

  const AdmobBanner({
    super.key,
    this.margin = const EdgeInsets.fromLTRB(12, 6, 12, 6),
    this.hideForPremium = true,
  });

  @override
  State<AdmobBanner> createState() => _AdmobBannerState();
}

class _AdmobBannerState extends State<AdmobBanner> {
  static const String _realAndroidBannerId =
      'ca-app-pub-1360261396564293/5395872499';
  static const String _realIosBannerId =
      'ca-app-pub-1360261396564293/1688157587';

  static const String _testAndroidBannerId =
      'ca-app-pub-3940256099942544/6300978111';

  BannerAd? _bannerAd;
  AdSize? _adSize;
  bool _loaded = false;
  bool _blockedForPremium = false;
  bool _started = false;

  String get _bannerUnitId =>
      kReleaseMode
          ? (defaultTargetPlatform == TargetPlatform.iOS
              ? _realIosBannerId
              : _realAndroidBannerId)
          : _testAndroidBannerId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadOnce();
  }

  Future<void> _loadOnce() async {
    if (_started) return;
    _started = true;

    if (widget.hideForPremium) {
      final premium = await UsageMeter().isPremium();
      if (!mounted) return;
      if (premium) {
        setState(() => _blockedForPremium = true);
        return;
      }
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final int availableWidth = math.max(1, screenWidth.floor() - 24);
    final int adWidth = availableWidth < 320
        ? availableWidth
        : math.min(availableWidth, 720);

    final AnchoredAdaptiveBannerAdSize? adaptiveSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(adWidth);

    if (!mounted) return;

    final AdSize size = adaptiveSize ?? AdSize.banner;
    _adSize = size;

    final ad = BannerAd(
      adUnitId: _bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _bannerAd = ad as BannerAd;
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('AdMob banner failed: ${error.code} - ${error.message}');
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _loaded = false;
          });
        },
      ),
    );

    await ad.load();
  }

  @override
  Widget build(BuildContext context) {
    if (_blockedForPremium || !_loaded || _bannerAd == null || _adSize == null) {
      return const SizedBox.shrink();
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final double safeWidth = math.min(
      _adSize!.width.toDouble(),
      math.max(1.0, screenWidth - 24.0),
    );

    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: widget.margin,
        child: Center(
          child: SizedBox(
            width: safeWidth,
            height: _adSize!.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}
