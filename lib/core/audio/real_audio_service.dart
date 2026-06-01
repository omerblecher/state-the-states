import 'dart:async' show Timer, unawaited;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_service.dart';

class RealAudioService implements AudioService {
  late AudioPlayer _correctPlayer;
  late AudioPlayer _errorPlayer;
  late AudioPlayer _anthemPlayer;
  bool _initialized = false;
  Timer? _fadeTimer;
  bool _isMuted = false; // track mute state to skip volume changes when muted

  @override
  Future<void> init() async {
    _correctPlayer = AudioPlayer();
    _errorPlayer = AudioPlayer();
    _anthemPlayer = AudioPlayer();
    try {
      await _correctPlayer.setAsset('assets/audio/correct.wav');
      await _errorPlayer.setAsset('assets/audio/error.wav');
      // Rights-clean anthem rendered via FluidSynth + GeneralUser GS (Phase 5, D-A1).
      // Looped so the welcome screen plays it continuously.
      await _anthemPlayer.setAsset('assets/audio/anthem.wav');
      await _anthemPlayer.setLoopMode(LoopMode.one);
      _initialized = true;
    } on PlayerException catch (e) {
      debugPrint('AudioService init failed: $e');
      _initialized = false;
    } catch (e) {
      debugPrint('AudioService init error: $e');
      _initialized = false;
    }
  }

  @override
  Future<void> playCorrect() async {
    if (!_initialized) return;
    try {
      await _correctPlayer.stop();
      await _correctPlayer.seek(Duration.zero);
      unawaited(_correctPlayer.play());
    } catch (_) {}
  }

  @override
  Future<void> playError() async {
    if (!_initialized) return;
    try {
      await _errorPlayer.stop();
      await _errorPlayer.seek(Duration.zero);
      unawaited(_errorPlayer.play());
    } catch (_) {}
  }

  @override
  Future<void> fadeInAnthem() async {
    if (!_initialized || _isMuted) return;
    _fadeTimer?.cancel();
    double volume = 0.0;
    const int ticks = 25; // 25 × 20ms = 500ms (D-A3)
    const tickInterval = Duration(milliseconds: 20);
    try {
      await _anthemPlayer.setVolume(0.0);
      await _anthemPlayer.seek(Duration.zero);
      unawaited(_anthemPlayer.play());
    } catch (_) {}
    _fadeTimer = Timer.periodic(tickInterval, (timer) async {
      volume = math.min(1.0, volume + 1.0 / ticks);
      try {
        await _anthemPlayer.setVolume(volume);
      } catch (_) {}
      if (volume >= 1.0) timer.cancel();
    });
  }

  @override
  Future<void> fadeOutAnthem() async {
    if (!_initialized) return;
    _fadeTimer?.cancel();
    double volume = _isMuted ? 0.0 : 1.0;
    const int ticks = 40; // 40 × 20ms = 800ms (D-A2)
    const tickInterval = Duration(milliseconds: 20);
    _fadeTimer = Timer.periodic(tickInterval, (timer) async {
      volume = math.max(0.0, volume - 1.0 / ticks);
      try {
        await _anthemPlayer.setVolume(volume);
      } catch (_) {}
      if (volume <= 0.0) {
        timer.cancel();
        try {
          await _anthemPlayer.stop();
        } catch (_) {}
      }
    });
  }

  @override
  Future<void> setMuted(bool muted) async {
    if (!_initialized) return;
    _isMuted = muted; // Phase 5: fade methods check this flag
    final volume = muted ? 0.0 : 1.0;
    try {
      await _correctPlayer.setVolume(volume);
      await _errorPlayer.setVolume(volume);
      await _anthemPlayer.setVolume(volume);
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _fadeTimer?.cancel(); // Phase 5: prevent timer firing after dispose (T-05-03)
    // Safe to dispose unconditionally: _correctPlayer, _errorPlayer, and
    // _anthemPlayer are assigned at the top of init() BEFORE the asset-loading
    // try block, so they always exist even when _initialized is false (i.e.
    // init() failed after assignment). AudioPlayer.dispose() is idempotent on
    // partially-initialized instances and will not throw.
    //
    // Do NOT add an `if (_initialized)` guard here — that would strand the three
    // AudioPlayers as resource leaks whenever init() fails (Pitfall 8).
    await _correctPlayer.dispose();
    await _errorPlayer.dispose();
    await _anthemPlayer.dispose();
  }
}
