import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/game/state_tray.dart';

Widget buildTray({required GameMode mode, bool showName = true}) {
  return MaterialApp(
    home: Scaffold(
      body: StateTray(
        postal: 'CA',
        stateName: 'California',
        mode: mode,
        sequenceIndex: 0,
        cardKey: GlobalKey(),
        showName: showName,
        hintsRemaining: 2,
      ),
    ),
  );
}

void main() {
  testWidgets('Learn mode shows abbreviation on face and state name below',
      (tester) async {
    await tester.pumpWidget(buildTray(mode: GameMode.learn, showName: true));
    // Card face shows 28sp bold abbreviation
    expect(find.text('CA'), findsAtLeastNWidgets(1));
    // Name label shown beneath card
    expect(find.text('California'), findsAtLeastNWidgets(1));
  });

  testWidgets('States Master mode shows state name on face and label below',
      (tester) async {
    await tester
        .pumpWidget(buildTray(mode: GameMode.statesMaster, showName: true));
    // 'California' appears both on card face (17sp) and as label beneath
    expect(find.text('California'), findsAtLeastNWidgets(2));
  });

  testWidgets(
      'Geographical Master mode shows abbreviation only, no name label',
      (tester) async {
    await tester.pumpWidget(
        buildTray(mode: GameMode.geographicalMaster, showName: false));
    // Card face shows abbreviation
    expect(find.text('CA'), findsAtLeastNWidgets(1));
    // No name label beneath card
    expect(find.text('California'), findsNothing);
  });

  testWidgets('Grand Master mode shows no text on card face', (tester) async {
    await tester
        .pumpWidget(buildTray(mode: GameMode.grandMaster, showName: false));
    // Grand Master shows solid colour only — no text
    expect(find.text('CA'), findsNothing);
    expect(find.text('California'), findsNothing);
  });

  testWidgets('Hint button shows hintsRemaining count', (tester) async {
    await tester.pumpWidget(buildTray(mode: GameMode.learn));
    expect(find.text('Hint ×2'), findsOneWidget);
  });

  testWidgets('Draggable carries postal as data', (tester) async {
    await tester.pumpWidget(buildTray(mode: GameMode.learn));
    expect(
      find.byWidgetPredicate(
          (w) => w is Draggable<String> && w.data == 'CA'),
      findsOneWidget,
    );
  });

  testWidgets('triggerBounce does not throw', (tester) async {
    await tester.pumpWidget(buildTray(mode: GameMode.learn));
    final state = tester.state<StateTrayState>(find.byType(StateTray));
    // Smoke test — triggerBounce must not throw
    expect(() => state.triggerBounce(), returnsNormally);
    // Let animation tick a few frames
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
  });
}
