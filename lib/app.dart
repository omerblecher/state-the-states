import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/home/home_screen.dart';
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
      builder: (context, state) => const MapScreen(),
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
