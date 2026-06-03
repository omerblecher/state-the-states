import 'package:flutter/widgets.dart';

abstract interface class AdService {
  /// Returns a banner widget sized to the adaptive banner loaded for this session.
  /// Returns [SizedBox.shrink()] if no banner is loaded.
  /// Callers embed this in their layout — no SDK imports needed in screens.
  Widget getBannerWidget();

  /// Loads an adaptive banner for [screenWidthDp]. Safe to call multiple times
  /// (loads only once). Call from initState via addPostFrameCallback, never from build().
  Future<void> loadBannerForWidth(int screenWidthDp);

  /// Shows the preloaded interstitial ad if available. Safe to call when no ad
  /// is loaded (silently no-ops). Call once in initState — never in build().
  Future<void> showInterstitialAd();

  /// Shows the preloaded rewarded ad. Returns [true] if the user watched to
  /// completion and earned the reward; returns [false] if dismissed, unavailable,
  /// or the ad failed to show. Caller grants hint refill only on [true].
  Future<bool> showRewardedAd();

  /// Shows the App Open ad if one is loaded and not expired (4-hour window).
  /// Suppression (gameplay active) is the caller's responsibility — see app.dart.
  Future<void> showAppOpenAd();
}
