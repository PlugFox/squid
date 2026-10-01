import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squid/squid.dart';

import 'src/routes.dart';

/// A route with a configurable priority and tags, so that the guards can be
/// fed with every combination they have to handle.
final class _Route with NavigationRoute {
  const _Route(this.id, {this.priority = 0, this.tags = const <String>{}});

  final String id;

  @override
  final int priority;

  @override
  final Set<String> tags;

  @override
  String get name => id;

  @override
  Widget build(BuildContext context) => Text(id);
}

/// A route sharing its key with [Routes.home] without being the same object:
/// what a deep link parser or a state restoration produces.
final class _HomeTwin with NavigationRoute {
  const _HomeTwin();

  @override
  String get name => 'home';

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A context guard adding a side pane once it can see the widget tree.
final class _PaneGuard extends ContextGuard {
  _PaneGuard();

  static const _Route pane = _Route('pane', tags: <String>{'pane'});

  int calls = 0;

  @override
  NavigationStack guard(BuildContext context, NavigationStack stack) {
    calls++;
    return stack.containsTag('pane')
        ? stack
        : <NavigationRoute>[...stack, pane];
  }
}

void main() => group('guards edge cases', () {
  late NavigationController controller;

  setUp(() {
    controller = NavigationController(<NavigationRoute>[Routes.home]);
  });

  tearDown(() => controller.dispose());

  group('PriorityGuard', () {
    const guard = PriorityGuard();

    test('returns the same instance for an empty or a single route stack', () {
      final empty = <NavigationRoute>[];
      final single = <NavigationRoute>[const ConfirmDialogRoute()];
      expect(guard(controller, empty), same(empty));
      expect(guard(controller, single), same(single));
    });

    test('returns the same instance when every priority is equal', () {
      final stack = <NavigationRoute>[
        Routes.settings,
        const ProductRoute(2),
        Routes.catalog,
        const ProductRoute(1),
      ];
      expect(guard(controller, stack), same(stack));
    });

    test('returns the same instance for a sorted mix of priorities', () {
      final stack = <NavigationRoute>[
        const _Route('splash', priority: -2),
        Routes.home,
        Routes.catalog,
        const ConfirmDialogRoute(),
        const _Route('toast', priority: 5),
      ];
      expect(guard(controller, stack), same(stack));
    });

    test('orders negative, zero and positive priorities', () {
      final result = guard(controller, <NavigationRoute>[
        const _Route('toast', priority: 5),
        Routes.catalog,
        const ConfirmDialogRoute(),
        const _Route('splash', priority: -2),
        Routes.home,
      ]);
      expect(
        result,
        equals(<NavigationRoute>[
          const _Route('splash', priority: -2),
          Routes.home,
          Routes.catalog,
          const ConfirmDialogRoute(),
          const _Route('toast', priority: 5),
        ]),
      );
    });

    test('keeps the relative order of the routes with an equal priority', () {
      final result = guard(controller, <NavigationRoute>[
        const FiltersSheetRoute(),
        const ProductRoute(2),
        const ConfirmDialogRoute(),
        const ProductRoute(1),
        Routes.home,
      ]);
      expect(
        result,
        equals(<NavigationRoute>[
          Routes.home,
          const ProductRoute(2),
          const ProductRoute(1),
          const FiltersSheetRoute(),
          const ConfirmDialogRoute(),
        ]),
      );
    });

    test('swaps a two routes stack in the wrong order', () {
      final result = guard(controller, <NavigationRoute>[
        const ConfirmDialogRoute(),
        Routes.home,
      ]);
      expect(
        result,
        equals(<NavigationRoute>[Routes.home, const ConfirmDialogRoute()]),
      );
    });

    test('does not modify the received stack and returns a growable one', () {
      final stack = <NavigationRoute>[const ConfirmDialogRoute(), Routes.home];
      final result = guard(controller, stack);
      expect(
        stack,
        equals(<NavigationRoute>[const ConfirmDialogRoute(), Routes.home]),
      );
      expect(() => result.add(Routes.catalog), returnsNormally);
    });

    test('in a controller, pop removes the top of the sorted stack', () {
      final sorted = NavigationController(
        <NavigationRoute>[const ConfirmDialogRoute(), Routes.home],
        guards: <NavigationGuard>[guard],
      );
      addTearDown(sorted.dispose);
      expect(
        sorted.stack,
        equals(<NavigationRoute>[Routes.home, const ConfirmDialogRoute()]),
      );

      sorted.push(Routes.catalog);
      expect(
        sorted.stack,
        equals(<NavigationRoute>[
          Routes.home,
          Routes.catalog,
          const ConfirmDialogRoute(),
        ]),
      );

      expect(sorted.pop(), isTrue);
      expect(
        sorted.stack,
        equals(<NavigationRoute>[Routes.home, Routes.catalog]),
        reason: 'the dialog floats on top, so it is the one popped',
      );
    });
  });

  group('RootGuard', () {
    final guard = RootGuard(() => Routes.home);

    test('moves the root from the middle to the bottom keeping the rest', () {
      expect(
        guard(controller, <NavigationRoute>[
          Routes.catalog,
          Routes.home,
          Routes.settings,
        ]),
        equals(<NavigationRoute>[Routes.home, Routes.catalog, Routes.settings]),
      );
    });

    test('inserts the root under a stack of several routes', () {
      expect(
        guard(controller, <NavigationRoute>[Routes.catalog, Routes.settings]),
        equals(<NavigationRoute>[Routes.home, Routes.catalog, Routes.settings]),
      );
    });

    test('accepts a different instance with the same key at the bottom', () {
      final stack = <NavigationRoute>[const _HomeTwin(), Routes.catalog];
      expect(guard(controller, stack), same(stack));
    });

    test('replaces a same key instance found above the bottom', () {
      final result = guard(controller, <NavigationRoute>[
        Routes.catalog,
        const _HomeTwin(),
      ]);
      expect(result, hasLength(2));
      expect(result.first, same(Routes.home));
      expect(result.last, same(Routes.catalog));
    });

    test('consults the root factory on every call', () {
      var calls = 0;
      final counting = RootGuard(() {
        calls++;
        return Routes.home;
      });
      expect(
        counting(controller, <NavigationRoute>[]),
        equals(<NavigationRoute>[Routes.home]),
      );
      expect(
        counting(controller, <NavigationRoute>[Routes.home]),
        equals(<NavigationRoute>[Routes.home]),
      );
      expect(calls, equals(2));
    });

    test('does not modify the received stack and returns a growable one', () {
      final stack = <NavigationRoute>[Routes.catalog, Routes.home];
      final result = guard(controller, stack);
      expect(stack, equals(<NavigationRoute>[Routes.catalog, Routes.home]));
      expect(() => result.add(Routes.settings), returnsNormally);
    });

    test('in a controller, no change can get rid of the root', () {
      final rooted = NavigationController(
        <NavigationRoute>[Routes.catalog],
        guards: <NavigationGuard>[guard],
      );
      addTearDown(rooted.dispose);
      expect(
        rooted.stack,
        equals(<NavigationRoute>[Routes.home, Routes.catalog]),
      );

      rooted.stack = <NavigationRoute>[Routes.settings];
      expect(
        rooted.stack,
        equals(<NavigationRoute>[Routes.home, Routes.settings]),
      );

      rooted.change((stack) => stack..removeAt(0));
      expect(
        rooted.stack,
        equals(<NavigationRoute>[Routes.home, Routes.settings]),
      );

      rooted.removeWhere((_) => true);
      expect(
        rooted.stack,
        equals(<NavigationRoute>[Routes.home]),
        reason: 'an emptied stack is refilled with the root',
      );
      expect(rooted.pop(), isFalse);

      // Several copies of the root are merged by the controller.
      rooted.stack = <NavigationRoute>[
        Routes.home,
        Routes.catalog,
        Routes.home,
      ];
      expect(
        rooted.stack,
        equals(<NavigationRoute>[Routes.home, Routes.catalog]),
      );
    });
  });

  group('LimitGuard', () {
    test('rejects a limit that is not positive', () {
      for (final limit in <int>[0, -1]) {
        expect(() => LimitGuard(limit), throwsAssertionError);
      }
    });

    test('a limit of one keeps only the root', () {
      const guard = LimitGuard(1);
      expect(
        guard(controller, <NavigationRoute>[
          Routes.home,
          Routes.catalog,
          Routes.settings,
        ]),
        equals(<NavigationRoute>[Routes.home]),
      );
      final single = <NavigationRoute>[Routes.home];
      expect(guard(controller, single), same(single));
    });

    test('returns the same instance when the length equals the limit', () {
      const guard = LimitGuard(3);
      final stack = <NavigationRoute>[
        Routes.home,
        Routes.catalog,
        Routes.settings,
      ];
      expect(guard(controller, stack), same(stack));
    });

    test('drops the oldest routes above the root', () {
      const guard = LimitGuard(2);
      expect(
        guard(controller, <NavigationRoute>[
          Routes.home,
          Routes.catalog,
          Routes.settings,
          const ProductRoute(1),
        ]),
        equals(<NavigationRoute>[Routes.home, const ProductRoute(1)]),
      );
      expect(
        guard(controller, <NavigationRoute>[
          Routes.home,
          Routes.catalog,
          Routes.settings,
        ]),
        equals(<NavigationRoute>[Routes.home, Routes.settings]),
      );
    });

    test('does not modify the received stack and returns a growable one', () {
      const guard = LimitGuard(1);
      final stack = <NavigationRoute>[Routes.home, Routes.catalog];
      final result = guard(controller, stack);
      expect(stack, equals(<NavigationRoute>[Routes.home, Routes.catalog]));
      expect(() => result.add(Routes.settings), returnsNormally);
    });

    test('declared after RootGuard, the root counts against the limit', () {
      final limited = NavigationController(
        <NavigationRoute>[Routes.home],
        guards: <NavigationGuard>[
          RootGuard(() => Routes.home),
          const LimitGuard(2),
        ],
      );
      addTearDown(limited.dispose);

      limited
        ..push(Routes.catalog)
        ..push(Routes.settings);
      expect(
        limited.stack,
        equals(<NavigationRoute>[Routes.home, Routes.settings]),
      );

      limited.stack = <NavigationRoute>[
        Routes.catalog,
        Routes.settings,
        const ProductRoute(1),
      ];
      expect(
        limited.stack,
        equals(<NavigationRoute>[Routes.home, const ProductRoute(1)]),
      );
    });

    test('declared before RootGuard, the inserted root exceeds the limit', () {
      final limited = NavigationController(
        <NavigationRoute>[Routes.home],
        guards: <NavigationGuard>[
          const LimitGuard(2),
          RootGuard(() => Routes.home),
        ],
      );
      addTearDown(limited.dispose);

      limited.stack = <NavigationRoute>[
        Routes.catalog,
        Routes.settings,
        const ProductRoute(1),
      ];
      // The limit trims to [catalog, product] and only then the root is put
      // underneath: the order of the guards matters.
      expect(
        limited.stack,
        equals(<NavigationRoute>[
          Routes.home,
          Routes.catalog,
          const ProductRoute(1),
        ]),
      );
    });

    test('declared after PriorityGuard, a floating modal survives the '
        'newest screen', () {
      final limited = NavigationController(
        <NavigationRoute>[Routes.home],
        guards: <NavigationGuard>[const PriorityGuard(), const LimitGuard(2)],
      );
      addTearDown(limited.dispose);

      limited
        ..push(const ConfirmDialogRoute())
        ..push(Routes.catalog);
      // Sorted to [home, catalog, dialog], then trimmed to two routes.
      expect(
        limited.stack,
        equals(<NavigationRoute>[Routes.home, const ConfirmDialogRoute()]),
      );
    });

    test('declared before PriorityGuard, the newest screen wins over '
        'the modal', () {
      final limited = NavigationController(
        <NavigationRoute>[Routes.home],
        guards: <NavigationGuard>[const LimitGuard(2), const PriorityGuard()],
      );
      addTearDown(limited.dispose);

      limited
        ..push(const ConfirmDialogRoute())
        ..push(Routes.catalog);
      expect(
        limited.stack,
        equals(<NavigationRoute>[Routes.home, Routes.catalog]),
      );
    });
  });

  group('GateGuard', () {
    const otp = _Route('otp', tags: <String>{'unauthenticated'});
    const help = _Route('help', tags: <String>{'unauthenticated', kModalTag});
    late Flag signedIn;
    late GateGuard guard;

    setUp(() {
      signedIn = Flag();
      guard = GateGuard(
        isOpen: () => signedIn.value,
        tag: 'unauthenticated',
        closed: () => <NavigationRoute>[Routes.signIn],
        opened: () => <NavigationRoute>[Routes.home],
      );
    });

    tearDown(() => signedIn.dispose());

    test('closed: keeps every gate route in order and drops the rest', () {
      expect(
        guard(controller, <NavigationRoute>[
          Routes.home,
          Routes.signIn,
          Routes.settings,
          otp,
          help,
        ]),
        equals(<NavigationRoute>[Routes.signIn, otp, help]),
      );
    });

    test('closed: a stack made only of gate routes is the same instance', () {
      final stack = <NavigationRoute>[Routes.signIn, otp];
      expect(guard(controller, stack), same(stack));
    });

    test('closed: an empty stack is replaced by the closed stack', () {
      expect(
        guard(controller, <NavigationRoute>[]),
        equals(<NavigationRoute>[Routes.signIn]),
      );
    });

    test('closed: a fallback without the tag is returned as it is', () {
      final untagged = GateGuard(
        isOpen: () => false,
        tag: 'unauthenticated',
        closed: () => <NavigationRoute>[Routes.catalog],
        opened: () => <NavigationRoute>[Routes.home],
      );
      expect(
        untagged(controller, <NavigationRoute>[Routes.home]),
        equals(<NavigationRoute>[Routes.catalog]),
      );
      // The fallback is not a gate route itself, so it is rebuilt on every
      // pass, but the result is the same every time.
      expect(
        untagged(controller, <NavigationRoute>[Routes.catalog]),
        equals(<NavigationRoute>[Routes.catalog]),
      );

      final gated = NavigationController(
        <NavigationRoute>[Routes.home],
        guards: <NavigationGuard>[untagged],
      );
      addTearDown(gated.dispose);
      expect(gated.stack, equals(<NavigationRoute>[Routes.catalog]));

      var notifications = 0;
      gated
        ..addListener(() => notifications++)
        ..revalidate();
      expect(notifications, isZero, reason: 'a stable stack');

      gated.push(Routes.signIn);
      expect(
        gated.stack,
        equals(<NavigationRoute>[Routes.signIn]),
        reason: 'a real gate route replaces the fallback',
      );
    });

    test('open: removes the gate routes wherever they are', () {
      signedIn.value = true;
      expect(
        guard(controller, <NavigationRoute>[
          Routes.signIn,
          Routes.home,
          otp,
          Routes.settings,
          help,
        ]),
        equals(<NavigationRoute>[Routes.home, Routes.settings]),
      );
    });

    test('open: the fallback is consulted only when nothing is left', () {
      var fallbacks = 0;
      final counting = GateGuard(
        isOpen: () => true,
        tag: 'unauthenticated',
        closed: () => <NavigationRoute>[Routes.signIn],
        opened: () {
          fallbacks++;
          return <NavigationRoute>[Routes.home];
        },
      );
      expect(
        counting(controller, <NavigationRoute>[Routes.signIn, otp]),
        equals(<NavigationRoute>[Routes.home]),
      );
      expect(fallbacks, equals(1));

      expect(
        counting(controller, <NavigationRoute>[Routes.signIn, Routes.catalog]),
        equals(<NavigationRoute>[Routes.catalog]),
      );
      expect(fallbacks, equals(1));
    });

    test('open: an empty stack is replaced by the opened stack', () {
      signedIn.value = true;
      expect(
        guard(controller, <NavigationRoute>[]),
        equals(<NavigationRoute>[Routes.home]),
      );
    });

    test('a route carrying the gate tag among others follows the gate', () {
      expect(
        guard(controller, <NavigationRoute>[Routes.home, help]),
        equals(<NavigationRoute>[help]),
      );
      signedIn.value = true;
      expect(
        guard(controller, <NavigationRoute>[Routes.home, help]),
        equals(<NavigationRoute>[Routes.home]),
      );
    });

    test('flipping the gate repeatedly always lands on a consistent '
        'stack', () {
      final gated = NavigationController(
        <NavigationRoute>[Routes.home, Routes.catalog],
        guards: <NavigationGuard>[guard],
        revalidate: signedIn,
      );
      addTearDown(gated.dispose);
      var notifications = 0;
      gated.addListener(() => notifications++);
      expect(gated.stack, equals(<NavigationRoute>[Routes.signIn]));

      gated.push(Routes.settings);
      expect(
        gated.stack,
        equals(<NavigationRoute>[Routes.signIn]),
        reason: 'rejected while the gate is closed',
      );
      expect(notifications, isZero);

      gated.push(otp);
      expect(gated.stack, equals(<NavigationRoute>[Routes.signIn, otp]));
      expect(notifications, equals(1));

      signedIn.value = true;
      expect(
        gated.stack,
        equals(<NavigationRoute>[Routes.home]),
        reason: 'nothing is left: the opened fallback is used',
      );
      expect(notifications, equals(2));

      gated.push(Routes.settings);
      expect(
        gated.stack,
        equals(<NavigationRoute>[Routes.home, Routes.settings]),
      );

      signedIn.value = false;
      expect(gated.stack, equals(<NavigationRoute>[Routes.signIn]));

      signedIn.value = true;
      expect(
        gated.stack,
        equals(<NavigationRoute>[Routes.home]),
        reason: 'the stack from before the sign out is not restored',
      );

      final before = notifications;
      gated.revalidate();
      expect(
        notifications,
        equals(before),
        reason: 'an open gate over a clean stack changes nothing',
      );
    });
  });

  group('NavigationGuard', () {
    test('a callback guard forwards the controller and the stack', () {
      NavigationController? seen;
      final guard = NavigationGuard((controller, stack) {
        seen = controller;
        return stack..add(Routes.catalog);
      });
      final stack = <NavigationRoute>[Routes.home];
      expect(guard(controller, stack), same(stack));
      expect(seen, same(controller));
      expect(stack, equals(<NavigationRoute>[Routes.home, Routes.catalog]));
    });

    test('the guards describe themselves', () {
      expect(const PriorityGuard().toString(), equals('PriorityGuard()'));
      expect(RootGuard(() => Routes.home).toString(), equals('RootGuard()'));
      expect(const LimitGuard(3).toString(), equals('LimitGuard(3)'));
      expect(
        GateGuard(
          isOpen: () => true,
          tag: 'unauthenticated',
          closed: () => <NavigationRoute>[Routes.signIn],
          opened: () => <NavigationRoute>[Routes.home],
        ).toString(),
        equals('GateGuard(unauthenticated)'),
      );
      expect(
        NavigationGuard((controller, stack) => stack).toString(),
        equals('NavigationGuard()'),
      );
      expect(_PaneGuard().toString(), equals('ContextGuard()'));
    });
  });

  group('ContextGuard', () {
    test('is skipped while the controller has no context', () {
      final guard = _PaneGuard();
      final stack = <NavigationRoute>[Routes.home];
      expect(controller.context, isNull);
      expect(guard(controller, stack), same(stack));
      expect(guard.calls, isZero);
    });

    testWidgets('runs once a view is mounted and is skipped again once '
        'the view is gone', (tester) async {
      final guard = _PaneGuard();
      final guarded = NavigationController(
        <NavigationRoute>[Routes.home],
        guards: <NavigationGuard>[guard],
      );
      addTearDown(guarded.dispose);
      expect(guard.calls, isZero, reason: 'no context during the constructor');
      expect(guarded.stack, equals(<NavigationRoute>[Routes.home]));

      await tester.pumpWidget(
        MaterialApp(home: NavigationView(controller: guarded)),
      );
      expect(guard.calls, equals(1));
      expect(
        guarded.stack,
        equals(<NavigationRoute>[Routes.home, _PaneGuard.pane]),
      );
      expect(find.text('pane'), findsOneWidget);

      guarded.revalidate();
      expect(guard.calls, equals(2));

      await tester.pumpWidget(const SizedBox.shrink());
      expect(guarded.context, isNull);
      guarded.revalidate();
      expect(guard.calls, equals(2), reason: 'skipped without a context');
      expect(
        guarded.stack,
        equals(<NavigationRoute>[Routes.home, _PaneGuard.pane]),
        reason: 'a skipped guard leaves the stack as it is',
      );
    });
  });
});
