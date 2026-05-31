import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/core/ticker.dart';

void main() {
  group('RealTicker — CR-03 timer-leak fix', () {
    late RealTicker ticker;

    setUp(() {
      ticker = RealTicker();
    });

    tearDown(() {
      ticker.stop();
    });

    test(
      'start() called twice does not double-fire _onTick (CR-03)',
      () async {
        // Use a Completer-based approach with a tick counter.
        // Two start() calls without an intervening stop() must leave exactly
        // ONE active timer; _onTick should fire only once per second.
        var tickCount = 0;
        ticker.start(() => tickCount++);
        // Calling start() a second time must cancel the first timer.
        ticker.start(() => tickCount++);

        // Wait just over 1 second so the single remaining timer fires once.
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        ticker.stop();

        // If the old timer was NOT cancelled we would see tickCount >= 2.
        expect(tickCount, equals(1));
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );

    test(
      'stop() followed by start() fires at the normal rate (not double) (CR-03)',
      () async {
        var tickCount = 0;
        ticker.start(() => tickCount++);
        await Future<void>.delayed(const Duration(milliseconds: 500));
        ticker.stop();
        // Restart fresh — must not accumulate an extra timer.
        tickCount = 0;
        ticker.start(() => tickCount++);
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        ticker.stop();

        expect(tickCount, equals(1));
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );
  });

  group('FakeTicker', () {
    test('tick() calls registered onTick callback', () {
      final ticker = FakeTicker();
      var called = 0;
      ticker.start(() => called++);
      ticker.tick();
      ticker.tick();
      expect(called, 2);
    });

    test('stop() clears the callback so tick() is a no-op', () {
      final ticker = FakeTicker();
      var called = 0;
      ticker.start(() => called++);
      ticker.stop();
      ticker.tick();
      expect(called, 0);
    });
  });
}
