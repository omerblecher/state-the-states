import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_service.dart';
import 'stub_audio_service.dart';

/// Defaults to the no-op [StubAudioService] so tests and any un-overridden
/// context stay silent. main.dart overrides this with a [RealAudioService]
/// (the ProviderScope-override pattern) for the running app.
final audioServiceProvider =
    Provider<AudioService>((ref) => const StubAudioService());
