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
    controller.addListener(() {
      if (reentered) return;
      reentered = true;
      controller.push(Routes.settings);
    });

    controller.push(Routes.catalog);
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
    controller.addListener(() => controller.push(ProductRoute(id++)));
    controller.push(Routes.catalog);

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
});

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
