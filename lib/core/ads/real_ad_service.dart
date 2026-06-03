import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:state_states/features/game/game_session_notifier.dart';
import 'package:state_states/features/game/game_phase.dart';
import 'ad_service.dart';
import 'ad_load_state.dart';
import 'ad_constants.dart';
import 'ad_service_provider.dart';

class RealAdService implements AdService {
  RealAdService(this._ref);

  final Ref _ref;

  // ── Banner ──────────────────────────────────────────────────────────────────
  BannerAd? _bannerAd;
  AdLoadState _bannerState = const AdFailed();

  /// Call once from a screen's [didChangeDependencies] or [initState] with the
  /// device's logical screen width in dp. Safe to call multiple times (loads only once).
  Future<void> loadBannerForWidth(int screenWidthDp) async {
    if (_bannerState is AdLoaded) return; // guard against double-load (T-08-02-04)
    final adSize = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
      screenWidthDp,
    );
    if (adSize == null) return;
    BannerAd(
      adUnitId: kBannerAdUnitId,
      request: const AdRequest(),
      size: adSize,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _bannerAd = ad as BannerAd;
          _bannerState = const AdLoaded();
          // Increment bannerReadyProvider so HomeScreen rebuilds and calls getBannerWidget().
          _ref.read(bannerReadyProvider.notifier).update((n) => n + 1);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _bannerState = const AdFailed();
        },
      ),
    ).load();
  }

  @override
  Widget getBannerWidget() {
    final ad = _bannerAd;
    if (ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }

  // ── Interstitial ─────────────────────────────────────────────────────────
  InterstitialAd? _interstitialAd;

  void _preloadInterstitial() {
    InterstitialAd.load(
      adUnitId: kInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  @override
  Future<void> showInterstitialAd() async {
    final ad = _interstitialAd;
    if (ad == null) return;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _preloadInterstitial(); // preload next immediately on dismiss
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd = null;
      },
    );
    _interstitialAd = null; // null BEFORE show to prevent double-show (T-08-02-03)
    try {
      await ad.show();
    } catch (e) {
      ad.dispose();
      debugPrint('interstitial show threw: $e');
    }
  }

  // ── Rewarded ─────────────────────────────────────────────────────────────
  RewardedAd? _rewardedAd;

  void _preloadRewarded() {
    RewardedAd.load(
      adUnitId: kRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
  }

  @override
  Future<bool> showRewardedAd() async {
    final ad = _rewardedAd;
    if (ad == null) return false;
    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _preloadRewarded();
        // HINT-05: complete(false) on dismiss/skip — reward only from onUserEarnedReward
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd = null;
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    _rewardedAd = null; // null BEFORE show (T-08-02-03)
    try {
      await ad.show(
        onUserEarnedReward: (_, reward) {
          // HINT-05: complete(true) ONLY here — never in dismiss callback (T-08-02-01)
          if (!completer.isCompleted) completer.complete(true);
        },
      );
    } catch (e) {
      ad.dispose();
      debugPrint('rewarded show threw: $e');
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }

  // ── App Open ─────────────────────────────────────────────────────────────
  AppOpenAd? _appOpenAd;
  DateTime? _appOpenLoadTime;
  static const Duration _kAppOpenExpiry = Duration(hours: 4);

  void _preloadAppOpen() {
    AppOpenAd.load(
      adUnitId: kAppOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenLoadTime = DateTime.now();
        },
        onAdFailedToLoad: (_) => _appOpenAd = null,
      ),
    );
  }

  bool get _isAppOpenAdAvailable {
    if (_appOpenAd == null) return false;
    final loadTime = _appOpenLoadTime;
    if (loadTime == null) return false;
    return DateTime.now().difference(loadTime) < _kAppOpenExpiry;
  }

  @override
  Future<void> showAppOpenAd() async {
    // AD-05 / T-08-02-02: suppress App Open during active gameplay or pause.
    final session = _ref.read(gameSessionProvider).value;
    if (session != null &&
        (session.phase == GamePhase.playing ||
            session.phase == GamePhase.paused)) {
      return;
    }

    if (!_isAppOpenAdAvailable) {
      _preloadAppOpen();
      return;
    }
    final ad = _appOpenAd!;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _preloadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _appOpenAd = null;
      },
    );
    _appOpenAd = null; // null BEFORE show (T-08-02-03)
    try {
      await ad.show();
    } catch (e) {
      ad.dispose();
      debugPrint('app open show threw: $e');
    }
  }

  // ── Startup preload ───────────────────────────────────────────────────────
  /// Called once after [MobileAds.instance.initialize()] completes.
  /// Preloads interstitial, rewarded, and App Open ads. Banner is loaded
  /// per-screen via [loadBannerForWidth].
  void preloadAll() {
    _preloadInterstitial();
    _preloadRewarded();
    _preloadAppOpen();
  }
}
