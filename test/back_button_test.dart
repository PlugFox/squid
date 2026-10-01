import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squid/squid.dart';

import 'src/routes.dart';

enum _Tab { feed, cart }

/// What the application last told the platform about the back button.
///
/// On Android with the predictive back gesture the system closes the
/// application on its own unless the framework claims the press.
class _Platform {
  bool? handlesBack;
}

void main() => group('back button', () {
  Future<_Platform> pumpApp(WidgetTester tester, Widget home) async {
    final platform = _Platform();
    await tester.pumpWidget(
      MaterialApp(
        onNavigationNotification: (notification) {
          platform.handlesBack = notification.canHandlePop;
          return true;
        },
        home: home,
      ),
    );
    await tester.pumpAndSettle();
    return platform;
  }

  /// A shell rebuilt on every change of [tabs], one view per tab.
  Widget shell(NavigationTabsController<_Tab> tabs) => ListenableBuilder(
    listenable: tabs,
    builder: (context, _) => IndexedStack(
      index: tabs.activeIndex,
      children: <Widget>[
        for (final controller in tabs.tabs.values)
          NavigationView(controller: controller),
      ],
    ),
  );

  testWidgets('a nested view is reported again when its route is on top', (
    tester,
  ) async {
    final inner = NavigationController(<NavigationRoute>[
      Routes.home,
      Routes.catalog,
    ]);
    addTearDown(inner.dispose);
    final outer = NavigationController(<NavigationRoute>[_ShellRoute(inner)]);
    addTearDown(outer.dispose);
    final platform = await pumpApp(tester, NavigationView(controller: outer));
    expect(platform.handlesBack, isTrue, reason: 'the nested view can pop');

    outer.push(Routes.settings);
    await tester.pumpAndSettle();
    expect(platform.handlesBack, isTrue);

    outer.pop();
    await tester.pumpAndSettle();
    expect(platform.handlesBack, isTrue, reason: 'the nested view is back');

    // The press goes to the nested view.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(inner.stack, equals(<NavigationRoute>[Routes.home]));
    expect(outer.length, equals(1));
    expect(platform.handlesBack, isFalse, reason: 'nothing left to pop');

    // Nothing to pop: the application may be closed.
    expect(await tester.binding.handlePopRoute(), isFalse);
  });

  testWidgets('a tab is reported with the nested view it hosts', (
    tester,
  ) async {
    final inner = NavigationController(<NavigationRoute>[
      Routes.home,
      Routes.catalog,
    ]);
    addTearDown(inner.dispose);
    final tabs = NavigationTabsController<_Tab>(
      tabs: <_Tab, NavigationController>{
        _Tab.feed: NavigationController(<NavigationRoute>[_ShellRoute(inner)]),
        _Tab.cart: NavigationController(<NavigationRoute>[Routes.catalog]),
      },
    );
    addTearDown(tabs.dispose);
    final platform = await pumpApp(tester, shell(tabs));
    expect(platform.handlesBack, isTrue);

    tabs.select(_Tab.cart);
    await tester.pumpAndSettle();
    expect(platform.handlesBack, isTrue, reason: 'returns to the feed');

    tabs.back();
    await tester.pumpAndSettle();
    expect(platform.handlesBack, isTrue, reason: 'the nested view can pop');

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(inner.stack, equals(<NavigationRoute>[Routes.home]));
    expect(tabs.active, equals(_Tab.feed));
    expect(platform.handlesBack, isFalse);

    expect(await tester.binding.handlePopRoute(), isFalse);
  });

  testWidgets('a PopScope on the root of a tab keeps the back button', (
    tester,
  ) async {
    var blocked = 0;
    final tabs = NavigationTabsController<_Tab>(
      tabs: <_Tab, NavigationController>{
        _Tab.feed: NavigationController(<NavigationRoute>[
          _GuardedRoute(() => blocked++),
        ]),
        _Tab.cart: NavigationController(<NavigationRoute>[Routes.catalog]),
      },
    );
    addTearDown(tabs.dispose);
    // The views are created once: nothing rebuilds them on a switch.
    final views = <Widget>[
      for (final controller in tabs.tabs.values)
        NavigationView(controller: controller),
    ];
    final platform = await pumpApp(
      tester,
      ListenableBuilder(
        listenable: tabs,
        builder: (context, _) =>
            IndexedStack(index: tabs.activeIndex, children: views),
      ),
    );
    expect(platform.handlesBack, isTrue, reason: 'the PopScope blocks it');

    tabs.select(_Tab.cart);
    await tester.pumpAndSettle();
    expect(platform.handlesBack, isTrue);

    tabs.back();
    await tester.pumpAndSettle();
    expect(platform.handlesBack, isTrue, reason: 'the PopScope blocks it');

    // The press is handled by the PopScope, nothing is closed.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(blocked, equals(1));
    expect(tabs.active, equals(_Tab.feed));
    expect(find.text('guarded'), findsOneWidget);
  });

  testWidgets('a disabled view does not claim the back button', (tester) async {
    final controller = NavigationController(<NavigationRoute>[
      Routes.home,
      Routes.catalog,
    ]);
    addTearDown(controller.dispose);
    final platform = await pumpApp(
      tester,
      NavigationView(controller: controller, interceptBackButton: false),
    );
    expect(platform.handlesBack, isFalse);

    expect(await tester.binding.handlePopRoute(), isFalse);
    expect(controller.length, equals(2));
  });

  testWidgets('disabling the back button is reported', (tester) async {
    final controller = NavigationController(<NavigationRoute>[
      Routes.home,
      Routes.catalog,
    ]);
    addTearDown(controller.dispose);
    final enabled = ValueNotifier<bool>(true);
    addTearDown(enabled.dispose);
    final platform = await pumpApp(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: enabled,
        builder: (context, value, _) =>
            NavigationView(controller: controller, interceptBackButton: value),
      ),
    );
    expect(platform.handlesBack, isTrue);

    enabled.value = false;
    await tester.pumpAndSettle();
    expect(platform.handlesBack, isFalse);
    expect(await tester.binding.handlePopRoute(), isFalse);

    enabled.value = true;
    await tester.pumpAndSettle();
    expect(platform.handlesBack, isTrue);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(controller.length, equals(1));
    expect(platform.handlesBack, isFalse);
  });

  testWidgets('hand-made tabs disabled with interceptBackButton', (
    tester,
  ) async {
    final first = NavigationController(<NavigationRoute>[
      Routes.home,
      Routes.catalog,
    ]);
    addTearDown(first.dispose);
    final second = NavigationController(<NavigationRoute>[Routes.settings]);
    addTearDown(second.dispose);
    final index = ValueNotifier<int>(0);
    addTearDown(index.dispose);
    final platform = await pumpApp(
      tester,
      ValueListenableBuilder<int>(
        valueListenable: index,
        builder: (context, value, _) => IndexedStack(
          index: value,
          children: <Widget>[
            NavigationView(controller: first, interceptBackButton: value == 0),
            NavigationView(controller: second, interceptBackButton: value == 1),
          ],
        ),
      ),
    );
    expect(platform.handlesBack, isTrue);

    index.value = 1;
    await tester.pumpAndSettle();
    expect(platform.handlesBack, isFalse, reason: 'a single visible route');
    expect(await tester.binding.handlePopRoute(), isFalse);
    expect(first.length, equals(2), reason: 'the hidden tab is untouched');

    index.value = 0;
    await tester.pumpAndSettle();
    expect(platform.handlesBack, isTrue);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(first.length, equals(1));
    expect(platform.handlesBack, isFalse);
  });

  testWidgets('disposing the tabs drops the claim of the previous tab', (
    tester,
  ) async {
    final feed = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(feed.dispose);
    final cart = NavigationController(<NavigationRoute>[Routes.catalog]);
    addTearDown(cart.dispose);
    final tabs = NavigationTabsController<_Tab>(
      tabs: <_Tab, NavigationController>{_Tab.feed: feed, _Tab.cart: cart},
      disposeTabs: false,
    );
    final platform = await pumpApp(tester, NavigationView(controller: cart));
    expect(platform.handlesBack, isFalse, reason: 'an inactive tab is silent');

    tabs.select(_Tab.cart);
    await tester.pumpAndSettle();
    expect(platform.handlesBack, isTrue, reason: 'returns to the feed');

    tabs.dispose();
    await tester.pumpAndSettle();
    expect(platform.handlesBack, isFalse, reason: 'no tabs to return to');
    expect(await tester.binding.handlePopRoute(), isFalse);
  });

  testWidgets('tabs created around a mounted view are reported', (
    tester,
  ) async {
    final feed = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(feed.dispose);
    final cart = NavigationController(<NavigationRoute>[
      Routes.catalog,
      Routes.settings,
    ]);
    addTearDown(cart.dispose);
    final platform = await pumpApp(tester, NavigationView(controller: cart));
    expect(platform.handlesBack, isTrue);

    final tabs = NavigationTabsController<_Tab>(
      tabs: <_Tab, NavigationController>{_Tab.feed: feed, _Tab.cart: cart},
      disposeTabs: false,
    );
    await tester.pumpAndSettle();
    expect(platform.handlesBack, isFalse, reason: 'an inactive tab');
    expect(await tester.binding.handlePopRoute(), isFalse);
    expect(cart.length, equals(2));

    tabs.dispose();
    await tester.pumpAndSettle();
    expect(platform.handlesBack, isTrue, reason: 'out of the tabs again');
  });

  testWidgets('a guard reading the context does not rebuild the pages', (
    tester,
  ) async {
    var builds = 0;
    final controller = NavigationController(
      <NavigationRoute>[_CountedRoute(() => builds++)],
      guards: <NavigationGuard>[const _SizeGuard()],
    );
    addTearDown(controller.dispose);
    final width = ValueNotifier<double>(400);
    addTearDown(width.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<double>(
          valueListenable: width,
          builder: (context, value, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: Size(value, 600)),
            child: child!,
          ),
          child: NavigationView(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initial = builds;
    expect(initial, isPositive);

    width.value = 300;
    await tester.pumpAndSettle();
    width.value = 200;
    await tester.pumpAndSettle();
    expect(builds, equals(initial), reason: 'the routes have not changed');
    expect(find.text('counted'), findsOneWidget);
  });
});

final class _ShellRoute with NavigationRoute {
  const _ShellRoute(this.controller);

  final NavigationController controller;

  @override
  String get name => 'shell';

  @override
  Widget build(BuildContext context) => NavigationView(controller: controller);
}

final class _GuardedRoute with NavigationRoute {
  const _GuardedRoute(this.onBlocked);

  final VoidCallback onBlocked;

  @override
  String get name => 'guarded';

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) onBlocked();
    },
    child: const Text('guarded'),
  );
}

final class _CountedRoute with NavigationRoute {
  const _CountedRoute(this.onPage);

  final VoidCallback onPage;

  @override
  String get name => 'counted';

  @override
  Page<Object?> page(BuildContext context) {
    onPage();
    return MaterialPage<Object?>(key: key, name: name, child: build(context));
  }

  @override
  Widget build(BuildContext context) => const Text('counted');
}

/// Subscribes the view to the size of the window, keeps the stack.
class _SizeGuard extends ContextGuard {
  const _SizeGuard();

  @override
  NavigationStack guard(BuildContext context, NavigationStack stack) {
    MediaQuery.sizeOf(context);
    return stack;
  }
}
