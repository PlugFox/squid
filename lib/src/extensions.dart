import 'package:flutter/widgets.dart';
import 'package:squid/src/controller.dart';
import 'package:squid/src/route.dart';
import 'package:squid/src/view.dart';

/// Shortcuts to the closest [NavigationController].
extension NavigationContextExtension on BuildContext {
  /// The controller of the closest [NavigationView] above this context.
  ///
  /// ```dart
  /// context.navigation.push(const ProductRoute(42));
  /// context.navigation.pop();
  /// context.navigation.change((stack) => <NavigationRoute>[Routes.home]);
  /// ```
  ///
  /// Throws when there is no navigator above, use [maybeNavigation]
  /// to handle that case.
  NavigationController get navigation => NavigationScope.of(this);

  /// The controller of the closest [NavigationView] above this context,
  /// or `null` when there is none.
  NavigationController? get maybeNavigation => NavigationScope.maybeOf(this);
}

/// Queries and transformations of a [NavigationStack].
///
/// All of them return a new list and never modify the receiver, so they can
/// be chained inside a guard or inside [NavigationController.change]:
///
/// ```dart
/// controller.change((stack) => stack.withoutTag(kModalTag).toList());
/// ```
extension NavigationStackExtension on NavigationStack {
  /// The visible route, or `null` when the stack is empty.
  NavigationRoute? get topOrNull => isEmpty ? null : last;

  /// Whether the stack contains a route with the given [key].
  bool containsKey(LocalKey key) => any((route) => route.key == key);

  /// Whether the stack contains a route with the given [tag].
  bool containsTag(String tag) => any((route) => route.tags.contains(tag));

  /// Whether the stack contains a route of the given type.
  bool containsType<T extends NavigationRoute>() => any((route) => route is T);

  /// The topmost route with the given [key], or `null`.
  NavigationRoute? findKey(LocalKey key) {
    for (var i = length - 1; i >= 0; i--) {
      if (this[i].key == key) return this[i];
    }
    return null;
  }

  /// The topmost route with the given [name], or `null`.
  NavigationRoute? findName(String name) {
    for (var i = length - 1; i >= 0; i--) {
      if (this[i].name == name) return this[i];
    }
    return null;
  }

  /// The topmost route of the given type, or `null`.
  ///
  /// ```dart
  /// final product = stack.findType<ProductRoute>();
  /// ```
  T? findType<T extends NavigationRoute>() {
    for (var i = length - 1; i >= 0; i--) {
      final route = this[i];
      if (route is T) return route;
    }
    return null;
  }

  /// The routes marked with [tag].
  NavigationStack whereTag(String tag) =>
      where((route) => route.tags.contains(tag)).toList(growable: true);

  /// The stack without the routes marked with [tag].
  ///
  /// The usual way to close every dialog and bottom sheet at once:
  ///
  /// ```dart
  /// controller.change((stack) => stack.withoutTag(kModalTag));
  /// ```
  NavigationStack withoutTag(String tag) =>
      where((route) => !route.tags.contains(tag)).toList(growable: true);

  /// The stack without the routes of the given type.
  NavigationStack withoutType<T extends NavigationRoute>() =>
      where((route) => route is! T).toList(growable: true);

  /// The stack without the route with the same key as [route].
  NavigationStack without(NavigationRoute route) =>
      where((other) => other.key != route.key).toList(growable: true);

  /// The stack with [route] on top, moving it there when it is already
  /// present.
  NavigationStack withRoute(NavigationRoute route) => <NavigationRoute>[
    ...where((other) => other.key != route.key),
    route,
  ];
}
