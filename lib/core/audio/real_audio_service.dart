import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_service.dart';

class RealAudioService implements AudioService {
  late AudioPlayer _correctPlayer;
  late AudioPlayer _errorPlayer;
  late AudioPlayer _anthemPlayer;
  bool _initialized = false;

  @override
  Future<void> init() async {
    _correctPlayer = AudioPlayer();
    _errorPlayer = AudioPlayer();
    _anthemPlayer = AudioPlayer();
    try {
      await _correctPlayer.setAsset('assets/audio/correct.wav');
      await _errorPlayer.setAsset('assets/audio/error.wav');
      // Placeholder anthem (silent WAV in v1; real render is Phase 5, D-05).
      // Looped so the welcome screen plays it continuously.
      await _anthemPlayer.setAsset('assets/audio/anthem_placeholder.wav');
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
  Future<void> playAnthem() async {
    if (!_initialized) return;
    try {
      await _anthemPlayer.seek(Duration.zero);
      unawaited(_anthemPlayer.play());
    } catch (_) {}
  }

  @override
  Future<void> stopAnthem() async {
    if (!_initialized) return;
    try {
      await _anthemPlayer.stop();
    } catch (_) {}
  }

  @override
  Future<void> setMuted(bool muted) async {
    if (!_initialized) return;
    final volume = muted ? 0.0 : 1.0;
    try {
      await _correctPlayer.setVolume(volume);
      await _errorPlayer.setVolume(volume);
      await _anthemPlayer.setVolume(volume);
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await _correctPlayer.dispose();
    await _errorPlayer.dispose();
    await _anthemPlayer.dispose();
  }
}
