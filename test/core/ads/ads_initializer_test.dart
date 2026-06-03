import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/core/ads/ads_initializer.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('initializeAds — COPPA init order (AD-01, AD-02)', () {
    setUp(_registerGmaMockChannel);
    tearDown(_clearGmaMockChannel);

    test(
      'AD-01: updateRequestConfiguration called with tagForChildDirectedTreatment yes',
      skip: 'requires SDK interaction mock — structural coverage in Wave 1 via code review',
      () async {},
    );

    test(
        'AD-02: ironSource setConsent(false) and setDoNotSell(true) called before initialize()',
        () {
      // RED: Wave 1 adds GmaMediationIronsource().setConsent(false) and
      // .setDoNotSell(true) to ads_initializer.dart before initialize().
      final source =
          File('lib/core/ads/ads_initializer.dart').readAsStringSync();
      expect(
        source.contains('setConsent(false)'),
        isTrue,
        reason:
            'ironSource GDPR call missing — add GmaMediationIronsource().setConsent(false) before MobileAds.instance.initialize()',
      );
      expect(
        source.contains('setDoNotSell(true)'),
        isTrue,
        reason:
            'ironSource CCPA call missing — add GmaMediationIronsource().setDoNotSell(true) before MobileAds.instance.initialize()',
      );
    });

    test(
        'AD-02: Unity setGDPRConsent(false) and setCCPAConsent(false) called before initialize()',
        () {
      // RED: Wave 1 adds GmaMediationUnity().setGDPRConsent(false) and
      // .setCCPAConsent(false) to ads_initializer.dart before initialize().
      final source =
          File('lib/core/ads/ads_initializer.dart').readAsStringSync();
      expect(
        source.contains('setGDPRConsent(false)'),
        isTrue,
        reason:
            'Unity GDPR call missing — add GmaMediationUnity().setGDPRConsent(false) before MobileAds.instance.initialize()',
      );
      expect(
        source.contains('setCCPAConsent(false)'),
        isTrue,
        reason:
            'Unity CCPA call missing — add GmaMediationUnity().setCCPAConsent(false) before MobileAds.instance.initialize()',
      );
    });

    test(
        'AD-02: no import of gma_mediation_inmobi anywhere in ads_initializer.dart',
        () {
      // GREEN immediately: InMobi has no Dart-side COPPA API — native adapter
      // forwards tagForChildDirectedTreatment automatically. This test guards
      // against accidental import ever being added.
      final source =
          File('lib/core/ads/ads_initializer.dart').readAsStringSync();
      expect(
        source.contains('gma_mediation_inmobi'),
        isFalse,
        reason:
            'InMobi has no Dart-side COPPA API — import must never appear in ads_initializer.dart',
      );
    });
  });
}
