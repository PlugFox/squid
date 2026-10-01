import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squid/squid.dart';

import 'src/routes.dart';

/// Enum routes carrying untyped arguments.
enum _Pages with NavigationRoute {
  list,
  detail;

  @override
  Map<String, Object?> get arguments => switch (this) {
    _Pages.list => const <String, Object?>{},
    _Pages.detail => const <String, Object?>{'id': 7, 'tab': 'reviews'},
  };

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Another enum with a value named like one of [Routes].
enum _Other with NavigationRoute {
  home;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A class route with the arguments given from the outside.
final class _ArgumentsRoute with NavigationRoute {
  const _ArgumentsRoute(this.arguments);

  @override
  final Map<String, Object?> arguments;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A route with the name and the arguments given from the outside.
final class _NamedRoute with NavigationRoute {
  const _NamedRoute(this.name, [this.arguments = const <String, Object?>{}]);

  @override
  final String name;

  @override
  final Map<String, Object?> arguments;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A generic route: its runtime type includes the type argument.
final class _Generic<T> with NavigationRoute {
  const _Generic();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A route whose identity is [id], while [label] may differ between two
/// instances: tells "the same key" from "the same object".
final class _LabeledRoute with NavigationRoute {
  const _LabeledRoute(this.id, this.label);

  final String id;

  final String label;

  @override
  String get name => 'labeled';

  @override
  LocalKey get key => ValueKey<String>('labeled/$id');

