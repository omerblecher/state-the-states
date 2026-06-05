import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/ads/ads_initializer.dart';
import 'core/audio/audio_service_provider.dart';
import 'core/audio/real_audio_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-init audio so anthem is ready before WelcomeScreen's first frame fires
  // fadeInAnthem(). RealAudioService.init() is fast (asset load from bundle).
  final audioSvc = RealAudioService();
  await audioSvc.init();

  await initializeAds();
  runApp(
    ProviderScope(
      overrides: [
        // Swap the silent StubAudioService default for the real just_audio
        // service in the running app (the ProviderScope-override pattern).
        // ref.onDispose ties the three AudioPlayer natives to the ProviderScope
        // lifecycle so dispose() actually runs (no leaked players).
        audioServiceProvider.overrideWith((ref) {
          ref.onDispose(audioSvc.dispose);
          return audioSvc;
        }),
      ],
      child: const App(),
    ),
  );
}
