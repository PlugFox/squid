import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squid/squid.dart';

import 'src/routes.dart';

void main() => group('controller', () {
  test('an empty initial stack is rejected', () {
    expect(
      () => NavigationController(const <NavigationRoute>[]),
      throwsArgumentError,
    );
  });

  test('push, pop and top', () {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);

    expect(controller.stack, equals(<NavigationRoute>[Routes.home]));
    expect(controller.top, equals(Routes.home));

    controller.push(Routes.settings);
    expect(
      controller.stack,
      equals(<NavigationRoute>[Routes.home, Routes.settings]),
    );

    expect(controller.pop(), isTrue);
    expect(controller.stack, equals(<NavigationRoute>[Routes.home]));

    // The root route is never removed.
    expect(controller.pop(), isFalse);
    expect(controller.stack, equals(<NavigationRoute>[Routes.home]));
  });

  test('an initial stack rejected by the guards is an error', () {
    expect(
      () => NavigationController(
        <NavigationRoute>[Routes.home],
        guards: <NavigationGuard>[
          NavigationGuard((controller, stack) => const <NavigationRoute>[]),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('pushAll adds the routes in order', () {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);

    controller.pushAll(<NavigationRoute>[Routes.catalog, Routes.settings]);
    expect(
      controller.stack,
      equals(<NavigationRoute>[Routes.home, Routes.catalog, Routes.settings]),
    );
  });

  test('the controller is a ValueListenable of the stack', () {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);

    expect(controller.value, same(controller.stack));
    expect(controller.contains(Routes.home), isTrue);
    expect(controller.contains(Routes.settings), isFalse);
    expect(controller.context, isNull, reason: 'no widget is attached');
    expect(controller.navigator, isNull);
  });

  test('the stack is unmodifiable from the outside', () {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);
    expect(() => controller.stack.add(Routes.settings), throwsUnsupportedError);
  });

  test('change rewrites the whole stack', () {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);

    controller.change(
      (stack) => <NavigationRoute>[
        ...stack,
        Routes.catalog,
        const ProductRoute(1),
      ],
    );
    expect(controller.length, equals(3));

    // Mutating the received copy is allowed as well.
    controller.change((stack) => stack..removeLast());
    expect(controller.top, equals(Routes.catalog));
  });

  test('pushing an existing route moves it to the top', () {
    final controller = NavigationController(<NavigationRoute>[
      Routes.home,
      Routes.catalog,
      Routes.settings,
    ]);
    addTearDown(controller.dispose);

    controller.push(Routes.catalog);
    expect(
      controller.stack,
      equals(<NavigationRoute>[Routes.home, Routes.settings, Routes.catalog]),
    );
  });

  test('duplicates are removed keeping the last occurrence', () {
    final controller = NavigationController(<NavigationRoute>[
      Routes.home,
      Routes.home,
      Routes.catalog,
    ]);
    addTearDown(controller.dispose);
    expect(
      controller.stack,
      equals(<NavigationRoute>[Routes.home, Routes.catalog]),
    );
  });

  test('popUntil, popToRoot, removeTag and removeWhere', () {
    final controller = NavigationController(<NavigationRoute>[
      Routes.home,
      Routes.catalog,
      const ProductRoute(1),
      const ConfirmDialogRoute(),
    ]);
    addTearDown(controller.dispose);

    controller.removeTag(kModalTag);
    expect(controller.length, equals(3));

    controller.popUntil((route) => route is! ProductRoute);
    expect(controller.top, equals(Routes.catalog));

    controller
      ..push(const ProductRoute(2))
      ..removeWhere((route) => route is ProductRoute);
    expect(controller.top, equals(Routes.catalog));

    controller.popToRoot();
    expect(controller.stack, equals(<NavigationRoute>[Routes.home]));
  });

  test('replaceTop swaps the visible route', () {
    final controller = NavigationController(<NavigationRoute>[
      Routes.home,
      Routes.catalog,
    ]);
    addTearDown(controller.dispose);

    controller.replaceTop(Routes.settings);
    expect(
      controller.stack,
      equals(<NavigationRoute>[Routes.home, Routes.settings]),
    );
  });

  test('listeners are notified only on a real change', () {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);

    var notifications = 0;
    controller
      ..addListener(() => notifications++)
      ..push(Routes.settings);
    expect(notifications, equals(1));

    // The same stack: nothing changes, nobody is notified.
    controller.change(
      (stack) => <NavigationRoute>[Routes.home, Routes.settings],
    );
    expect(notifications, equals(1));

    controller.pop();
    expect(notifications, equals(2));
  });

  test('guards are applied in order and can rewrite the stack', () {
    final calls = <String>[];
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      guards: <NavigationGuard>[
        NavigationGuard((controller, stack) {
          calls.add('first');
          return stack..add(Routes.catalog);
        }),
        NavigationGuard((controller, stack) {
          calls.add('second');
          expect(stack.last, equals(Routes.catalog));
          return stack;
        }),
      ],
    );
    addTearDown(controller.dispose);

    expect(calls, equals(<String>['first', 'second']));
    expect(
      controller.stack,
      equals(<NavigationRoute>[Routes.home, Routes.catalog]),
    );
  });

  test('a guard can cancel a change by returning the previous stack', () {
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      guards: <NavigationGuard>[
        NavigationGuard(
          (controller, stack) =>
              stack.containsType<ProductRoute>() ? controller.stack : stack,
        ),
      ],
    );
    addTearDown(controller.dispose);

    controller.push(const ProductRoute(1));
    expect(controller.stack, equals(<NavigationRoute>[Routes.home]));

    controller.push(Routes.settings);
    expect(controller.top, equals(Routes.settings));
  });

  test('a throwing guard is skipped and reported', () {
    final errors = <Object>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exception);
    addTearDown(() => FlutterError.onError = previous);

    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      guards: <NavigationGuard>[
        NavigationGuard((controller, stack) => throw StateError('broken')),
        NavigationGuard((controller, stack) => stack..add(Routes.settings)),
      ],
    );
    addTearDown(controller.dispose);

    expect(errors, hasLength(1));
    expect(controller.top, equals(Routes.settings));
  });

  test('revalidate re-runs the guards when the dependency changes', () {
    final signedIn = Flag();
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      guards: <NavigationGuard>[
        GateGuard(
          isOpen: () => signedIn.value,
          tag: 'unauthenticated',
          closed: () => <NavigationRoute>[Routes.signIn],
          opened: () => <NavigationRoute>[Routes.home],
        ),
      ],
      revalidate: signedIn,
    );
    addTearDown(controller.dispose);

    expect(controller.stack, equals(<NavigationRoute>[Routes.signIn]));

    // Everything else is rejected while the gate is closed.
    controller.push(Routes.settings);
    expect(controller.stack, equals(<NavigationRoute>[Routes.signIn]));

    signedIn.value = true;
    expect(controller.stack, equals(<NavigationRoute>[Routes.home]));

    controller.push(Routes.settings);
    expect(controller.top, equals(Routes.settings));

    // Signing out throws the user back to the gate.
    signedIn.value = false;
    expect(controller.stack, equals(<NavigationRoute>[Routes.signIn]));
  });

  test('pushForResult completes with the value passed to pop', () async {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);

    final result = controller.pushForResult<bool>(const ConfirmDialogRoute());
    expect(controller.top, isA<ConfirmDialogRoute>());

    controller.pop(true);
    expect(await result, isTrue);
  });

  test('pushForResult completes with null when removed by a guard', () async {
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      guards: <NavigationGuard>[
        NavigationGuard((controller, stack) => stack.withoutTag(kModalTag)),
      ],
    );
    addTearDown(controller.dispose);

    expect(
      await controller.pushForResult<bool>(const ConfirmDialogRoute()),
      isNull,
    );
  });

  test('pushForResult completes with null on dispose', () async {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    final result = controller.pushForResult<bool>(const ConfirmDialogRoute());
    controller.dispose();
    expect(await result, isNull);
  });

  test('a change requested from a listener is applied afterwards', () {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);

    var reentered = false;
    controller
      ..addListener(() {
        if (reentered) return;
        reentered = true;
        controller.push(Routes.settings);
      })
      ..push(Routes.catalog);
    expect(
      controller.stack,
      equals(<NavigationRoute>[Routes.home, Routes.catalog, Routes.settings]),
    );
  });

  test('an endless chain of reentrant changes is stopped and reported', () {
    final errors = <Object>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exception);
    addTearDown(() => FlutterError.onError = previous);

    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);

    var id = 0;
    controller
      ..addListener(() => controller.push(ProductRoute(id++)))
      ..push(Routes.catalog);

    expect(errors, hasLength(1));
    expect(errors.first, isStateError);
  });

  test('observers report the added and the removed routes', () {
    final observer = _RecordingObserver();
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      observers: <NavigationObserver>[observer],
    );
    addTearDown(controller.dispose);

    controller
      ..push(Routes.catalog)
      ..change((stack) => <NavigationRoute>[Routes.settings]);

    expect(observer.added, equals(<String>['catalog', 'settings']));
    expect(observer.removed, equals(<String>['home', 'catalog']));
    expect(observer.changes, equals(2));
  });

  test('the committed stack cannot be mutated through the caller list', () {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);

    final mine = <NavigationRoute>[Routes.home, Routes.catalog];
    controller.stack = mine;
    mine.add(Routes.settings);

    expect(controller.length, equals(2));
  });

  test('a change after dispose is ignored', () {
    final controller = NavigationController(<NavigationRoute>[Routes.home])
      ..dispose();
    expect(() => controller.push(Routes.settings), returnsNormally);
    expect(controller.length, equals(1));
  });

  test('toString describes the stack', () {
    final controller = NavigationController(<NavigationRoute>[
      Routes.home,
      Routes.catalog,
    ], debugLabel: 'main');
    addTearDown(controller.dispose);
    expect(
      controller.toString(),
      equals('NavigationController(main: home > catalog)'),
    );
  });

  test('a pushForResult requested from a listener and rejected completes', () {
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      guards: <NavigationGuard>[
        NavigationGuard((controller, stack) => stack.withoutTag(kModalTag)),
      ],
    );
    addTearDown(controller.dispose);

    Future<bool?>? result;
    controller
      ..addListener(
        () => result ??= controller.pushForResult<bool>(
          const ConfirmDialogRoute(),
        ),
      )
      ..push(Routes.settings);

    // Completed right after the queue is drained, not only on dispose.
    expect(result, completion(isNull));
    expect(controller.top, equals(Routes.settings));
  });

  test('the result of a pop cancelled by a guard is not reused', () async {
    final locked = Flag(value: true);
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      guards: <NavigationGuard>[
        NavigationGuard(
          (controller, stack) =>
              locked.value &&
                  !stack.containsTag(kModalTag) &&
                  controller.stack.containsTag(kModalTag)
              ? controller.stack
              : stack,
        ),
      ],
    );
    addTearDown(controller.dispose);

    final result = controller.pushForResult<bool>(const ConfirmDialogRoute());
    expect(controller.pop(true), isTrue, reason: 'requested');
    expect(controller.top, isA<ConfirmDialogRoute>(), reason: 'cancelled');

    locked.value = false;
    controller.removeTag(kModalTag);
    expect(await result, isNull, reason: 'the stale `true` is dropped');
  });

  test('remove completes the future of the removed route only', () async {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);

    final product = controller.pushForResult<int>(const ProductRoute(1));
    final dialog = controller.pushForResult<bool>(const ConfirmDialogRoute());

    expect(controller.remove(const ProductRoute(1), 42), isTrue);
    expect(controller.remove(const ProductRoute(1), 43), isFalse);
    expect(await product, equals(42));

    controller.pop(true);
    expect(await dialog, isTrue);
  });

  test('a result of the wrong type completes with null', () async {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);

    final result = controller.pushForResult<bool>(const ConfirmDialogRoute());
    controller.pop('not a bool');
    expect(await result, isNull);
  });

  test('pushing the same route for a result again releases the first', () {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);

    final first = controller.pushForResult<bool>(const ConfirmDialogRoute());
    final second = controller.pushForResult<bool>(const ConfirmDialogRoute());
    expect(first, completion(isNull));

    controller.pop(true);
    expect(second, completion(isTrue));
  });

  test('pushForResult after dispose completes with null', () async {
    final controller = NavigationController(<NavigationRoute>[Routes.home])
      ..dispose();
    expect(
      await controller.pushForResult<bool>(const ConfirmDialogRoute()),
      isNull,
    );
  });

  test('disposing the controller from an observer stops the queue', () {
    final errors = <Object>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exception);
    addTearDown(() => FlutterError.onError = previous);

    late final NavigationController controller;
    controller = NavigationController(
      <NavigationRoute>[Routes.home],
      observers: <NavigationObserver>[_DisposingObserver()],
    );
    // A change is queued by the listener, then the observer disposes the
    // controller before the queue is drained.
    controller
      ..addListener(() => controller.push(Routes.settings))
      ..push(Routes.catalog);

    expect(errors, isEmpty);
    expect(controller.isDisposed, isTrue);
    expect(controller.top, equals(Routes.catalog));
  });

  test('a guard returning an empty stack is reported, the queue goes on', () {
    final errors = <Object>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exception);
    addTearDown(() => FlutterError.onError = previous);

    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      guards: <NavigationGuard>[
        NavigationGuard(
          (controller, stack) => stack.containsKey(Routes.signIn.key)
              ? <NavigationRoute>[]
              : stack,
        ),
      ],
    );
    addTearDown(controller.dispose);

    var queued = false;
    controller
      ..addListener(() {
        if (queued) return;
        queued = true;
        controller
          ..push(Routes.signIn)
          ..push(Routes.settings);
      })
      ..push(Routes.catalog);

    expect(errors, hasLength(1));
    expect(errors.single, isStateError);
    expect(
      controller.stack,
      equals(<NavigationRoute>[Routes.home, Routes.catalog, Routes.settings]),
    );
  });

  test('pop and remove from a listener see the pending changes', () {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);

    var queued = false;
    controller
      ..addListener(() {
        if (queued) return;
        queued = true;
        controller.push(const ProductRoute(1));
        expect(controller.remove(const ProductRoute(1)), isTrue);
        controller.push(Routes.settings);
      })
      ..push(Routes.catalog);

    expect(
      controller.stack,
      equals(<NavigationRoute>[Routes.home, Routes.catalog, Routes.settings]),
    );
  });

  test('a guard can dispose the controller', () async {
    final errors = <Object>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exception);
    addTearDown(() => FlutterError.onError = previous);

    var later = 0;
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      guards: <NavigationGuard>[
        NavigationGuard((controller, stack) {
          // E.g. a sign out tearing down the whole navigation.
          if (stack.contains(Routes.settings)) controller.dispose();
          return stack;
        }),
        NavigationGuard((controller, stack) {
          later++;
          return stack;
        }),
      ],
    );
    expect(later, equals(1), reason: 'the initial validation');

    final result = controller.pushForResult<bool>(Routes.settings);
    expect(controller.isDisposed, isTrue);
    expect(later, equals(1), reason: 'no guard runs after the dispose');
    expect(await result, isNull);
    expect(errors, isEmpty);
    expect(controller.stack, equals(<NavigationRoute>[Routes.home]));
  });

  test('a guard disposing the controller during the initial validation '
      'does not subscribe it to revalidate', () {
    final flag = _CountingListenable();
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      revalidate: flag,
      guards: <NavigationGuard>[
        NavigationGuard((controller, stack) {
          controller.dispose();
          return stack;
        }),
      ],
    );
    expect(controller.isDisposed, isTrue);
    expect(flag.listeners, isEmpty);
  });

  test('observers are not notified about a change after a listener has '
      'disposed the controller', () {
    final errors = <Object>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exception);
    addTearDown(() => FlutterError.onError = previous);

    final observer = _RecordingObserver();
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      observers: <NavigationObserver>[observer],
    );
    controller
      ..addListener(controller.dispose)
      ..push(Routes.catalog);
    expect(errors, isEmpty);
    expect(controller.isDisposed, isTrue);
    expect(observer.changes, isZero);
    expect(observer.added, isEmpty);
  });

  group('maybePop from a listener', () {
    test('returns false when the pending stack has a single route', () async {
      final controller = NavigationController(<NavigationRoute>[
        Routes.home,
        Routes.catalog,
      ]);
      addTearDown(controller.dispose);

      Future<bool>? popped;
      controller.addListener(() => popped ??= controller.maybePop());
      expect(controller.pop(), isTrue);

      expect(controller.stack, equals(<NavigationRoute>[Routes.home]));
      expect(await popped, isFalse);
      expect(controller.stack, equals(<NavigationRoute>[Routes.home]));
    });

    test('pops the route left by the pending changes', () async {
      final controller = NavigationController(<NavigationRoute>[Routes.home]);
      addTearDown(controller.dispose);

      Future<bool>? popped;
      controller
        ..addListener(() => popped ??= controller.maybePop())
        ..pushAll(<NavigationRoute>[Routes.catalog, Routes.settings]);

      expect(await popped, isTrue);
      expect(
        controller.stack,
        equals(<NavigationRoute>[Routes.home, Routes.catalog]),
      );
    });

    test('completes with false when the queue is dropped', () async {
      final errors = <Object>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details.exception);
      addTearDown(() => FlutterError.onError = previous);

      late final NavigationController controller;
      controller = NavigationController(
        <NavigationRoute>[Routes.home],
        observers: <NavigationObserver>[_DisposingObserver()],
      );
      Future<bool>? popped;
      controller
        ..addListener(() => popped ??= controller.maybePop())
        ..push(Routes.catalog);

      expect(controller.isDisposed, isTrue);
      expect(await popped, isFalse);
      expect(errors, isEmpty);
    });
  });

  group('notifications deferred to the end of the frame', () {
    testWidgets('are delivered in order when an observer changes the stack', (
      tester,
    ) async {
      var redirect = false;
      final a = _ChainingObserver();
      final b = _TranscriptObserver();
      final controller = NavigationController(
        <NavigationRoute>[Routes.home],
        guards: <NavigationGuard>[
          NavigationGuard(
            (controller, stack) => redirect && !stack.contains(Routes.catalog)
                ? <NavigationRoute>[...stack, Routes.catalog]
                : stack,
          ),
        ],
        observers: <NavigationObserver>[a, b],
      );
      addTearDown(controller.dispose);

      redirect = true;
      controller.revalidateDuringBuild();
      expect(b.transcript, isEmpty, reason: 'deferred to the end of the frame');
      await tester.pump();

      expect(
        b.transcript,
        equals(<String>[
          'home -> home>catalog',
          'home>catalog -> home>catalog>settings',
        ]),
      );
      expect(a.transcript, equals(b.transcript));
    });

    testWidgets('notify every listener once per frame', (tester) async {
      var redirect = false;
      final controller = NavigationController(
        <NavigationRoute>[Routes.home],
        guards: <NavigationGuard>[
          NavigationGuard(
            (controller, stack) => redirect && !stack.contains(Routes.catalog)
                ? <NavigationRoute>[...stack, Routes.catalog]
                : stack,
          ),
        ],
        observers: <NavigationObserver>[_TranscriptObserver()],
      );
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() {
        // The first notification is the deferred one: the listener reacts
        // with a change of its own, notified synchronously.
        if (notifications++ == 0) controller.push(Routes.settings);
      });

      redirect = true;
      controller.revalidateDuringBuild();
      expect(notifications, isZero);
      await tester.pump();
      expect(notifications, equals(2));
      expect(
        controller.stack,
        equals(<NavigationRoute>[Routes.home, Routes.catalog, Routes.settings]),
      );

      // Nothing has changed since: no spurious notification next frame.
      tester.binding.scheduleFrame();
      await tester.pump();
      await tester.pump();
      expect(notifications, equals(2));
    });

    testWidgets('a change deferred by a listener is notified next frame', (
      tester,
    ) async {
      final redirects = <NavigationRoute>{};
      final controller = NavigationController(
        <NavigationRoute>[Routes.home],
        guards: <NavigationGuard>[
          NavigationGuard(
            (controller, stack) => <NavigationRoute>[
              ...stack,
              for (final route in redirects)
                if (!stack.contains(route)) route,
            ],
          ),
        ],
        observers: <NavigationObserver>[_TranscriptObserver()],
      );
      addTearDown(controller.dispose);

      final seen = <NavigationRoute>[];
      controller.addListener(() {
        seen.add(controller.top);
        if (seen.length > 1) return;
        redirects.add(Routes.settings);
        controller.revalidateDuringBuild();
      });

      redirects.add(Routes.catalog);
      controller.revalidateDuringBuild();
      await tester.pump();
      expect(seen, equals(<NavigationRoute>[Routes.catalog]));
      await tester.pump();
      expect(seen, equals(<NavigationRoute>[Routes.catalog, Routes.settings]));
    });
  });

  test('a stale result of a cancelled pop is not used by a queued removal', () {
    final locked = Flag(value: true);
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      guards: <NavigationGuard>[
        NavigationGuard(
          (controller, stack) =>
              locked.value &&
                  !stack.containsTag(kModalTag) &&
                  controller.stack.containsTag(kModalTag)
              ? controller.stack
              : stack,
        ),
      ],
    );
    addTearDown(controller.dispose);
    final result = controller.pushForResult<bool>(const ConfirmDialogRoute());

    // The pop is cancelled, then a removal without a result is queued.
    controller.change((stack) {
      controller
        ..pop(true)
        ..change((stack) {
          locked.value = false;
          return stack.withoutTag(kModalTag);
        });
      return stack;
    });

    expect(controller.top, equals(Routes.home));
    expect(result, completion(isNull));
  });

  test('a failed callback does not swallow the other events', () {
    final errors = <Object>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exception);
    addTearDown(() => FlutterError.onError = previous);

    final observer = _ThrowingOnAddObserver();
    final controller = NavigationController(
      <NavigationRoute>[Routes.home, Routes.catalog],
      observers: <NavigationObserver>[observer],
    );
    addTearDown(controller.dispose);

    controller.change(
      (stack) => <NavigationRoute>[Routes.home, Routes.settings, Routes.signIn],
    );

    expect(errors, hasLength(2));
    expect(observer.added, equals(<String>['settings', 'signIn']));
    expect(observer.removed, equals(<String>['catalog']));
  });
});

