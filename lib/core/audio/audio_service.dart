abstract interface class AudioService {
  Future<void> init();
  Future<void> playCorrect();
  Future<void> playError();

  /// Plays the welcome-screen anthem on a loop. Backed by the placeholder WAV
  /// in v1; the real rights-clean render lands in Phase 5 (D-05).
  Future<void> playAnthem();

  /// Stops the anthem (e.g. on transition away from the welcome screen).
  Future<void> stopAnthem();

  Future<void> setMuted(bool muted);
  Future<void> dispose();
}
