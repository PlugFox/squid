import 'package:squid/src/controller.dart';
import 'package:squid/src/guard.dart';
import 'package:squid/src/route.dart';

/// {@template squid.priority_guard}
/// Keeps the stack sorted by [NavigationRoute.priority].
///
/// Routes with a lower priority are moved closer to the bottom of the stack,
/// routes with an equal priority keep the order in which they were added.
///
/// This is what makes dialogs and bottom sheets "float": they declare a
/// positive priority, the root screens declare a negative one, and whatever
/// the application pushes, the result is always ordered correctly.
///
/// ```dart
/// NavigationController(
///   <NavigationRoute>[Routes.home],
///   guards: <NavigationGuard>[const PriorityGuard()],
/// );
/// ```
/// {@endtemplate}
class PriorityGuard implements NavigationGuard {
  /// {@macro squid.priority_guard}
  const PriorityGuard();

  /// Sorts [stack] by priority.
  @override
  NavigationStack call(NavigationController controller, NavigationStack stack) {
    if (stack.length < 2) return stack;
    var sorted = true;
    for (var i = 1; i < stack.length; i++) {
      if (stack[i - 1].priority <= stack[i].priority) continue;
      sorted = false;
      break;
    }
    if (sorted) return stack;
    // A stable sort: the index is used as a tie breaker, so the routes with
    // the same priority keep their relative order.
    final indexed =
        <({int index, NavigationRoute route})>[
          for (var i = 0; i < stack.length; i++) (index: i, route: stack[i]),
        ]..sort((a, b) {
          final result = a.route.priority.compareTo(b.route.priority);
          return result != 0 ? result : a.index.compareTo(b.index);
        });
    return <NavigationRoute>[for (final entry in indexed) entry.route];
  }

  @override
  String toString() => 'PriorityGuard()';
}

/// {@template squid.root_guard}
/// Keeps [root] at the bottom of the stack and the stack non empty.
///
/// Whatever happens — a deep link, an aggressive guard, a user that popped
/// everything — the application always has a screen to show, and going back
/// always leads home.
///
/// ```dart
/// NavigationController(
///   <NavigationRoute>[Routes.home],
///   guards: <NavigationGuard>[RootGuard(() => Routes.home)],
/// );
/// ```
/// {@endtemplate}
class RootGuard implements NavigationGuard {
  /// {@macro squid.root_guard}
  const RootGuard(this.root);

  /// The route that must always be at the bottom of the stack.
  final NavigationRoute Function() root;

  /// Ensures the stack starts with the root route.
  @override
  NavigationStack call(NavigationController controller, NavigationStack stack) {
    final route = root();
    if (stack.isNotEmpty && stack.first.key == route.key) return stack;
    return <NavigationRoute>[
      route,
      ...stack.where((other) => other.key != route.key),
    ];
  }

  @override
  String toString() => 'RootGuard()';
}

/// {@template squid.limit_guard}
/// Limits the depth of the navigation stack.
///
/// The root route is always kept, the oldest routes in the middle are dropped
/// first. Protects against the loops a user can build by pushing the same
/// pair of screens over and over again.
///
/// ```dart
/// NavigationController(
///   <NavigationRoute>[Routes.home],
///   guards: <NavigationGuard>[const LimitGuard(16)],
/// );
/// ```
/// {@endtemplate}
class LimitGuard implements NavigationGuard {
  /// {@macro squid.limit_guard}
  const LimitGuard(this.limit) : assert(limit > 0, 'limit must be positive');

  /// Maximum number of routes in the stack.
  final int limit;

  /// Trims the stack to [limit] routes.
  @override
  NavigationStack call(NavigationController controller, NavigationStack stack) {
    if (stack.length <= limit) return stack;
    if (limit == 1) return <NavigationRoute>[stack.first];
    return <NavigationRoute>[
      stack.first,
      ...stack.sublist(stack.length - limit + 1),
    ];
  }

  @override
  String toString() => 'LimitGuard($limit)';
}

/// {@template squid.gate_guard}
/// Keeps the application behind a gate while [isOpen] returns `false`.
///
/// This is the shape of almost every "the user must do X first" rule:
/// authentication, onboarding, a mandatory update, a terms of service
/// screen. While the gate is closed only the routes marked with [tag] are
/// allowed, and as soon as it opens they are removed:
///
/// ```dart
/// NavigationController(
///   <NavigationRoute>[Routes.home],
///   guards: <NavigationGuard>[
///     GateGuard(
///       isOpen: () => authentication.isSignedIn,
///       tag: 'unauthenticated',
///       closed: () => <NavigationRoute>[Routes.signIn],
///       opened: () => <NavigationRoute>[Routes.home],
///     ),
///   ],
///   revalidate: authentication,
/// );
/// ```
///
/// Do not forget the `revalidate` listenable: it is what re-runs the guard
/// when the user finally signs in.
/// {@endtemplate}
class GateGuard implements NavigationGuard {
  /// {@macro squid.gate_guard}
  const GateGuard({
    required this.isOpen,
    required this.tag,
    required this.closed,
    required this.opened,
  });

  /// Whether the gate is open and the application can be used.
  final bool Function() isOpen;

  /// The tag marking the routes that belong to the gate itself,
  /// e.g. the sign in screen and everything reachable from it.
  final String tag;

  /// The stack to show while the gate is closed.
  final NavigationStack Function() closed;

  /// The stack to fall back to when the gate opens and nothing is left.
  final NavigationStack Function() opened;

  /// Applies the gate to the stack.
  @override
  NavigationStack call(NavigationController controller, NavigationStack stack) {
    if (isOpen()) {
      if (!stack.any((route) => route.tags.contains(tag))) return stack;
      final next = stack
          .where((route) => !route.tags.contains(tag))
          .toList(growable: true);
      return next.isEmpty ? opened() : next;
    } else {
      if (stack.isNotEmpty && stack.every((r) => r.tags.contains(tag))) {
        return stack;
      }
      final next = stack
          .where((route) => route.tags.contains(tag))
          .toList(growable: true);
      return next.isEmpty ? closed() : next;
    }
  }

  @override
  String toString() => 'GateGuard($tag)';
}
