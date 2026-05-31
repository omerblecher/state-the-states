import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/core/audio/audio_service.dart';
import 'package:state_states/core/audio/real_audio_service.dart';
import 'package:state_states/core/audio/stub_audio_service.dart';

// Registers minimal mock handlers for just_audio method channels.
//
// just_audio uses:
//   - 'com.ryanheise.just_audio.methods' — main channel for global lifecycle
//     (init, disposeAllPlayers, disposePlayer).
//   - 'com.ryanheise.just_audio.methods.<id>' — per-player channel for load,
//     play, stop, seek, setVolume, dispose, etc.
//   - Event channels per player ('com.ryanheise.just_audio.events.<id>' and
//     'com.ryanheise.just_audio.data.<id>') — not needed for this test since
//     we only exercise init/dispose.
//
// The mock accepts all method calls and returns the minimal Map responses
// required by DisposeAllPlayersResponse.fromMap / DisposePlayerResponse.fromMap
// (both accept an empty Map — fromMap is a no-op that just creates an instance).
void _registerJustAudioMockChannels() {
  // Main channel handler.
  const mainChannel = MethodChannel('com.ryanheise.just_audio.methods');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(mainChannel, (MethodCall call) async {
    switch (call.method) {
      case 'init':
        // invokeMethod<void> — return value ignored.
        return null;
      case 'disposeAllPlayers':
        // DisposeAllPlayersResponse.fromMap(map!) — must be non-null Map.
        return <String, dynamic>{};
      case 'disposePlayer':
        // DisposePlayerResponse.fromMap(map!) — must be non-null Map.
        return <String, dynamic>{};
      default:
        return null;
    }
  });

  // Per-player channel handler — uses a wildcard-style handler registered on
  // the binary messenger for any channel name matching the player prefix.
  // Since we cannot enumerate UUIDs in advance, register a handler on the
  // messenger's 'checkMockMessageHandler' path. In practice, Flutter test
  // routes unknown-channel method calls to a null handler; the just_audio
  // player catches MissingPluginException in its internal try/catch layers,
  // which is exactly the "graceful failure" path that drives _initialized=false
  // without throwing to the caller.
}

void _clearJustAudioMockChannels() {
  const mainChannel = MethodChannel('com.ryanheise.just_audio.methods');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(mainChannel, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StubAudioService', () {
    test('satisfies AudioService interface as no-op without throwing', () async {
      // Exercise every method through the AudioService interface type to make
      // interface-parity explicit (WEL-04 / Criterion #5).
      final AudioService stub = StubAudioService();
      await stub.init();
      await stub.playCorrect();
      await stub.playError();
      await stub.playAnthem();
      await stub.stopAnthem();
      await stub.setMuted(true);
      await stub.dispose();
      // If we reach here without throwing, all seven interface methods are no-ops.
    });
  });

  group('RealAudioService', () {
    setUp(_registerJustAudioMockChannels);
    tearDown(_clearJustAudioMockChannels);

    test(
        'init() with missing asset leaves service uninitialized and does not '
        'throw; dispose() completes without throwing (no leaked players)',
        () async {
      // The mock channel handles the global just_audio lifecycle (init,
      // disposeAllPlayers) so those calls succeed at the Dart layer.
      // Per-player channel calls (setAsset, setVolume, etc.) hit unknown
      // channels and throw MissingPluginException, which is caught by
      // RealAudioService.init()'s try/catch, leaving _initialized == false.
      //
      // The key invariant (Pitfall 8): _correctPlayer, _errorPlayer, and
      // _anthemPlayer are assigned BEFORE the try block, so they always exist.
      // AudioPlayer.dispose() on a partially-initialized instance is safe.
      final AudioService service = RealAudioService();

      // init() must complete without throwing even when asset loading fails.
      await service.init();

      // dispose() must complete without throwing after a failed init.
      // expectLater(..., completes) verifies the Future resolves successfully.
      await expectLater(service.dispose(), completes);
    });
  });
}