class _ThrowingOnAddObserver with NavigationObserver {
  final List<String> added = <String>[];
  final List<String> removed = <String>[];

  @override
  void onAdd(NavigationController controller, NavigationRoute route) {
    added.add(route.name);
    throw StateError('onAdd');
  }

  @override
  void onRemove(NavigationController controller, NavigationRoute route) =>
      removed.add(route.name);
}

class _RecordingObserver with NavigationObserver {
  final List<String> added = <String>[];
  final List<String> removed = <String>[];
  int changes = 0;

  @override
  void onChange(
    NavigationController controller,
    NavigationStack previous,
    NavigationStack next,
  ) => changes++;

  @override
  void onAdd(NavigationController controller, NavigationRoute route) =>
      added.add(route.name);

  @override
  void onRemove(NavigationController controller, NavigationRoute route) =>
      removed.add(route.name);
}

class _DisposingObserver with NavigationObserver {
  @override
  void onChange(
    NavigationController controller,
    NavigationStack previous,
    NavigationStack next,
  ) => controller.dispose();
}

/// Records every transition as `previous -> next`, and pushes the settings
/// on the first one.
class _ChainingObserver extends _TranscriptObserver {
  @override
  void onChange(
    NavigationController controller,
    NavigationStack previous,
    NavigationStack next,
  ) {
    super.onChange(controller, previous, next);
    if (transcript.length == 1) controller.push(Routes.settings);
  }
}

/// Records every transition as `previous -> next`.
class _TranscriptObserver with NavigationObserver {
  final List<String> transcript = <String>[];

  static String _names(NavigationStack stack) =>
      stack.map<String>((route) => route.name).join('>');

  @override
  void onChange(
    NavigationController controller,
    NavigationStack previous,
    NavigationStack next,
  ) => transcript.add('${_names(previous)} -> ${_names(next)}');
}

/// A listenable that exposes its listeners, to check for the leaks.
class _CountingListenable implements Listenable {
  final List<VoidCallback> listeners = <VoidCallback>[];

  @override
  void addListener(VoidCallback listener) => listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => listeners.remove(listener);
}
