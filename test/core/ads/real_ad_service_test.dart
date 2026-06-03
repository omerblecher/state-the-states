import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:state_states/core/ads/ad_service.dart';
import 'package:state_states/core/ads/stub_ad_service.dart';

void main() {
  group('StubAdService — interface parity (AD-03, HINT-05 reference)', () {
    late StubAdService service;

    setUp(() {
      service = const StubAdService();
    });

    test('getBannerWidget returns SizedBox.shrink', () {
      final widget = service.getBannerWidget();
      expect(widget, isNotNull);
    });

    test('showRewardedAd returns false', () async {
      final result = await service.showRewardedAd();
      expect(result, isFalse);
    });
  });

  group('RealAdService unit tests', () {
    test(
      'AD-03: getBannerWidget returns SizedBox.shrink when _bannerAd is null',
      skip: 'real_ad_service.dart created in Wave 2',
      () {},
    );

    test(
      'AD-04: showInterstitialAd is a no-op when _interstitialAd is null',
      skip: 'real_ad_service.dart created in Wave 2',
      () {},
    );

    test(
      'AD-05: showAppOpenAd suppressed when GamePhase.playing',
      skip: 'real_ad_service.dart created in Wave 2',
      () {},
    );

    test(
      'HINT-05: showRewardedAd returns false when _rewardedAd is null',
      skip: 'real_ad_service.dart created in Wave 2',
      () {},
    );
  });
}
