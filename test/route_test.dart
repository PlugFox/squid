import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squid/squid.dart';

import 'src/routes.dart';

void main() => group('route', () {
  test('enum routes have a name and a key out of the box', () {
    expect(Routes.home.name, equals('home'));
    expect(Routes.home.key, equals(const ValueKey<String>('home')));
    expect(Routes.settings.key, isNot(equals(Routes.home.key)));
  });

  test('class routes derive the name from the runtime type', () {
    expect(const FastRoute().name, equals('FastRoute'));
  });

  test('the default key includes the arguments', () {
    expect(
      const _ArgumentsRoute(<String, Object?>{'id': 1}).key,
      equals(const ValueKey<String>('_ArgumentsRoute?id=1')),
    );
    expect(
      const _ArgumentsRoute(<String, Object?>{'id': 1}).key,
      isNot(equals(const _ArgumentsRoute(<String, Object?>{'id': 2}).key)),
    );
  });

  test('routes with parameters are distinguished by the overridden key', () {
    expect(const ProductRoute(1).key, isNot(equals(const ProductRoute(2).key)));
    expect(const ProductRoute(1).key, equals(const ProductRoute(1).key));
  });

  testWidgets('the default page is a material page with the route key', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final page = const ProductRoute(7).page(ctx);
    expect(page, isA<MaterialPage<Object?>>());
    expect(page.key, equals(const ValueKey<String>('product/7')));
    expect(page.name, equals('product'));
    expect(page.arguments, equals(<String, Object?>{'id': 7}));
  });

  testWidgets('mixins replace the page of the route', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(const ConfirmDialogRoute().page(ctx), isA<DialogPage<Object?>>());
    expect(
      const FiltersSheetRoute().page(ctx),
      isA<BottomSheetPage<Object?>>(),
    );
    expect(const FastRoute().page(ctx), isA<NoTransitionPage<Object?>>());
  });

  test('modal mixins tag and prioritize the route', () {
    expect(const ConfirmDialogRoute().tags, contains(kModalTag));
    expect(const FiltersSheetRoute().tags, contains(kModalTag));
    expect(const ConfirmDialogRoute().priority, greaterThan(0));
  });
});

final class _ArgumentsRoute with NavigationRoute {
  const _ArgumentsRoute(this.arguments);

  @override
  final Map<String, Object?> arguments;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
