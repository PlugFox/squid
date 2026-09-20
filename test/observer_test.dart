import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squid/squid.dart';

import 'src/routes.dart';

void main() => group('observer', () {
  test('the default implementation does nothing', () {
    final observer = _SilentObserver();
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      observers: <NavigationObserver>[observer],
    );
    addTearDown(controller.dispose);

    expect(() => controller.push(Routes.settings), returnsNormally);
  });

  test('a throwing observer is skipped and reported', () {
    final errors = <Object>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exception);
    addTearDown(() => FlutterError.onError = previous);

    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      observers: <NavigationObserver>[_BrokenObserver()],
    );
    addTearDown(controller.dispose);

    controller.push(Routes.settings);
    expect(errors, hasLength(1));
    expect(controller.top, equals(Routes.settings), reason: 'committed');
  });

  test('NavigationLogger prints every change', () {
    final lines = <String>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
    addTearDown(() => debugPrint = previous);

    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      observers: <NavigationObserver>[const NavigationLogger()],
      debugLabel: 'main',
    );
    addTearDown(controller.dispose);

    controller.push(Routes.catalog);
    expect(lines, equals(<String>['[squid][main] home > catalog']));

    controller.pop();
    expect(lines.last, equals('[squid][main] home'));
  });
});

class _SilentObserver with NavigationObserver {}

class _BrokenObserver with NavigationObserver {
  @override
  void onAdd(NavigationController controller, NavigationRoute route) =>
      throw StateError('broken');
}
