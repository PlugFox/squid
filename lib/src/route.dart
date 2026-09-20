import 'package:flutter/material.dart';

/// The whole navigation state: an ordered list of routes,
/// from the bottom of the stack to the top.
///
/// This is a plain [List], so any operation you already know works here:
/// `[...stack, route]`, `stack.where(...)`, `stack.sublist(...)` and so on.
///
/// {@template squid.stack}
/// The last element is the visible one, the first element is the root of
/// the navigation. An empty stack is not allowed and will be rejected
/// by the [NavigationController].
/// {@endtemplate}
typedef NavigationStack = List<NavigationRoute>;

/// {@template squid.route}
/// A single entry of the [NavigationStack].
///
/// A route is an immutable value object that describes **what** should be
/// shown, not **how** it was opened. Mix it into an `enum` when routes have
/// no parameters, or into a `sealed class` hierarchy when they do:
///
/// ```dart
/// enum Routes with NavigationRoute {
///   home,
///   settings;
///
///   @override
///   Widget build(BuildContext context) => switch (this) {
///         Routes.home => const HomeScreen(),
///         Routes.settings => const SettingsScreen(),
///       };
/// }
/// ```
///
/// ```dart
/// sealed class AppRoute with NavigationRoute {
///   const AppRoute();
/// }
///
/// final class ProductRoute extends AppRoute {
///   const ProductRoute(this.id);
///
///   final int id;
///
///   @override
///   String get name => 'product';
///
///   @override
///   LocalKey get key => ValueKey<String>('product/$id');
///
///   @override
///   Widget build(BuildContext context) => ProductScreen(id: id);
/// }
/// ```
/// {@endtemplate}
@immutable
mixin NavigationRoute {
  /// Human readable name of the route, e.g. `product`.
  ///
  /// Used for debugging, analytics and as a part of the default [key].
  /// Defaults to the enum value name for enums and to the runtime type
  /// for classes.
  String get name => switch (this) {
    Enum e => e.name,
    _ => runtimeType.toString(),
  };

  /// Identity of this route inside the stack.
  ///
  /// Two routes with the same [key] are the same screen: Flutter reuses the
  /// underlying [Route] object and keeps its state instead of recreating it.
  /// Keys must be unique within a single stack.
  ///
  /// The default value is built from [name] and [arguments], which is enough
  /// for enums and for parameterless routes. **Routes that carry their
  /// parameters as fields must override this getter**, otherwise all of them
  /// will collide:
  ///
  /// ```dart
  /// @override
  /// LocalKey get key => ValueKey<String>('product/$id');
  /// ```
  LocalKey get key {
    final args = arguments;
    if (args.isEmpty) return ValueKey<String>(name);
    final buffer = StringBuffer(name)..write('?');
    var first = true;
    for (final entry in args.entries) {
      if (first) {
        first = false;
      } else {
        buffer.write('&');
      }
      buffer
        ..write(entry.key)
        ..write('=')
        ..write(entry.value);
    }
    return ValueKey<String>(buffer.toString());
  }

  /// Arbitrary marks used to address groups of routes declaratively.
  ///
  /// Tags are the cheapest way to write a guard or a bulk operation without
  /// knowing the concrete types: remove every `modal`, forbid everything
  /// tagged `authenticated`, count `paywall` screens and so on.
  ///
  /// ```dart
  /// controller.change((stack) =>
  ///     stack.where((route) => !route.tags.contains('modal')).toList());
  /// ```
  Set<String> get tags => const <String>{};

  /// Ordering hint for the [PriorityGuard].
  ///
  /// Routes with a lower priority are kept closer to the bottom of the stack.
  /// Use a negative value for the root screens (they should never be covered
  /// by anything) and a positive one for dialogs and bottom sheets
  /// (they should always float on top).
  ///
  /// Has no effect unless [PriorityGuard] is added to the controller.
  int get priority => 0;

  /// Optional untyped parameters of the route.
  ///
  /// Mostly useful for enum based routes, for analytics and for debugging.
  /// Classes are free to keep their parameters as typed fields instead and
  /// leave this map empty.
  Map<String, Object?> get arguments => const <String, Object?>{};

  /// Builds the content of this route.
  ///
  /// Called lazily, with a [BuildContext] located **inside** the created
  /// [Route], so [ModalRoute.of], [Navigator.of] and inherited widgets of
  /// the navigator work as expected.
  Widget build(BuildContext context);

  /// Builds the [Page] for this route.
  ///
  /// Override it to change the transition, to open the route as a dialog or
  /// as a bottom sheet, or to return any other [Page] implementation:
  ///
  /// ```dart
  /// @override
  /// Page<Object?> page(BuildContext context) => MaterialPage<Object?>(
  ///       key: key,
  ///       name: name,
  ///       fullscreenDialog: true,
  ///       child: Builder(builder: build),
  ///     );
  /// ```
  ///
  /// See also [DialogRouteMixin] and [BottomSheetRouteMixin], which do exactly
  /// that for the two most common cases.
  Page<Object?> page(BuildContext context) => MaterialPage<Object?>(
    key: key,
    name: name,
    arguments: arguments,
    child: Builder(builder: build),
  );
}
