import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squid/squid.dart';

import 'src/routes.dart';

enum _Tab { feed, cart }

void main() => group('tabs', () {
  late NavigationTabsController<_Tab> tabs;

  setUp(() {
    tabs = NavigationTabsController<_Tab>(
      tabs: <_Tab, NavigationController>{
        _Tab.feed: NavigationController(<NavigationRoute>[
          Routes.home,
        ], debugLabel: 'feed'),
        _Tab.cart: NavigationController(<NavigationRoute>[
          Routes.catalog,
        ], debugLabel: 'cart'),
      },
    );
  });

  tearDown(() => tabs.dispose());

  test('the first tab is selected by default', () {
    expect(tabs.active, equals(_Tab.feed));
    expect(tabs.activeIndex, isZero);
    expect(tabs.controller, same(tabs[_Tab.feed]));
  });

  test('selecting a tab notifies the listeners', () {
    var notifications = 0;
    tabs
      ..addListener(() => notifications++)
      ..select(_Tab.cart);
    expect(tabs.active, equals(_Tab.cart));
    expect(notifications, equals(1));

    tabs.select(_Tab.cart);
    expect(notifications, equals(1), reason: 'the same tab');
  });

  test('a change of any stack notifies the listeners of the tabs', () {
    var notifications = 0;
    tabs.addListener(() => notifications++);

    tabs[_Tab.feed].push(Routes.settings);
    expect(notifications, equals(1), reason: 'the active tab');

    tabs[_Tab.cart].push(Routes.settings);
    expect(notifications, equals(2), reason: 'a background tab');
  });

  test('selecting the active tab pops its stack to the root', () {
    tabs[_Tab.feed].push(Routes.settings);
    expect(tabs[_Tab.feed].length, equals(2));

    tabs.select(_Tab.feed);
    expect(tabs[_Tab.feed].stack, equals(<NavigationRoute>[Routes.home]));
  });

  test('one tab can rewrite the stack of another one', () {
    tabs[_Tab.cart].push(const ProductRoute(1));
    tabs.select(_Tab.cart);

    expect(tabs.controller.top, equals(const ProductRoute(1)));
    expect(tabs[_Tab.feed].stack, equals(<NavigationRoute>[Routes.home]));
  });

  test('the tab selection history drives the back navigation', () {
    tabs
      ..select(_Tab.cart)
      ..select(_Tab.feed);
    // Every tab appears at most once, so the history cannot grow forever
    // and the back navigation always terminates.
    expect(tabs.history, equals(<_Tab>[_Tab.cart]));

    expect(tabs.back(), isTrue);
    expect(tabs.active, equals(_Tab.cart));
    expect(tabs.back(), isFalse);
    expect(tabs.active, equals(_Tab.cart));
  });

  test('an unknown tab is rejected', () {
    final single = NavigationTabsController<_Tab>(
      tabs: <_Tab, NavigationController>{
        _Tab.feed: NavigationController(<NavigationRoute>[Routes.home]),
      },
    );
    addTearDown(single.dispose);

    expect(() => single[_Tab.cart], throwsArgumentError);
    expect(() => single.select(_Tab.cart), throwsArgumentError);
    expect(
      () =>
          NavigationTabsController<_Tab>(tabs: <_Tab, NavigationController>{}),
      throwsA(isA<AssertionError>()),
    );
  });

  test('dispose releases the controllers of the tabs', () {
    final controller = tabs[_Tab.feed];
    tabs.dispose();
    expect(controller.isDisposed, isTrue);

    // A second dispose in tearDown must not throw.
    tabs = NavigationTabsController<_Tab>(
      tabs: <_Tab, NavigationController>{
        _Tab.feed: NavigationController(<NavigationRoute>[Routes.home]),
      },
    );
  });

  testWidgets('only the active tab reacts to the system back button', (
    tester,
  ) async {
    tabs[_Tab.feed].push(Routes.settings);
    tabs[_Tab.cart].push(const ProductRoute(1));

    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: tabs,
          builder: (context, _) => IndexedStack(
            index: tabs.activeIndex,
            children: <Widget>[
              for (final controller in tabs.tabs.values)
                NavigationView(controller: controller),
            ],
          ),
        ),
      ),
    );

    // The feed tab is active: the press pops its stack.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(tabs[_Tab.feed].length, equals(1));
    expect(tabs[_Tab.cart].length, equals(2), reason: 'untouched');

    // Nothing left to pop and no previous tab: the press bubbles up.
    expect(await tester.binding.handlePopRoute(), isFalse);

    // After switching, the back button returns to the previous tab.
    tabs.select(_Tab.cart);
    await tester.pumpAndSettle();

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(tabs[_Tab.cart].length, equals(1), reason: 'the cart pops first');

    expect(await tester.binding.handlePopRoute(), isTrue);
    expect(tabs.active, equals(_Tab.feed), reason: 'back to the previous tab');
  });

  testWidgets('switching tabs keeps the stack of every tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: tabs,
          builder: (context, _) => IndexedStack(
            index: tabs.activeIndex,
            children: <Widget>[
              for (final controller in tabs.tabs.values)
                NavigationView(controller: controller),
            ],
          ),
        ),
      ),
    );

    tabs[_Tab.cart].push(const ProductRoute(7));
    tabs.select(_Tab.cart);
    await tester.pumpAndSettle();
    expect(find.text('product:7'), findsOneWidget);

    tabs.select(_Tab.feed);
    await tester.pumpAndSettle();
    expect(find.text('screen:home'), findsOneWidget);

    tabs.select(_Tab.cart, popToRoot: false);
    await tester.pumpAndSettle();
    expect(find.text('product:7'), findsOneWidget, reason: 'stack survived');
  });

  testWidgets('tabs nested into a route of an outer view', (tester) async {
    tabs[_Tab.feed].push(Routes.settings);
    final root = NavigationController(<NavigationRoute>[
      _ShellRoute(tabs),
      const ProductRoute(1),
    ], debugLabel: 'root');
    addTearDown(root.dispose);
    await tester.pumpWidget(
      MaterialApp(home: NavigationView(controller: root)),
    );
    await tester.pumpAndSettle();

    // The shell is covered: the outer route is closed first.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(root.length, equals(1));
    expect(tabs[_Tab.feed].length, equals(2), reason: 'untouched');

    // Then the active tab goes back.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(tabs[_Tab.feed].length, equals(1));

    // Then the previous tab is restored.
    tabs.select(_Tab.cart);
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), isTrue);
    expect(tabs.active, equals(_Tab.feed));

    // Nothing is left anywhere: the press bubbles up.
    expect(await tester.binding.handlePopRoute(), isFalse);
  });
});

final class _ShellRoute with NavigationRoute {
  const _ShellRoute(this.tabs);

  final NavigationTabsController<_Tab> tabs;

  @override
  LocalKey get key => const ValueKey<String>('shell');

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: tabs,
    builder: (context, _) => IndexedStack(
      index: tabs.activeIndex,
      children: <Widget>[
        for (final controller in tabs.tabs.values)
          NavigationView(controller: controller),
      ],
    ),
  );
}
