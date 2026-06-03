import 'package:flutter/widgets.dart';
import 'ad_service.dart';

/// No-op ad service — the v1 COPPA walled garden. This is the ONLY AdService
/// implementation wired in v1 (see ad_service_provider.dart). [getBannerWidget]
/// returns [SizedBox.shrink()] so screens compile with no visible ads; all
/// async methods complete immediately. The real AdMob service is v2 scope.
class StubAdService implements AdService {
  const StubAdService();

  @override
  Widget getBannerWidget() => const SizedBox.shrink();

  @override
  Future<void> loadBannerForWidth(int screenWidthDp) async {}

  @override
  Future<void> showInterstitialAd() async {}

  @override
  Future<bool> showRewardedAd() async => false;

  @override
  Future<void> showAppOpenAd() async {}
}
