// Source: C:\code\Claude\FlagsRoundTheWorld\lib\core\ticker.dart (verbatim port)
import 'dart:async';

abstract class Ticker {
  void start(void Function() onTick);
  void stop();
}

class RealTicker implements Ticker {
  Timer? _timer;
  void Function()? _onTick;

  @override
  void start(void Function() onTick) {
    _timer?.cancel(); // cancel any live timer before overwriting (CR-03)
    _onTick = onTick;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick!());
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

class FakeTicker implements Ticker {
  void Function()? _onTick;

  @override
  void start(void Function() onTick) {
    _onTick = onTick;
  }

  @override
  void stop() {
    _onTick = null;
  }

  /// Call from tests to simulate one elapsed second.
  void tick() => _onTick?.call();
}
