abstract interface class AudioService {
  Future<void> init();
  Future<void> playCorrect();
  Future<void> playError();

  /// Plays the anthem from the start with a 500ms volume fade-in (D-A3).
  Future<void> fadeInAnthem();

  /// Ramps anthem volume to 0 over ~800ms then stops playback (D-A2).
  Future<void> fadeOutAnthem();

  Future<void> setMuted(bool muted);
  Future<void> dispose();
}