  @override
  Widget build(BuildContext context) => Text(label);
}

void main() => group('routes edge cases', () {
  group('route', () {
    test('an enum route builds its key from its name and arguments', () {
      expect(_Pages.list.name, equals('list'));
      expect(_Pages.list.key, equals(const ValueKey<String>('list')));
      expect(_Pages.detail.name, equals('detail'));
      expect(
        _Pages.detail.key,
        equals(const ValueKey<String>('detail?id=7&tab=reviews')),
      );
    });

    test('the separators of the arguments are escaped', () {
      const joined = _ArgumentsRoute(<String, Object?>{'q': 'a&b=c'});
      const split = _ArgumentsRoute(<String, Object?>{'q': 'a', 'b': 'c'});
      expect(
        joined.key,
        equals(const ValueKey<String>('_ArgumentsRoute?q=a%26b%3Dc')),
      );
      expect(joined.key, isNot(equals(split.key)));
      for (final (escaped, raw) in const <(String, String)>[
        ('%26', '&'),
        ('%3D', '='),
        ('%3F', '?'),
        ('%25', '%'),
      ]) {
        final percent = _ArgumentsRoute(<String, Object?>{'q': escaped});
        final separator = _ArgumentsRoute(<String, Object?>{'q': raw});
        expect(percent.key, isNot(equals(separator.key)), reason: escaped);
        final percentName = _ArgumentsRoute(<String, Object?>{escaped: 1});
        final separatorName = _ArgumentsRoute(<String, Object?>{raw: 1});
        expect(
          percentName.key,
          isNot(equals(separatorName.key)),
          reason: escaped,
        );
      }
      const nothing = _ArgumentsRoute(<String, Object?>{'id': null});
      const text = _ArgumentsRoute(<String, Object?>{'id': 'null'});
      expect(nothing.key, isNot(equals(text.key)));
    });

    test('a "?" in the name does not collide with the arguments', () {
      expect(
        const _NamedRoute('a?b', <String, Object?>{'c': 1}).key,
        isNot(equals(const _NamedRoute('a', <String, Object?>{'b?c': 1}).key)),
      );
    });

    test('a name without arguments does not collide with the arguments', () {
      expect(
        const _NamedRoute('a?b=c').key,
        isNot(equals(const _NamedRoute('a', <String, Object?>{'b': 'c'}).key)),
      );
      expect(
        const _NamedRoute('a?b').key,
        isNot(equals(const _NamedRoute('a', <String, Object?>{'b': null}).key)),
      );
    });

    test('the separators in the name do not collide with the arguments', () {
      expect(
        const _NamedRoute('a?b&c').key,
        isNot(
          equals(
            const _NamedRoute('a', <String, Object?>{'b': null, 'c': null}).key,
          ),
        ),
      );
    });

    test('the default key escapes the name and the arguments', () {
      expect(
        const _NamedRoute('catalog', <String, Object?>{'id': 1}).key,
        equals(const ValueKey<String>('catalog?id=1')),
      );
      expect(
        const _NamedRoute('a?b').key,
        equals(const ValueKey<String>('a%3Fb')),
      );
      expect(
        const _NamedRoute('a?b=c&d%', <String, Object?>{
          'k?': 'v?',
          'e': null,
        }).key,
        equals(const ValueKey<String>('a%3Fb%3Dc%26d%25?k%3F=v%3F&e')),
      );
      expect(
        const _NamedRoute('a%3Fb').key,
        isNot(equals(const _NamedRoute('a?b').key)),
      );
    });

    test('the values are compared by their string representation', () {
      // By design: the default key writes every value with toString().
      expect(
        const _ArgumentsRoute(<String, Object?>{'x': 1}).key,
        equals(const _ArgumentsRoute(<String, Object?>{'x': '1'}).key),
      );
    });

    test('the arguments are written in their declaration order', () {
      const ab = _ArgumentsRoute(<String, Object?>{'a': 1, 'b': 2});
      const ba = _ArgumentsRoute(<String, Object?>{'b': 2, 'a': 1});
      expect(ab.key, equals(const ValueKey<String>('_ArgumentsRoute?a=1&b=2')));
      expect(ba.key, equals(const ValueKey<String>('_ArgumentsRoute?b=2&a=1')));
      expect(ab.key, isNot(equals(ba.key)));
    });

    test('a null argument has no value, the others are written as strings', () {
      const route = _ArgumentsRoute(<String, Object?>{
        'id': null,
        'flag': true,
        'ids': <int>[1, 2],
      });
      expect(
        route.key,
        equals(
          const ValueKey<String>('_ArgumentsRoute?id&flag=true&ids=[1, 2]'),
        ),
      );
    });

    test('the name of a class route includes its type arguments', () {
      expect(const _Generic<int>().name, equals('_Generic<int>'));
      expect(
        const _Generic<int>().key,
        equals(const ValueKey<String>('_Generic<int>')),
      );
      expect(
        const _Generic<int>().key,
        isNot(equals(const _Generic<String>().key)),
      );
    });

    test('enum values of different types with the same name share a key', () {
      expect(_Other.home.key, equals(Routes.home.key));
      expect(_Other.home, isNot(equals(Routes.home)));

      // For the controller they are the same screen.
      final controller = NavigationController(<NavigationRoute>[Routes.home]);
      addTearDown(controller.dispose);
      controller.push(_Other.home);
      expect(controller.stack, equals(<NavigationRoute>[_Other.home]));
    });

    test('the defaults of a route are empty', () {
      const route = _Generic<int>();
      expect(route.tags, isEmpty);
      expect(route.priority, isZero);
      expect(route.arguments, isEmpty);
    });
  });

  group('extensions', () {
    final empty = <NavigationRoute>[];

    test('every query of an empty stack is negative', () {
      expect(empty.topOrNull, isNull);
      expect(empty.containsKey(Routes.home.key), isFalse);
      expect(empty.containsTag(kModalTag), isFalse);
      expect(empty.containsType<NavigationRoute>(), isFalse);
      expect(empty.findKey(Routes.home.key), isNull);
      expect(empty.findName('home'), isNull);
      expect(empty.findType<NavigationRoute>(), isNull);
    });

    test('every transformation of an empty stack is a new growable list', () {
      expect(empty.whereTag(kModalTag), isEmpty);
      expect(empty.withoutTag(kModalTag), isEmpty);
      expect(empty.withoutType<ProductRoute>(), isEmpty);
      expect(empty.without(Routes.home), isEmpty);
      expect(
        empty.withRoute(Routes.home),
        equals(<NavigationRoute>[Routes.home]),
      );

      for (final result in <NavigationStack>[
        empty.whereTag(kModalTag),
        empty.withoutTag(kModalTag),
        empty.withoutType<ProductRoute>(),
        empty.without(Routes.home),
        empty.withRoute(Routes.home),
      ]) {
        expect(result, isNot(same(empty)));
        expect(() => result.add(Routes.catalog), returnsNormally);
      }
      expect(empty, isEmpty, reason: 'the receiver is untouched');
    });

    test('the queries return the topmost match', () {
      final stack = <NavigationRoute>[
        const ProductRoute(1),
        Routes.catalog,
        const _LabeledRoute('a', 'bottom'),
        const ProductRoute(2),
        const _LabeledRoute('a', 'top'),
      ];
      expect(stack.topOrNull, same(stack.last));
      expect(stack.findType<ProductRoute>()?.id, equals(2));
      expect(stack.findName('product'), equals(const ProductRoute(2)));
      expect(
        stack.findKey(const ValueKey<String>('labeled/a')),
        isA<_LabeledRoute>().having((route) => route.label, 'label', 'top'),
      );
      expect(stack.findType<AppRoute>(), equals(const ProductRoute(2)));
      expect(stack.findType<Routes>(), equals(Routes.catalog));
      expect(stack.findType<FastRoute>(), isNull);
    });

    test('without and withRoute match by key, not by identity', () {
      const old = _LabeledRoute('a', 'old');
      const fresh = _LabeledRoute('a', 'fresh');
      final stack = <NavigationRoute>[Routes.home, old, Routes.catalog];

      expect(
        stack.without(fresh),
        equals(<NavigationRoute>[Routes.home, Routes.catalog]),
      );

      final moved = stack.withRoute(fresh);
      expect(moved, hasLength(3));
      expect(moved.last, same(fresh));
      expect(moved.contains(old), isFalse);
      expect(
        moved.sublist(0, 2),
        equals(<NavigationRoute>[Routes.home, Routes.catalog]),
      );
    });

    test('withRoute moves an existing route up and appends a new one', () {
      final stack = <NavigationRoute>[
        Routes.home,
        Routes.catalog,
        Routes.settings,
      ];
      expect(
        stack.withRoute(Routes.catalog),
        equals(<NavigationRoute>[Routes.home, Routes.settings, Routes.catalog]),
      );
      expect(
        stack.withRoute(Routes.settings),
        equals(<NavigationRoute>[Routes.home, Routes.catalog, Routes.settings]),
      );
      expect(
        stack.withRoute(const ProductRoute(1)),
        equals(<NavigationRoute>[
          Routes.home,
          Routes.catalog,
          Routes.settings,
          const ProductRoute(1),
        ]),
      );
    });

    test('the type queries respect the subtypes', () {
      final stack = <NavigationRoute>[
        Routes.home,
        const ProductRoute(1),
        const ConfirmDialogRoute(),
        const FiltersSheetRoute(),
      ];
      expect(stack.containsType<AppRoute>(), isTrue);
      expect(stack.containsType<Routes>(), isTrue);
      expect(stack.containsType<FastRoute>(), isFalse);
      expect(
        stack.withoutType<AppRoute>(),
        equals(<NavigationRoute>[Routes.home]),
      );
      expect(stack.withoutType<DialogRouteMixin>(), hasLength(3));
      expect(stack.withoutType<NavigationRoute>(), isEmpty);
      expect(stack.findType<BottomSheetRouteMixin>(), isA<FiltersSheetRoute>());
    });

    test('whereTag and withoutTag partition the stack keeping the order', () {
      final stack = <NavigationRoute>[
        Routes.home,
        const ConfirmDialogRoute(),
        Routes.catalog,
        const FiltersSheetRoute(),
      ];
      expect(
        stack.whereTag(kModalTag),
        equals(<NavigationRoute>[
          const ConfirmDialogRoute(),
          const FiltersSheetRoute(),
        ]),
      );
      expect(
        stack.withoutTag(kModalTag),
        equals(<NavigationRoute>[Routes.home, Routes.catalog]),
      );
      expect(
        stack.whereTag('dialog'),
        equals(<NavigationRoute>[const ConfirmDialogRoute()]),
      );
      expect(
        stack.whereTag('bottom_sheet'),
        equals(<NavigationRoute>[const FiltersSheetRoute()]),
      );
      expect(stack.whereTag('root'), equals(<NavigationRoute>[Routes.home]));
      expect(stack.whereTag('nothing'), isEmpty);
      expect(stack.withoutTag('nothing'), equals(stack));
      expect(stack.withoutTag('nothing'), isNot(same(stack)));
    });

    test('the transformations never modify an unmodifiable receiver', () {
      final stack = List<NavigationRoute>.unmodifiable(<NavigationRoute>[
        Routes.home,
        const ProductRoute(1),
        const ConfirmDialogRoute(),
      ]);
      expect(() => stack.add(Routes.catalog), throwsUnsupportedError);

      expect(stack.whereTag(kModalTag), hasLength(1));
      expect(stack.withoutTag(kModalTag), hasLength(2));
      expect(stack.withoutType<ProductRoute>(), hasLength(2));
      expect(stack.without(Routes.home), hasLength(2));
      expect(stack.withRoute(Routes.home), hasLength(3));
      expect(stack.withRoute(Routes.catalog), hasLength(4));
      expect(
        () => stack.withRoute(Routes.home).add(Routes.catalog),
        returnsNormally,
      );

      expect(
        stack,
        equals(<NavigationRoute>[
          Routes.home,
          const ProductRoute(1),
          const ConfirmDialogRoute(),
        ]),
      );
    });

    test('the stack of a controller is queried and transformed in place', () {
      final controller = NavigationController(<NavigationRoute>[
        Routes.home,
        const ConfirmDialogRoute(),
      ]);
      addTearDown(controller.dispose);
      expect(controller.stack.containsTag(kModalTag), isTrue);

      controller.change((stack) => stack.withoutTag(kModalTag));
      expect(controller.stack, equals(<NavigationRoute>[Routes.home]));

      // A transformation alone does not touch the controller.
      expect(
        controller.stack.withRoute(Routes.catalog),
        equals(<NavigationRoute>[Routes.home, Routes.catalog]),
      );
      expect(controller.stack, equals(<NavigationRoute>[Routes.home]));
    });
  });
});
