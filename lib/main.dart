import 'package:flutter/material.dart';

// Placeholder main.dart — replaced in plan 01-04 with full app entry point.
// Kept minimal so the project compiles while the app shell is being built.
void main() {
  runApp(const _PlaceholderApp());
}

class _PlaceholderApp extends StatelessWidget {
  const _PlaceholderApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'State the States',
      home: Scaffold(
        body: Center(
          child: Text('State the States — loading…'),
        ),
      ),
    );
  }
}
