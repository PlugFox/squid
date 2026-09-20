import 'package:flutter_test/flutter_test.dart';
import 'package:squid/squid.dart';

import 'src/routes.dart';

void main() => group('guards', () {
  late NavigationController controller;

  setUp(() {
    controller = NavigationController(<NavigationRoute>[Routes.home]);
  });

  tearDown(() => controller.dispose());

  group('PriorityGuard', () {
    const guard = PriorityGuard();

    test('keeps a correctly ordered stack untouched', () {
      final stack = <NavigationRoute>[
        Routes.home,
        Routes.catalog,
        const ConfirmDialogRoute(),
      ];
      expect(identical(guard(controller, stack), stack), isTrue);
    });

    test('moves the modals above the screens', () {
      final result = guard(controller, <NavigationRoute>[
        const ConfirmDialogRoute(),
        Routes.home,
        Routes.catalog,
      ]);
      expect(
        result,
        equals(<NavigationRoute>[
          Routes.home,
          Routes.catalog,
          const ConfirmDialogRoute(),
        ]),
      );
    });

    test('is stable for the routes with an equal priority', () {
      final result = guard(controller, <NavigationRoute>[
        Routes.catalog,
        Routes.settings,
        Routes.home,
        const ProductRoute(1),
      ]);
      expect(
        result,
        equals(<NavigationRoute>[
          Routes.home,
          Routes.catalog,
          Routes.settings,
          const ProductRoute(1),
        ]),
      );
    });
  });

  group('RootGuard', () {
    final guard = RootGuard(() => Routes.home);

    test('adds the root route at the bottom', () {
      expect(
        guard(controller, <NavigationRoute>[Routes.catalog]),
        equals(<NavigationRoute>[Routes.home, Routes.catalog]),
      );
    });

    test('moves an existing root route to the bottom', () {
      expect(
        guard(controller, <NavigationRoute>[Routes.catalog, Routes.home]),
        equals(<NavigationRoute>[Routes.home, Routes.catalog]),
      );
    });

    test('refills an empty stack', () {
      expect(
        guard(controller, <NavigationRoute>[]),
        equals(<NavigationRoute>[Routes.home]),
      );
    });
  });

  group('LimitGuard', () {
    test('keeps the root and the newest routes', () {
      const guard = LimitGuard(3);
      final result = guard(controller, <NavigationRoute>[
        Routes.home,
        Routes.catalog,
        const ProductRoute(1),
        const ProductRoute(2),
        const ProductRoute(3),
      ]);
      expect(
        result,
        equals(<NavigationRoute>[
          Routes.home,
          const ProductRoute(2),
          const ProductRoute(3),
        ]),
      );
    });

    test('does nothing when the stack is short enough', () {
      const guard = LimitGuard(8);
      final stack = <NavigationRoute>[Routes.home, Routes.catalog];
      expect(identical(guard(controller, stack), stack), isTrue);
    });
  });

  group('GateGuard', () {
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

    test('closed: replaces everything with the gate', () {
      expect(
        guard(controller, <NavigationRoute>[Routes.home, Routes.settings]),
        equals(<NavigationRoute>[Routes.signIn]),
      );
    });

    test('closed: keeps the routes of the gate', () {
      final stack = <NavigationRoute>[Routes.signIn];
      expect(identical(guard(controller, stack), stack), isTrue);
    });

    test('open: removes the routes of the gate', () {
      signedIn.value = true;
      expect(
        guard(controller, <NavigationRoute>[Routes.signIn, Routes.catalog]),
        equals(<NavigationRoute>[Routes.catalog]),
      );
    });

    test('open: falls back when nothing is left', () {
      signedIn.value = true;
      expect(
        guard(controller, <NavigationRoute>[Routes.signIn]),
        equals(<NavigationRoute>[Routes.home]),
      );
    });

    test('open: does not touch a stack without the gate', () {
      signedIn.value = true;
      final stack = <NavigationRoute>[Routes.home, Routes.catalog];
      expect(identical(guard(controller, stack), stack), isTrue);
    });
  });
});
