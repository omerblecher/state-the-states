import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/game/game_mode.dart';
import 'features/game/game_session.dart';
import 'features/home/home_screen.dart';
import 'features/map/completion_screen.dart';
import 'features/map/map_screen.dart';
import 'features/map/spike_map_screen.dart';

/// Top-level GoRouter — defined at file scope so it is created once and reused.
final _router = GoRouter(
  initialLocation: '/',
  routes: [
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

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'State the States',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
