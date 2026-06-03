import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/ads/ad_service_provider.dart';
import 'core/ads/app_state_observer.dart';
import 'features/game/game_mode.dart';
import 'features/game/game_phase.dart';
import 'features/game/game_session.dart';
import 'features/game/game_session_notifier.dart';
import 'features/home/home_screen.dart';
import 'features/map/completion_screen.dart';
import 'features/map/map_screen.dart';
import 'features/map/spike_map_screen.dart';
import 'features/tutorial/tutorial_screen.dart';
import 'features/typing/speed_typing_screen.dart';
import 'features/welcome/welcome_screen.dart';

/// Top-level GoRouter — defined at file scope so it is created once and reused.
final _router = GoRouter(
  initialLocation: '/welcome',
  routes: [
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/tutorial',
      builder: (context, state) => const TutorialScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/play',
      builder: (context, state) {
        final mode = state.extra as GameMode? ?? GameMode.learn;
        return MapScreen(mode: mode);
      },
    ),
    GoRoute(
      path: '/type',
      builder: (context, state) => const SpeedTypingScreen(),
    ),
    GoRoute(
      path: '/complete',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return CompletionScreen(
          session: extra['session'] as GameSession,
          previousBest: extra['previousBest'] as int?,
        );
      },
    ),
    // /spike is only registered in debug builds — absent from release APK/IPA.
    // Threat T-03-09: kDebugMode guard prevents SpikeMapScreen disclosure.
    if (kDebugMode)
      GoRoute(
        path: '/spike',
        builder: (context, state) => const SpikeMapScreen(),
      ),
  ],
);

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  StreamSubscription<AppState>? _appStateSubscription;

  @override
  void initState() {
    super.initState();
    AppStateEventNotifier.startListening();
    _appStateSubscription = AppStateEventNotifier.appStateStream.listen(
      (appState) {
        if (appState == AppState.foreground) _onAppResumed();
      },
    );
  }

  void _onAppResumed() {
    // AD-05: suppress App Open during active gameplay or pause.
    final sessionAsync = ref.read(gameSessionProvider);
    if (sessionAsync.isLoading) return; // unknown state — skip
    final phase = sessionAsync.value?.phase;
    if (phase == GamePhase.playing || phase == GamePhase.paused) return;
    ref.read(adServiceProvider).showAppOpenAd();
  }

  @override
  void dispose() {
    _appStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'State the States',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
