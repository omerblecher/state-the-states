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
  // inside initializeAds() (plan 01-01).
  await initializeAds();
  runApp(
    ProviderScope(
      overrides: [
        // Swap the silent StubAudioService default for the real just_audio
        // service in the running app (the ProviderScope-override pattern).
        audioServiceProvider.overrideWith((_) {
          final svc = RealAudioService();
          unawaited(svc.init());
          return svc;
        }),
      ],
      child: const App(),
    ),
  );
}
