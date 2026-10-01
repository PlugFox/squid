import 'package:flutter/material.dart';
import 'package:squid/squid.dart';

/// Navigation shortcuts of the application: `context.nav.push(...)`.
///
/// Squid itself only adds `context.navigation`, the raw controller. An
/// application usually wants its own vocabulary on top of it — and an
/// extension type is the cheapest way to get one: it is a zero cost wrapper
/// around the [BuildContext], it does not pollute the namespace of the
/// [BuildContext] with dozens of methods, and it can grow application
/// specific helpers such as [popModals].
extension type AppNavigation(BuildContext _context) {
  /// The controller of the closest navigator.
  NavigationController get controller => _context.navigation;

  /// The current stack of the closest navigator.
  NavigationStack get stack => controller.stack;

  /// Rewrites the stack, see [NavigationController.change].
  void change(NavigationChange fn) => controller.change(fn);

  /// Pushes [route] on top of the stack.
  void push(NavigationRoute route) => controller.push(route);

  /// Pushes [route] and waits for its result.
  Future<T?> pushForResult<T extends Object?>(NavigationRoute route) =>
      controller.pushForResult<T>(route);

  /// Closes the visible route.
  bool pop([Object? result]) => controller.pop(result);

  /// Replaces the whole stack.
  void set(NavigationStack stack) => controller.stack = stack;

  /// Closes every popup at once, whatever opened it.
  ///
  /// * the declarative dialogs and sheets — the routes tagged with
  ///   [kModalTag];
  /// * the imperative ones — `showDialog`, `showModalBottomSheet`,
  ///   `showMenu`, a dropdown — opened on top of the stack or on the root
  ///   navigator of the application;
  /// * the context menu of a text field.
  void popModals() {
    final controller = _context.maybeNavigation;
    controller?.removeTag(kModalTag);
    final navigators = <NavigatorState>{
      ?controller?.navigator,
      ?Navigator.maybeOf(_context, rootNavigator: true),
    };
    for (final navigator in navigators) {
      // The page based popups belong to the controller and are already
      // gone from its stack: only the imperative ones are popped here.
      navigator.popUntil(
        (route) => route is! PopupRoute || route.settings is Page,
      );
    }
    ContextMenuController.removeAny();
  }
}

/// Entry point of [AppNavigation].
extension AppNavigationContext on BuildContext {
  /// Navigation shortcuts of the application.
  ///
  /// ```dart
  /// context.nav.push(const ProductRoute(42));
  /// context.nav.change((stack) => stack.withoutType<ProductRoute>());
  /// context.nav.popModals();
  /// ```
  AppNavigation get nav => AppNavigation(this);
}
