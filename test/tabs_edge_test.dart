import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squid/squid.dart';

import 'src/routes.dart';

enum _Tab { feed, search, cart }

/// Three tabs with a single route each, so that every test starts from a
/// known state: the feed is active and the history is empty.
NavigationTabsController<_Tab> _createTabs({
  _Tab? initial,
  bool disposeTabs = true,
}) => NavigationTabsController<_Tab>(
  tabs: <_Tab, NavigationController>{
    _Tab.feed: NavigationController(<NavigationRoute>[
      Routes.home,
    ], debugLabel: 'feed'),
    _Tab.search: NavigationController(<NavigationRoute>[
      Routes.catalog,
    ], debugLabel: 'search'),
    _Tab.cart: NavigationController(<NavigationRoute>[
      Routes.settings,
    ], debugLabel: 'cart'),
  },
  initial: initial,
  disposeTabs: disposeTabs,
);

/// Every tab in an [IndexedStack], the usual shell of a bottom bar.
Widget _shell(NavigationTabsController<_Tab> tabs) => MaterialApp(
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
);

void main() => group('tabs edge cases', () {
  test('the initial tab is selectable and must be one of the tabs', () {
    final tabs = _createTabs(initial: _Tab.cart);
    addTearDown(tabs.dispose);
    expect(tabs.active, equals(_Tab.cart));
    expect(tabs.value, equals(_Tab.cart));
    expect(tabs.activeIndex, equals(2));
    expect(tabs.history, isEmpty);
    expect(tabs.controller, same(tabs[_Tab.cart]));

    final orphan = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(orphan.dispose);
    expect(
      () => NavigationTabsController<_Tab>(
        tabs: <_Tab, NavigationController>{_Tab.feed: orphan},
        initial: _Tab.cart,
      ),
      throwsAssertionError,
    );
  });

  test('the history keeps every tab at most once, the most recent last', () {
    final tabs = _createTabs();
    addTearDown(tabs.dispose);

    tabs.select(_Tab.search);
    expect(tabs.history, equals(<_Tab>[_Tab.feed]));

    tabs.select(_Tab.cart);
    expect(tabs.history, equals(<_Tab>[_Tab.feed, _Tab.search]));

    tabs.select(_Tab.feed);
    expect(tabs.history, equals(<_Tab>[_Tab.search, _Tab.cart]));

    tabs.select(_Tab.cart);
    expect(
      tabs.history,
      equals(<_Tab>[_Tab.search, _Tab.feed]),
      reason: 'the cart left the history and the feed joined it',
    );
    expect(tabs.active, equals(_Tab.cart));

    expect(tabs.back(), isTrue);
    expect(tabs.active, equals(_Tab.feed));
    expect(tabs.history, equals(<_Tab>[_Tab.search]));

    expect(tabs.back(), isTrue);
    expect(tabs.active, equals(_Tab.search));
    expect(tabs.history, isEmpty);

    expect(tabs.back(), isFalse);
    expect(tabs.active, equals(_Tab.search));
  });

  test('back with an empty history does nothing and does not notify', () {
    final tabs = _createTabs();
    addTearDown(tabs.dispose);
    var notifications = 0;
    tabs.addListener(() => notifications++);

    expect(tabs.history, isEmpty);
    expect(tabs.back(), isFalse);
    expect(tabs.active, equals(_Tab.feed));
    expect(notifications, isZero);
  });

  test('selecting an unknown tab throws and changes nothing', () {
    final feed = NavigationController(<NavigationRoute>[Routes.home]);
    final search = NavigationController(<NavigationRoute>[Routes.catalog]);
    final tabs = NavigationTabsController<_Tab>(
      tabs: <_Tab, NavigationController>{_Tab.feed: feed, _Tab.search: search},
    );
    addTearDown(tabs.dispose);
    var notifications = 0;
    tabs
      ..addListener(() => notifications++)
      ..select(_Tab.search);

    expect(() => tabs.select(_Tab.cart), throwsArgumentError);
    expect(() => tabs.select(_Tab.cart, popToRoot: false), throwsArgumentError);
    expect(() => tabs[_Tab.cart], throwsArgumentError);
    expect(tabs.indexOf(_Tab.cart), equals(-1));

    expect(tabs.active, equals(_Tab.search));
    expect(tabs.history, equals(<_Tab>[_Tab.feed]));
    expect(notifications, equals(1));
  });

  test('selecting the active tab pops it to the root and notifies once', () {
    final tabs = _createTabs();
    addTearDown(tabs.dispose);
    tabs[_Tab.feed].pushAll(<NavigationRoute>[Routes.catalog, Routes.settings]);

    var notifications = 0;
    tabs
      ..addListener(() => notifications++)
      ..select(_Tab.feed);
    expect(tabs[_Tab.feed].stack, equals(<NavigationRoute>[Routes.home]));
    expect(notifications, equals(1), reason: 'the stack of the tab changed');
    expect(tabs.history, isEmpty);

    tabs.select(_Tab.feed);
    expect(notifications, equals(1), reason: 'already at the root');
  });

  test('selecting the active tab without popToRoot is a no-op', () {
    final tabs = _createTabs();
    addTearDown(tabs.dispose);
    tabs[_Tab.feed].push(Routes.catalog);

    var notifications = 0;
    tabs
      ..addListener(() => notifications++)
      ..select(_Tab.feed, popToRoot: false);
    expect(
      tabs[_Tab.feed].stack,
      equals(<NavigationRoute>[Routes.home, Routes.catalog]),
    );
    expect(notifications, isZero);
    expect(tabs.history, isEmpty);
  });

  test('switching to another tab never pops any stack', () {
    final tabs = _createTabs();
    addTearDown(tabs.dispose);
    tabs[_Tab.feed].push(Routes.catalog);
    tabs[_Tab.cart].push(const ProductRoute(1));

    tabs.select(_Tab.cart);
    expect(tabs[_Tab.feed].length, equals(2));
    expect(tabs[_Tab.cart].length, equals(2));

    tabs.select(_Tab.feed);
    expect(tabs[_Tab.feed].length, equals(2));
    expect(tabs[_Tab.cart].length, equals(2));
  });

  test('indexOf and activeIndex follow the declaration order', () {
    final tabs = _createTabs();
    addTearDown(tabs.dispose);
    expect(tabs.indexOf(_Tab.feed), isZero);
    expect(tabs.indexOf(_Tab.search), equals(1));
    expect(tabs.indexOf(_Tab.cart), equals(2));
    expect(tabs.activeIndex, isZero);

    tabs.select(_Tab.cart);
    expect(tabs.activeIndex, equals(2));

    expect(tabs.back(), isTrue);
    expect(tabs.activeIndex, isZero);
  });

  test('notifies once per selection and once per change of any stack', () {
    final tabs = _createTabs();
    addTearDown(tabs.dispose);
    var notifications = 0;
    tabs
      ..addListener(() => notifications++)
      ..select(_Tab.search);
    expect(notifications, equals(1));

    tabs[_Tab.cart].push(const ProductRoute(1));
    expect(notifications, equals(2), reason: 'a background tab');

    tabs[_Tab.search].push(const ProductRoute(2));
    expect(notifications, equals(3), reason: 'the active tab');

    tabs[_Tab.cart].change((stack) => stack);
    expect(notifications, equals(3), reason: 'nothing changed');

    tabs[_Tab.feed].revalidate();
    expect(notifications, equals(3), reason: 'nothing changed either');

    expect(tabs.back(), isTrue);
    expect(notifications, equals(4));
  });

  test(
    'disposeTabs false keeps the controllers alive and detaches them',
    () async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);

      final feed = NavigationController(<NavigationRoute>[Routes.home]);
      final cart = NavigationController(<NavigationRoute>[Routes.settings]);
      addTearDown(feed.dispose);
      addTearDown(cart.dispose);
      final tabs = NavigationTabsController<_Tab>(
        tabs: <_Tab, NavigationController>{_Tab.feed: feed, _Tab.cart: cart},
        disposeTabs: false,
      );
      feed.push(Routes.catalog);
      tabs.select(_Tab.cart);
      expect(await feed.maybePop(), isFalse, reason: 'an inactive member');

      tabs.dispose();
      expect(feed.isDisposed, isFalse);
      expect(cart.isDisposed, isFalse);

      // The listeners are gone: a change does not reach the disposed group.
      expect(() => cart.push(const ProductRoute(1)), returnsNormally);
      expect(errors, isEmpty);

      // The group is gone: the feed is not an inactive member any more.
      expect(await feed.maybePop(), isTrue);
      expect(feed.stack, equals(<NavigationRoute>[Routes.home]));
    },
  );

  test('a tab disposed on its own does not break the group', () {
    final tabs = _createTabs();
    tabs[_Tab.search].dispose();
    expect(tabs.dispose, returnsNormally);
    expect(tabs[_Tab.feed].isDisposed, isTrue);
  });

  test('maybePop pops the active tab first, then returns to the previous '
      'tab', () async {
    final tabs = _createTabs();
    addTearDown(tabs.dispose);
    tabs.select(_Tab.cart);
    tabs[_Tab.cart].push(const ProductRoute(1));

    expect(await tabs.maybePop(), isTrue);
    expect(tabs[_Tab.cart].stack, equals(<NavigationRoute>[Routes.settings]));
    expect(tabs.active, equals(_Tab.cart));

    expect(
      await tabs.maybePop(),
      isTrue,
      reason: 'at the root: back to the previous tab',
    );
    expect(tabs.active, equals(_Tab.feed));
    expect(tabs.history, isEmpty);

    expect(
      await tabs.maybePop(),
      isFalse,
      reason: 'nothing to pop and nowhere to go back to',
    );
    expect(tabs.active, equals(_Tab.feed));
  });

  test('maybePop of an inactive tab is refused, pop is not', () async {
    final tabs = _createTabs();
    addTearDown(tabs.dispose);
    tabs[_Tab.search].push(const ProductRoute(1));

    expect(await tabs[_Tab.search].maybePop(), isFalse);
    expect(tabs[_Tab.search].length, equals(2));
    expect(tabs.active, equals(_Tab.feed));

    expect(tabs[_Tab.search].pop(), isTrue);
    expect(tabs[_Tab.search].length, equals(1));
  });

  testWidgets('maybePop with the views in an IndexedStack', (tester) async {
    final tabs = _createTabs();
    addTearDown(tabs.dispose);
    await tester.pumpWidget(_shell(tabs));

    tabs.select(_Tab.cart);
    tabs[_Tab.cart].push(const ProductRoute(1));
    await tester.pumpAndSettle();
    expect(find.text('product:1'), findsOneWidget);

    expect(await tabs.maybePop(), isTrue);
    await tester.pumpAndSettle();
    expect(tabs[_Tab.cart].stack, equals(<NavigationRoute>[Routes.settings]));
    expect(tabs.active, equals(_Tab.cart));
    expect(find.text('screen:settings'), findsOneWidget);

    expect(await tabs.maybePop(), isTrue);
    await tester.pumpAndSettle();
    expect(tabs.active, equals(_Tab.feed));
    expect(find.text('screen:home'), findsOneWidget);
    expect(tabs[_Tab.cart].length, equals(1), reason: 'untouched');

    expect(await tabs.maybePop(), isFalse);
    expect(tabs.active, equals(_Tab.feed));
  });

  testWidgets('selecting the active tab pops its view to the root', (
    tester,
  ) async {
    final tabs = _createTabs();
    addTearDown(tabs.dispose);
    await tester.pumpWidget(_shell(tabs));

    tabs[_Tab.feed].pushAll(<NavigationRoute>[
      Routes.catalog,
      const ProductRoute(3),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('product:3'), findsOneWidget);

    tabs.select(_Tab.feed);
    await tester.pumpAndSettle();
    expect(find.text('product:3'), findsNothing);
    expect(find.text('screen:home'), findsOneWidget);
  });

  test('toString names the active tab', () {
    final tabs = _createTabs();
    addTearDown(tabs.dispose);
    expect(tabs.toString(), equals('NavigationTabsController(_Tab.feed)'));

    tabs.select(_Tab.cart);
    expect(tabs.toString(), equals('NavigationTabsController(_Tab.cart)'));
  });

  test('the tabs and the history are read only copies', () {
    final feed = NavigationController(<NavigationRoute>[Routes.home]);
    final search = NavigationController(<NavigationRoute>[Routes.catalog]);
    addTearDown(feed.dispose);
    addTearDown(search.dispose);

    final source = <_Tab, NavigationController>{_Tab.feed: feed};
    final tabs = NavigationTabsController<_Tab>(
      tabs: source,
      disposeTabs: false,
    );
    addTearDown(tabs.dispose);

    source[_Tab.search] = search;
    expect(
      tabs.tabs.keys,
      equals(<_Tab>[_Tab.feed]),
      reason: 'the map is copied',
    );
    expect(() => tabs.tabs[_Tab.search] = search, throwsUnsupportedError);
    expect(() => tabs.history.add(_Tab.feed), throwsUnsupportedError);
  });
});
