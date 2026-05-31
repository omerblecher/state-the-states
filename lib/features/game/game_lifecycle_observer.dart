// New file — no Flags equivalent.
// Implements D-10 (build in Phase 2 but mount to game screen in Phase 4) and
// D-11 (auto-pause on .paused/.hidden only; .inactive intentionally ignored).
import 'package:flutter/widgets.dart';
import 'package:state_states/features/game/game_session_notifier.dart';

/// Bridges Flutter app-lifecycle events to [GameSessionNotifier.pauseGame()].
///
/// **Registration:** this observer does nothing until registered with
/// `WidgetsBinding.instance.addObserver(this)`. It is built and tested here
/// (Phase 2) but mounted to the game screen in Phase 4:
///
/// ```dart
/// // In StatefulWidget.initState():
/// WidgetsBinding.instance.addObserver(_observer);
/// // In State.dispose():
/// WidgetsBinding.instance.removeObserver(_observer);
/// ```
///
/// **D-11:** auto-pause fires ONLY on [AppLifecycleState.paused] and
/// [AppLifecycleState.hidden]. [AppLifecycleState.inactive] is intentionally
/// ignored — iOS fires `.inactive` on transient overlays (Notification Center,
/// Control Center, incoming-call banner) which would cause jarring false pauses.
///
/// **D-09 principle:** [AppLifecycleState.resumed] does NOT auto-resume.
/// The player must tap the Resume button explicitly.
class GameLifecycleObserver extends WidgetsBindingObserver {
  GameLifecycleObserver(this._notifier);

  final GameSessionNotifier _notifier;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // D-11: ONLY .paused and .hidden trigger auto-pause.
    // .inactive is intentionally ignored (transient UI overlays, iOS control
    // center, incoming call banner — would cause false pauses).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _notifier.pauseGame();
    }
    // resumeGame() is NOT called on AppLifecycleState.resumed — the player
    // must explicitly tap Resume (D-09 principle extended to lifecycle resume).
  }
}
