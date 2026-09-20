import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squid/squid.dart';

import 'src/routes.dart';

void main() => group('view', () {
  Future<void> pumpView(WidgetTester tester, NavigationController controller) =>
      tester.pumpWidget(
        MaterialApp(home: NavigationView(controller: controller)),
      );

  testWidgets('renders the visible route of the stack', (tester) async {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);
    await pumpView(tester, controller);

    expect(find.text('screen:home'), findsOneWidget);

    controller.push(Routes.settings);
    await tester.pumpAndSettle();
    expect(find.text('screen:settings'), findsOneWidget);
    expect(find.text('screen:home'), findsNothing);

    controller.pop();
    await tester.pumpAndSettle();
    expect(find.text('screen:home'), findsOneWidget);
  });

  testWidgets('rewriting the whole stack works in one frame', (tester) async {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);
    await pumpView(tester, controller);

    controller.stack = <NavigationRoute>[
      Routes.catalog,
      const ProductRoute(42),
    ];
    await tester.pumpAndSettle();

    expect(find.text('product:42'), findsOneWidget);
    expect(controller.length, equals(2));
  });

  testWidgets('the state of a screen survives a change of the stack', (
    tester,
  ) async {
    final controller = NavigationController(<NavigationRoute>[
      const _CounterRoute(),
    ]);
    addTearDown(controller.dispose);
    await pumpView(tester, controller);

    await tester.tap(find.text('0'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // A new stack instance with the same route must not remount the screen.
    controller.change((stack) => <NavigationRoute>[...stack]);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('context.navigation reaches the controller', (tester) async {
    final controller = NavigationController(<NavigationRoute>[
      const _PusherRoute(),
    ]);
    addTearDown(controller.dispose);
    await pumpView(tester, controller);

    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();
    expect(find.text('screen:settings'), findsOneWidget);
    expect(controller.top, equals(Routes.settings));
  });

  testWidgets('a route closed by the navigator leaves the stack', (
    tester,
  ) async {
    final controller = NavigationController(<NavigationRoute>[
      Routes.home,
      Routes.settings,
    ]);
    addTearDown(controller.dispose);
    await pumpView(tester, controller);

    // The back button of the AppBar pops the route imperatively.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(controller.stack, equals(<NavigationRoute>[Routes.home]));
    expect(find.text('screen:home'), findsOneWidget);
  });

  testWidgets('the system back button pops the stack', (tester) async {
    final controller = NavigationController(<NavigationRoute>[
      Routes.home,
      Routes.settings,
    ]);
    addTearDown(controller.dispose);
    await pumpView(tester, controller);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(controller.stack, equals(<NavigationRoute>[Routes.home]));

    // Nothing left to pop: the press is not handled and bubbles up.
    expect(await tester.binding.handlePopRoute(), isFalse);
  });

  testWidgets('interceptBackButton disables the system back button', (
    tester,
  ) async {
    final controller = NavigationController(<NavigationRoute>[
      Routes.home,
      Routes.settings,
    ]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: NavigationView(
          controller: controller,
          interceptBackButton: false,
        ),
      ),
    );

    expect(await tester.binding.handlePopRoute(), isFalse);
    expect(controller.length, equals(2));
  });

  testWidgets('a dialog route is shown and dismissed declaratively', (
    tester,
  ) async {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);
    await pumpView(tester, controller);

    final result = controller.pushForResult<bool>(const ConfirmDialogRoute());
    await tester.pumpAndSettle();
    expect(find.text('confirm?'), findsOneWidget);
    expect(find.text('screen:home'), findsOneWidget, reason: 'still visible');

    await tester.tap(find.text('yes'));
    await tester.pumpAndSettle();

    expect(await result, isTrue);
    expect(find.text('confirm?'), findsNothing);
    expect(controller.stack, equals(<NavigationRoute>[Routes.home]));
  });

  testWidgets('a tap on the barrier removes the dialog from the stack', (
    tester,
  ) async {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);
    await pumpView(tester, controller);

    final result = controller.pushForResult<bool>(const ConfirmDialogRoute());
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(await result, isNull);
    expect(controller.stack, equals(<NavigationRoute>[Routes.home]));
  });

  testWidgets('a bottom sheet route is a part of the stack', (tester) async {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);
    await pumpView(tester, controller);

    controller.push(const FiltersSheetRoute());
    await tester.pumpAndSettle();
    expect(find.text('filters'), findsOneWidget);

    controller.removeTag(kModalTag);
    await tester.pumpAndSettle();
    expect(find.text('filters'), findsNothing);
  });

  testWidgets('a guard can close the modals on every change', (tester) async {
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      guards: <NavigationGuard>[
        // Modals never survive a change of the screen below them.
        NavigationGuard(
          (controller, stack) =>
              stack.length > 1 && stack.last is! DialogRouteMixin
              ? stack.withoutTag(kModalTag)
              : stack,
        ),
        const PriorityGuard(),
      ],
    );
    addTearDown(controller.dispose);
    await pumpView(tester, controller);

    controller.push(const ConfirmDialogRoute());
    await tester.pumpAndSettle();
    expect(find.text('confirm?'), findsOneWidget);

    controller.push(Routes.settings);
    await tester.pumpAndSettle();
    expect(find.text('confirm?'), findsNothing);
    expect(
      controller.stack,
      equals(<NavigationRoute>[Routes.home, Routes.settings]),
    );
  });

  testWidgets('a route without a transition is shown immediately', (
    tester,
  ) async {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);
    await pumpView(tester, controller);

    controller.push(const FastRoute());
    // A single frame is enough: there is no animation to settle.
    await tester.pump();
    expect(find.text('fast'), findsOneWidget);

    controller.pop();
    await tester.pump();
    expect(find.text('fast'), findsNothing);
    expect(find.text('screen:home'), findsOneWidget);
  });

  testWidgets('the view follows a swap of the controller', (tester) async {
    final first = NavigationController(<NavigationRoute>[Routes.home]);
    final second = NavigationController(<NavigationRoute>[Routes.catalog]);
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    await pumpView(tester, first);
    expect(find.text('screen:home'), findsOneWidget);

    await pumpView(tester, second);
    await tester.pumpAndSettle();
    expect(find.text('screen:catalog'), findsOneWidget);

    // The old controller no longer drives the view.
    first.push(Routes.settings);
    await tester.pumpAndSettle();
    expect(find.text('screen:catalog'), findsOneWidget);
  });

  testWidgets('onBackButtonPressed overrides the back button', (tester) async {
    final controller = NavigationController(<NavigationRoute>[
      Routes.home,
      Routes.catalog,
      Routes.settings,
    ]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: NavigationView(
          controller: controller,
          // A terminal flow that always goes home instead of revealing
          // the screen underneath.
          onBackButtonPressed: (controller) async {
            controller.stack = <NavigationRoute>[Routes.home];
            return true;
          },
        ),
      ),
    );

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(controller.stack, equals(<NavigationRoute>[Routes.home]));
    expect(find.text('screen:home'), findsOneWidget);
  });

  testWidgets('the view exposes the controller and its navigator', (
    tester,
  ) async {
    final controller = NavigationController(<NavigationRoute>[
      const _PusherRoute(),
    ]);
    addTearDown(controller.dispose);
    await pumpView(tester, controller);

    final context = tester.element(find.text('push'));
    expect(NavigationView.of(context), same(controller));
    expect(NavigationView.maybeOf(context), same(controller));
    expect(controller.context, isNotNull);
    expect(controller.navigator, isNotNull);
  });

  testWidgets('NavigationScope.stackOf rebuilds on every change', (
    tester,
  ) async {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);
    var builds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: NavigationScope(
          controller: controller,
          child: Builder(
            builder: (context) {
              builds++;
              return Text(
                NavigationScope.stackOf(
                  context,
                ).map<String>((route) => route.name).join('>'),
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('home'), findsOneWidget);
    expect(builds, equals(1));

    controller.push(Routes.catalog);
    await tester.pump();
    expect(find.text('home>catalog'), findsOneWidget);
    expect(builds, equals(2));
  });

  testWidgets('NavigationScope.of throws a readable error when absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expect(context.maybeNavigation, isNull);
            expect(() => context.navigation, throwsFlutterError);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });
});

final class _CounterRoute with NavigationRoute {
  const _CounterRoute();

  @override
  Widget build(BuildContext context) => const _CounterScreen();
}

class _CounterScreen extends StatefulWidget {
  const _CounterScreen();

  @override
  State<_CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<_CounterScreen> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => setState(() => _count++),
        child: Text('$_count'),
      ),
    ),
  );
}

final class _PusherRoute with NavigationRoute {
  const _PusherRoute();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => context.navigation.push(Routes.settings),
        child: const Text('push'),
      ),
    ),
  );
}
