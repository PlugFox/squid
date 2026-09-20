import 'package:flutter/foundation.dart';
import 'package:squid/src/controller.dart';
import 'package:squid/src/route.dart';

/// {@template squid.observer}
/// A listener of the committed changes of the navigation stack.
///
/// Unlike a guard, an observer cannot change anything: it is called after the
/// new stack has been accepted and is meant for the side effects — analytics,
/// logging, the title of the application window and so on.
///
/// ```dart
/// class AnalyticsObserver with NavigationObserver {
///   AnalyticsObserver(this._analytics);
///
///   final Analytics _analytics;
///
///   @override
///   void onAdd(NavigationController controller, NavigationRoute route) =>
///       _analytics.logScreenView(route.name);
/// }
/// ```
/// {@endtemplate}
abstract mixin class NavigationObserver {
  /// Called after every committed change of the stack.
  void onChange(
    NavigationController controller,
    NavigationStack previous,
    NavigationStack next,
  ) {}

  /// Called for every route that appeared in the stack.
  void onAdd(NavigationController controller, NavigationRoute route) {}

  /// Called for every route that left the stack.
  void onRemove(NavigationController controller, NavigationRoute route) {}
}

/// {@template squid.logger}
/// An observer that prints every change of the navigation stack.
///
/// ```dart
/// NavigationController(
///   <NavigationRoute>[Routes.home],
///   observers: <NavigationObserver>[
///     if (kDebugMode) const NavigationLogger(),
///   ],
/// );
/// ```
/// {@endtemplate}
class NavigationLogger with NavigationObserver {
  /// {@macro squid.logger}
  const NavigationLogger({this.prefix = 'squid'});

  /// Prefix of every printed line.
  final String prefix;

  @override
  void onChange(
    NavigationController controller,
    NavigationStack previous,
    NavigationStack next,
  ) {
    final label = controller.debugLabel;
    debugPrint(
      '[$prefix]${label == null ? '' : '[$label]'} '
      '${next.map<String>((route) => route.name).join(' > ')}',
    );
  }
}
