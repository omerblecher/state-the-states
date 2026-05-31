import 'audio_service.dart';

/// No-op audio service — the default provider value and the test double.
/// Overridden by [RealAudioService] in main.dart for the running app.
class StubAudioService implements AudioService {
  const StubAudioService();

  @override
  Future<void> init() async {}

  @override
  Future<void> playCorrect() async {}

  @override
  Future<void> playError() async {}

  @override
  Future<void> playAnthem() async {}

  @override
  Future<void> stopAnthem() async {}

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<void> dispose() async {}
}
