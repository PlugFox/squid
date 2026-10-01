import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squid/squid.dart';

import 'src/routes.dart';

/// The callback a [_ThrowingObserver] throws from.
enum _Stage { change, add, remove }

/// Throws from one of its callbacks and records the ones it still receives.
class _ThrowingObserver with NavigationObserver {
  _ThrowingObserver(this.stage);

  final _Stage stage;

  final List<String> events = <String>[];

  @override
  void onChange(
    NavigationController controller,
    NavigationStack previous,
    NavigationStack next,
  ) {
    events.add('change');
    if (stage == _Stage.change) throw StateError('change');
  }

  @override
  void onAdd(NavigationController controller, NavigationRoute route) {
    events.add('add:${route.name}');
    if (stage == _Stage.add) throw StateError('add');
  }

  @override
  void onRemove(NavigationController controller, NavigationRoute route) {
    events.add('remove:${route.name}');
    if (stage == _Stage.remove) throw StateError('remove');
  }
}

/// Records every callback together with what the controller showed then.
class _RecordingObserver with NavigationObserver {
  final List<String> events = <String>[];

  NavigationStack? lastPrevious;

  NavigationStack? lastNext;

  NavigationStack? stackDuringChange;

  @override
  void onChange(
    NavigationController controller,
    NavigationStack previous,
    NavigationStack next,
  ) {
    events.add('change');
    lastPrevious = previous;
    lastNext = next;
    stackDuringChange = controller.stack;
  }

  @override
  void onAdd(NavigationController controller, NavigationRoute route) =>
      events.add('add:${route.name}');

  @override
  void onRemove(NavigationController controller, NavigationRoute route) =>
      events.add('remove:${route.name}');
}

/// Pushes the settings as soon as the catalog appears.
class _ChainingObserver with NavigationObserver {
  @override
  void onAdd(NavigationController controller, NavigationRoute route) {
    if (route == Routes.catalog) controller.push(Routes.settings);
  }
}

