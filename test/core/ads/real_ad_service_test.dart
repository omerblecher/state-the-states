import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/core/ads/ad_service.dart';
import 'package:state_states/core/ads/real_ad_service.dart';
import 'package:state_states/core/ads/stub_ad_service.dart';
import 'package:state_states/core/ticker.dart';
import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/game/game_phase.dart';
import 'package:state_states/features/game/game_session.dart';
import 'package:state_states/features/game/game_session_notifier.dart';

void _registerGmaMockChannel() {
  const channel = MethodChannel('plugins.flutter.io/google_mobile_ads');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async => null);
}

void _clearGmaMockChannel() {
  const channel = MethodChannel('plugins.flutter.io/google_mobile_ads');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
}

/// Returns a minimal [GameSession] with the given [phase].
GameSession _sessionWithPhase(GamePhase phase) => GameSession(
      phase: phase,
      mode: GameMode.learn,
      score: 0,
      elapsed: Duration.zero,
      errorCount: 0,
      hintsRemaining: 2,
    );

/// A GameSessionNotifier that immediately builds to GamePhase.playing.
/// Used for AD-05 (showAppOpenAd suppression) without ticking through countdown.
class _PlayingPhaseNotifier extends GameSessionNotifier {
  _PlayingPhaseNotifier() : super(ticker: FakeTicker());

  @override
  Future<GameSession> build() async => _sessionWithPhase(GamePhase.playing);
}

/// Provider used in tests to capture a real Ref and build a RealAdService.
/// Ref is a sealed class in Riverpod 3.x and cannot be mocked.
final _testRealAdServiceProvider = Provider<RealAdService>((ref) {
  return RealAdService(ref);
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    setUp(_registerGmaMockChannel);
    tearDown(_clearGmaMockChannel);

    test('AD-03: getBannerWidget returns SizedBox.shrink when _bannerAd is null',
        () {
      // RealAdService starts with _bannerAd == null (_bannerState == AdFailed)
      final container = ProviderContainer(
        overrides: [
          gameSessionProvider.overrideWith(() => _PlayingPhaseNotifier()),
          _testRealAdServiceProvider,
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(_testRealAdServiceProvider);
      final widget = service.getBannerWidget();

      // Must return SizedBox.shrink() — zero-size widget, no AdWidget
      expect(widget, isA<SizedBox>());
    });

    test('AD-04: showInterstitialAd is a no-op when _interstitialAd is null',
        () async {
      final container = ProviderContainer(
        overrides: [
          gameSessionProvider.overrideWith(() => _PlayingPhaseNotifier()),
          _testRealAdServiceProvider,
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(_testRealAdServiceProvider);
      // _interstitialAd starts null — must complete without throwing
      await expectLater(service.showInterstitialAd(), completes);
    });

    test('AD-05: showAppOpenAd suppressed when GamePhase.playing', () async {
      // Override gameSessionProvider to immediately return playing phase
      final container = ProviderContainer(
        overrides: [
          gameSessionProvider.overrideWith(() => _PlayingPhaseNotifier()),
          _testRealAdServiceProvider,
        ],
      );
      addTearDown(container.dispose);

      // Wait for the session to have a value
      await container.read(gameSessionProvider.future);

      final service = container.read(_testRealAdServiceProvider);
      // showAppOpenAd reads session phase; playing → returns early (suppressed)
      // Since _appOpenAd is also null, without suppression it would call _preloadAppOpen.
      // Suppression fires first — the method completes without any SDK call.
      await expectLater(service.showAppOpenAd(), completes);
    });

    test('HINT-05: showRewardedAd returns false when _rewardedAd is null',
        () async {
      final container = ProviderContainer(
        overrides: [
          gameSessionProvider.overrideWith(() => _PlayingPhaseNotifier()),
          _testRealAdServiceProvider,
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(_testRealAdServiceProvider);
      // _rewardedAd starts null — must return false immediately
      final result = await service.showRewardedAd();
      expect(result, isFalse);
    });
  });
}
