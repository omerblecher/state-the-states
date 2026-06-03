import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ad_service.dart';
import 'real_ad_service.dart';

/// Phase 8: adServiceProvider now returns RealAdService, which implements all
/// four ad types (banner, interstitial, rewarded, App Open) and calls
/// preloadAll() immediately after construction so ads are ready when needed.
///
/// stub_ad_service.dart is retained for tests — do NOT delete it.
final adServiceProvider = Provider<AdService>((ref) {
  final service = RealAdService(ref);
  service.preloadAll();
  return service;
});

/// Notifier that tracks banner-load revision. Incremented by RealAdService.onAdLoaded
/// to notify HomeScreen to rebuild and call getBannerWidget(). Watching this provider
/// is the mechanism that triggers the banner slot to appear after the async ad load.
class BannerReadyNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state = state + 1;
}

final bannerReadyProvider =
    NotifierProvider<BannerReadyNotifier, int>(BannerReadyNotifier.new);
