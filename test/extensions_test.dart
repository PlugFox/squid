import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squid/squid.dart';

import 'src/routes.dart';

void main() => group('extensions', () {
  final stack = <NavigationRoute>[
    Routes.home,
    Routes.catalog,
    const ProductRoute(1),
    const ConfirmDialogRoute(),
  ];

  test('queries', () {
    expect(stack.topOrNull, isA<ConfirmDialogRoute>());
    expect(<NavigationRoute>[].topOrNull, isNull);

    expect(stack.containsKey(Routes.catalog.key), isTrue);
    expect(stack.containsKey(Routes.settings.key), isFalse);
    expect(stack.containsTag(kModalTag), isTrue);
    expect(stack.containsTag('unauthenticated'), isFalse);
    expect(stack.containsType<ProductRoute>(), isTrue);

    expect(stack.findKey(const ValueKey<String>('product/1')), isNotNull);
    expect(stack.findName('catalog'), equals(Routes.catalog));
    expect(stack.findType<ProductRoute>()?.id, equals(1));
    expect(stack.findName('nothing'), isNull);
  });

  test('transformations do not modify the receiver', () {
    expect(stack.whereTag(kModalTag), hasLength(1));
    expect(stack.withoutTag(kModalTag), hasLength(3));
    expect(stack.withoutType<ProductRoute>(), hasLength(3));
    expect(stack.without(Routes.home).first, equals(Routes.catalog));
    expect(stack.withRoute(Routes.catalog).last, equals(Routes.catalog));
    expect(stack.withRoute(Routes.catalog), hasLength(stack.length));
    expect(stack.withRoute(Routes.settings), hasLength(stack.length + 1));
    expect(stack, hasLength(4), reason: 'the receiver is untouched');
  });

  test('the transformations are growable lists', () {
    expect(() => stack.withoutTag(kModalTag).add(Routes.home), returnsNormally);
    expect(() => stack.whereTag(kModalTag).add(Routes.home), returnsNormally);
  });
});
