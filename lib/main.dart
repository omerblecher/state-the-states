import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/ads/ads_initializer.dart';
import 'core/audio/audio_service_provider.dart';
import 'core/audio/real_audio_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // COPPA init: child-directed flags are set BEFORE MobileAds.initialize()
  // inside initializeAds() (plan 01-01). v1 ships zero real ads (StubAdService
  // walled garden), so a failed/slow ad-SDK init must NOT block app launch —
  // especially on low-end child hardware. Guard it; the app is fully functional
  // without the SDK initialized.
  try {
    await initializeAds();
  } catch (e) {
    debugPrint('initializeAds failed (non-fatal in v1, no real ads): $e');
  }
  runApp(
    ProviderScope(
      overrides: [
        // Swap the silent StubAudioService default for the real just_audio
        // service in the running app (the ProviderScope-override pattern).
        // ref.onDispose ties the three AudioPlayer natives to the ProviderScope
        // lifecycle so dispose() actually runs (no leaked players).
        audioServiceProvider.overrideWith((ref) {
          final svc = RealAudioService();
          unawaited(svc.init());
          ref.onDispose(svc.dispose);
          return svc;
        }),
      ],
      child: const App(),
    ),
  );
}
