import 'package:example/src/app.dart';
import 'package:example/src/authentication.dart';
import 'package:example/src/deep_links.dart';
import 'package:example/src/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squid/squid.dart';

void main() => group('deep links', () {
  setUp(Authentication.instance.signOut);
  tearDown(Authentication.instance.signOut);

  // The three parsers agree on every link they all understand.
  final parsers = <String, DeepLink? Function(Uri uri)>{
    'switch': parseDeepLinkWithSwitch,
    'table': parseDeepLinkWithTable,
    'segments': parseDeepLinkBySegments,
  };
  final links = <String, DeepLink?>{
    '/': (tab: AppTab.shop, stack: <NavigationRoute>[]),
    '/cart': (tab: AppTab.cart, stack: <NavigationRoute>[]),
    '/account/settings': (
      tab: AppTab.account,
      stack: <NavigationRoute>[Routes.settings],
    ),
    'https://squid.example/shop/filters?utm_source=mail': (
      tab: AppTab.shop,
      stack: <NavigationRoute>[const FiltersRoute()],
    ),
    'squid://app/unknown': null,
  };

  for (final MapEntry(key: name, value: parse) in parsers.entries) {
    test('$name: the common links', () {
      for (final MapEntry(key: link, value: expected) in links.entries) {
        final actual = parse(Uri.parse(link));
        expect(actual?.tab, equals(expected?.tab), reason: link);
        expect(
          _keys(actual?.stack),
          equals(_keys(expected?.stack)),
          reason: link,
        );
      }
    });
  }

  test('switch and table: a product link', () {
    for (final parse in <DeepLink? Function(Uri)>[
      parseDeepLinkWithSwitch,
      parseDeepLinkWithTable,
    ]) {
      final link = parse(Uri.parse('/shop/product/7'))!;
      expect(link.tab, equals(AppTab.shop));
      expect(
        _keys(link.stack),
        equals(_keys(<NavigationRoute>[const ProductRoute(7)])),
      );
      expect(parse(Uri.parse('/shop/product/seven')), isNull);
    }
  });

  test('segments: any combination of the screens', () {
    final link = parseDeepLinkBySegments(
      Uri.parse('/shop/product-3/oops/product-4/filters'),
    )!;
    expect(link.tab, equals(AppTab.shop));
    expect(
      _keys(link.stack),
      equals(
        _keys(<NavigationRoute>[
          const ProductRoute(3),
          const ProductRoute(4),
          const FiltersRoute(),
        ]),
      ),
      reason: 'the unknown segment is skipped',
    );
  });

  testWidgets('the application opens the link it was launched with', (
    tester,
  ) async {
    Authentication.instance.signIn();
    tester.platformDispatcher.defaultRouteNameTestValue = '/shop/product/5';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
    expect(find.text('Product #5'), findsWidgets);

    // The root of the tab is underneath: going back leads to the catalog.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Catalog'), findsOneWidget);
  });

  testWidgets('a link received while running switches the tab', (tester) async {
    Authentication.instance.signIn();
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
    expect(find.text('Catalog'), findsOneWidget);

    expect(await tester.binding.handlePushRoute('/account/settings'), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Nothing to configure yet'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      equals(2),
    );
  });

  testWidgets('a signed out user stays behind the gate', (tester) async {
    tester.platformDispatcher.defaultRouteNameTestValue = '/shop/product/5';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
    expect(find.text('You are signed out'), findsOneWidget);
    expect(find.text('Product #5'), findsNothing);
  });
});

/// The routes with parameters are compared by their keys.
List<LocalKey>? _keys(NavigationStack? stack) =>
    stack?.map((route) => route.key).toList();