void main() => group('observer edge cases', () {
  group('NavigationLogger', () {
    late List<String> lines;

    setUp(() {
      lines = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
      addTearDown(() => debugPrint = previous);
    });

    test('prints without a label and with a custom prefix', () {
      final plain = NavigationController(
        <NavigationRoute>[Routes.home],
        observers: <NavigationObserver>[const NavigationLogger()],
      );
      addTearDown(plain.dispose);
      plain.push(Routes.catalog);
      expect(lines, equals(<String>['[squid] home > catalog']));

      final custom = NavigationController(
        <NavigationRoute>[Routes.home],
        observers: <NavigationObserver>[const NavigationLogger(prefix: 'nav')],
        debugLabel: 'main',
      );
      addTearDown(custom.dispose);
      custom.push(Routes.settings);
      expect(lines, hasLength(2));
      expect(lines.last, equals('[nav][main] home > settings'));
    });

    test('is silent for the initial stack and for the changes that change '
        'nothing', () {
      final controller = NavigationController(
        <NavigationRoute>[Routes.home, Routes.catalog],
        observers: <NavigationObserver>[const NavigationLogger()],
      );
      addTearDown(controller.dispose);
      expect(lines, isEmpty, reason: 'the initial validation is not a change');

      controller
        ..revalidate()
        ..change((stack) => stack)
        ..change((stack) => <NavigationRoute>[Routes.home, Routes.catalog])
        ..push(Routes.catalog);
      expect(lines, isEmpty);

      // The logger is alive: a real change is printed.
      expect(controller.pop(), isTrue);
      expect(lines, equals(<String>['[squid] home']));
    });

    test('prints the whole stack after a rewrite', () {
      final controller = NavigationController(
        <NavigationRoute>[Routes.home],
        observers: <NavigationObserver>[const NavigationLogger()],
      );
      addTearDown(controller.dispose);

      controller.stack = <NavigationRoute>[
        Routes.catalog,
        const ProductRoute(1),
        const ConfirmDialogRoute(),
      ];
      expect(
        lines,
        equals(<String>['[squid] catalog > product > ConfirmDialogRoute']),
      );

      controller.popToRoot();
      expect(lines.last, equals('[squid] catalog'));
    });
  });

  group('a throwing observer', () {
    late List<FlutterErrorDetails> errors;

    setUp(() {
      errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);
    });

    test('does not break the other observers or the commit', () {
      final first = _ThrowingObserver(_Stage.change);
      final second = _RecordingObserver();
      final third = _ThrowingObserver(_Stage.remove);
      final controller = NavigationController(
        <NavigationRoute>[Routes.home],
        observers: <NavigationObserver>[first, second, third],
      );
      addTearDown(controller.dispose);

      controller.push(Routes.catalog);
      expect(
        controller.stack,
        equals(<NavigationRoute>[Routes.home, Routes.catalog]),
        reason: 'committed',
      );
      expect(
        first.events,
        equals(<String>['change']),
        reason: 'its own onAdd is skipped after the throw',
      );
      expect(second.events, equals(<String>['change', 'add:catalog']));
      expect(third.events, equals(<String>['change', 'add:catalog']));
      expect(errors, hasLength(1));
      expect(errors.single.library, equals('squid'));
      expect(errors.single.exception, isStateError);
      expect(
        errors.single.context.toString(),
        contains('notifying the observer'),
      );

      expect(controller.pop(), isTrue);
      expect(controller.stack, equals(<NavigationRoute>[Routes.home]));
      expect(second.events.last, equals('remove:catalog'));
      expect(third.events.last, equals('remove:catalog'));
      expect(errors, hasLength(3), reason: 'one per throwing callback');
    });

    test('a throw from onAdd skips the remaining routes of that observer '
        'only', () {
      final broken = _ThrowingObserver(_Stage.add);
      final recording = _RecordingObserver();
      final controller = NavigationController(
        <NavigationRoute>[Routes.home],
        observers: <NavigationObserver>[broken, recording],
      );
      addTearDown(controller.dispose);

      controller.pushAll(<NavigationRoute>[Routes.catalog, Routes.settings]);
      expect(broken.events, equals(<String>['change', 'add:catalog']));
      expect(
        recording.events,
        equals(<String>['change', 'add:catalog', 'add:settings']),
      );
      expect(errors, hasLength(1));
      expect(controller.length, equals(3));
    });
  });

  test('observers run after the commit with the committed stacks', () {
    final observer = _RecordingObserver();
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      observers: <NavigationObserver>[observer],
    );
    addTearDown(controller.dispose);

    controller.push(Routes.catalog);
    expect(observer.lastPrevious, equals(<NavigationRoute>[Routes.home]));
    expect(
      observer.lastNext,
      equals(<NavigationRoute>[Routes.home, Routes.catalog]),
    );
    expect(
      observer.stackDuringChange,
      equals(<NavigationRoute>[Routes.home, Routes.catalog]),
      reason: 'the controller already shows the new stack',
    );

    controller.stack = <NavigationRoute>[Routes.settings];
    expect(
      observer.events,
      equals(<String>[
        'change',
        'add:catalog',
        'change',
        'add:settings',
        'remove:home',
        'remove:catalog',
      ]),
    );
  });

  test('a change requested by an observer is applied after the current '
      'one', () {
    final recording = _RecordingObserver();
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      observers: <NavigationObserver>[_ChainingObserver(), recording],
    );
    addTearDown(controller.dispose);

    controller.push(Routes.catalog);
    expect(
      controller.stack,
      equals(<NavigationRoute>[Routes.home, Routes.catalog, Routes.settings]),
    );
    expect(
      recording.events,
      equals(<String>['change', 'add:catalog', 'change', 'add:settings']),
      reason: 'two separate commits, each one fully observed',
    );
  });
});
