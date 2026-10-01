import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:squid/src/guard.dart';
import 'package:squid/src/observer.dart';
import 'package:squid/src/route.dart';

/// Transformation of the navigation stack.
///
/// Receives a mutable copy of the current stack and returns the desired one.
/// Both mutating the copy and building a brand new list are allowed:
///
/// ```dart
/// controller.change((stack) => <NavigationRoute>[...stack, Routes.settings]);
/// controller.change((stack) => stack..removeLast());
/// ```
typedef NavigationChange = NavigationStack Function(NavigationStack stack);

/// A widget that renders a [NavigationController].
///
/// Implemented by `NavigationView`, which attaches itself to the controller
/// so that the controller can reach the [Navigator] it drives.
@internal
abstract interface class NavigationAttachment {
  /// Context of the widget that renders the controller.
  BuildContext? get context;

  /// Navigator driven by the controller, `null` before the first build.
  NavigatorState? get navigator;

  /// Called when the group of the controller has changed, e.g. another tab
  /// has been selected, so the widget may handle the back button differently.
  void didChangeGroup();
}

/// A group of controllers where only one of them is active at a time.
///
/// Implemented by `NavigationTabsController`.
@internal
abstract interface class NavigationGroup {
  /// Whether [controller] is the active member of the group.
  bool isActiveMember(NavigationController controller);

  /// Handles a back button press that the active member could not handle.
  ///
  /// Returns `true` when the group switched back to the previously
  /// selected member.
  bool popGroupMember();

  /// Whether [popGroupMember] would switch to another member.
  bool get canPopGroupMember;
}

/// {@template squid.controller}
/// Owner of a [NavigationStack].
///
/// The controller is the single source of truth of the navigation: every
/// change goes through [change], is validated by the [guards] and only then
/// becomes visible to the widgets.
///
/// ```dart
/// final controller = NavigationController(
///   <NavigationRoute>[Routes.home],
///   guards: <NavigationGuard>[
///     AuthenticationGuard(authentication),
///     const PriorityGuard(),
///   ],
///   revalidate: authentication,
/// );
/// ```
///
/// A controller can live without any widget: it is a plain [ChangeNotifier]
/// and can be created, mutated and tested outside of the widget tree. Attach
/// it to a `NavigationView` to render it, or to several of them (for example
/// one per tab) to control one stack from another place of the application.
/// {@endtemplate}
class NavigationController
    with ChangeNotifier
    implements ValueListenable<NavigationStack> {
  /// {@macro squid.controller}
  ///
  /// The [initial] stack must not be empty and is validated by the [guards]
  /// immediately, so the very first frame is already consistent.
  NavigationController(
    NavigationStack initial, {
    List<NavigationGuard> guards = const <NavigationGuard>[],
    List<NavigationObserver> observers = const <NavigationObserver>[],
    Listenable? revalidate,
    this.debugLabel,
  }) : guards = List<NavigationGuard>.unmodifiable(guards),
       observers = List<NavigationObserver>.unmodifiable(observers),
       _revalidate = revalidate,
       _stack = const <NavigationRoute>[] {
    if (initial.isEmpty) {
      throw ArgumentError.value(
        initial,
        'initial',
        'The initial navigation stack must not be empty',
      );
    }
    final candidate = _dedupe(List<NavigationRoute>.of(initial));
    // Publish the requested stack before the validation, so that a guard
    // reading `controller.stack` sees the stack it is validating.
    _stack = UnmodifiableListView<NavigationRoute>(candidate);
    final next = _dedupe(_runGuards(candidate));
    if (next.isEmpty) {
      throw ArgumentError.value(
        initial,
        'initial',
        'The guards have rejected every route of the initial stack',
      );
    }
    _stack = UnmodifiableListView<NavigationRoute>(
      List<NavigationRoute>.of(next),
    );
    revalidate?.addListener(this.revalidate);
  }

  /// Guards applied to every change of the stack, in the order they are
  /// declared: each guard receives the result of the previous one.
  final List<NavigationGuard> guards;

  /// Observers notified after every committed change of the stack.
  final List<NavigationObserver> observers;

  /// Name of this controller, used in logs and in [toString].
  final String? debugLabel;

  final Listenable? _revalidate;
  final List<NavigationAttachment> _attachments = <NavigationAttachment>[];
  final Map<LocalKey, Completer<Object?>> _completers =
      <LocalKey, Completer<Object?>>{};
  final Map<LocalKey, Object?> _results = <LocalKey, Object?>{};

  /// Maximum number of changes requested from within a single transition.
  ///
  /// The changes over the limit are reported to `FlutterError` and dropped:
  /// use [pushAll] or a single [change] instead of many separate calls from
  /// a listener.
  static const int _maxQueuedChanges = 64;

  NavigationStack _stack;
  List<NavigationChange>? _queue;
  NavigationGroup? _group;
  bool _processing = false;
  bool _disposed = false;

  /// Whether the listeners are notified at the end of the frame instead of
  /// synchronously, see [revalidateDuringBuild].
  bool _deferNotifications = false;
  bool _notificationScheduled = false;

  /// Transitions waiting to be reported to the [observers] at the end of the
  /// frame, see [revalidateDuringBuild].
  final List<(NavigationStack, NavigationStack)> _deferredObserverEvents =
      <(NavigationStack, NavigationStack)>[];

  /* #region State */

  /// Current navigation stack, an unmodifiable list ordered from the root
  /// of the navigation to the visible route.
  ///
  /// {@macro squid.stack}
  NavigationStack get stack => _stack;

  /// Replaces the whole navigation stack.
  ///
  /// The new stack is validated by the [guards] first and may be rejected
  /// or altered by them.
  set stack(NavigationStack stack) => change((_) => stack);

  @override
  NavigationStack get value => _stack;

  /// The visible route, the last element of the [stack].
  NavigationRoute get top => _stack.last;

  /// Number of routes in the [stack].
  int get length => _stack.length;

  /// Whether the controller has been disposed.
  bool get isDisposed => _disposed;

  /// Context of the widget rendering this controller, if it is mounted.
  ///
  /// This is what a guard reads to reach the widget tree: the media query,
  /// the theme, an inherited scope with the dependencies. Such a read
  /// subscribes the [NavigationView] to that inherited widget, so the guards
  /// are re-run whenever it changes — see [ContextGuard].
  ///
  /// It is `null` before the first widget is mounted, e.g. while the
  /// constructor validates the initial stack.
  BuildContext? get context {
    for (var i = _attachments.length - 1; i >= 0; i--) {
      final context = _attachments[i].context;
      if (context != null && context.mounted) return context;
    }
    return null;
  }

  /// Navigator driven by this controller, if it is mounted.
  NavigatorState? get navigator {
    for (var i = _attachments.length - 1; i >= 0; i--) {
      final navigator = _attachments[i].navigator;
      if (navigator != null && navigator.mounted) return navigator;
    }
    return null;
  }

  /// Whether the [stack] contains a route with the same key as [route].
  bool contains(NavigationRoute route) => containsKey(route.key);

  /// Whether the [stack] contains a route with the given [key].
  bool containsKey(LocalKey key) => _stack.any((route) => route.key == key);

  /* #endregion */

  /* #region Mutations */

  /// The main navigation method: rewrites the stack with [fn].
  ///
  /// Everything else in this class is a shortcut for this method.
  ///
  /// ```dart
  /// controller.change((stack) => <NavigationRoute>[
  ///       ...stack.where((route) => !route.tags.contains('modal')),
  ///       const ProductRoute(42),
  ///     ]);
  /// ```
  void change(NavigationChange fn) {
    if (_disposed) return;
    if (_processing) {
      // Reentrant call from a guard, an observer or a listener:
      // postpone it until the current transition is committed.
      (_queue ??= <NavigationChange>[]).add(fn);
      return;
    }
    _processing = true;
    try {
      _transition(fn);
      final queue = _queue;
      // A guard or a listener that changes the stack on every notification
      // would loop forever: stop it instead of freezing the application.
      for (var i = 0; queue != null && queue.isNotEmpty; i++) {
        // A listener may dispose the controller while it is being notified.
        if (_disposed) break;
        if (i >= _maxQueuedChanges) {
          _reportError(
            StateError(
              'More than $_maxQueuedChanges changes have been requested '
              'while committing a single one',
            ),
            StackTrace.current,
            'draining the queue',
          );
          break;
        }
        _transition(queue.removeAt(0));
      }
    } finally {
      _queue = null;
      _processing = false;
      _settleResults();
    }
  }

  /// Revalidates the current stack by running all [guards] again.
  ///
  /// Called automatically whenever the `revalidate` listenable passed to the
  /// constructor notifies: the user signs in, the subscription status
  /// changes, a feature flag arrives and so on.
  void revalidate() => change((stack) => stack);

  /// Revalidates the stack from the build phase of a widget.
  ///
  /// The new stack is committed immediately, so the widget that requested
  /// the revalidation builds it in the current frame, while the listeners are
  /// notified at the end of the frame: marking an ancestor of the building
  /// widget dirty would be an error.
  @internal
  void revalidateDuringBuild() {
    if (_deferNotifications) return revalidate();
    _deferNotifications = true;
    try {
      revalidate();
    } finally {
      _deferNotifications = false;
    }
  }

  /// Adds [route] on top of the stack.
  ///
  /// If the stack already contains a route with the same
  /// [NavigationRoute.key], that route is moved to the top instead of
  /// being duplicated.
  void push(NavigationRoute route) => change((stack) => stack..add(route));

  /// Adds [routes] on top of the stack, in the given order.
  void pushAll(Iterable<NavigationRoute> routes) =>
      change((stack) => stack..addAll(routes));

  /// Adds [route] on top of the stack and waits until it is removed.
  ///
  /// The future completes with the value passed to [pop] / [remove], or with
  /// `null` when the route is closed in any other way: a swipe back, a tap on
  /// the barrier of a dialog, the system back button or a guard.
  ///
  /// Only one caller can wait for a route: pushing a route with the same
  /// [NavigationRoute.key] again completes the previous future with `null`
  /// right away, even though the route stays on the screen.
  ///
  /// ```dart
  /// final confirmed =
  ///     await controller.pushForResult<bool>(const ConfirmDialog());
  /// ```
  Future<T?> pushForResult<T extends Object?>(NavigationRoute route) {
    final key = route.key;
    _completers.remove(key)?.complete(null);
    if (_disposed) return Future<T?>.value();
    final completer = _completers[key] = Completer<Object?>();
    // A push rejected by a guard is completed with `null` as soon as the
    // change is committed, see [_settleResults].
    push(route);
    return completer.future.then<T?>((result) => result is T ? result : null);
  }

  /// Replaces the visible route with [route].
  void replaceTop(NavigationRoute route) =>
      change((stack) => stack..[stack.length - 1] = route);

  /// Removes the visible route and completes its [pushForResult] future
  /// with [result].
  ///
  /// Does nothing and returns `false` when there is only one route left,
  /// because an empty stack is not allowed.
  ///
  /// When called from a guard, an observer or a listener, the pop is
  /// postponed until the current change is committed and `true` only means
  /// that it has been scheduled.
  bool pop([Object? result]) {
    if (!_processing && _stack.length < 2) return false;
    // The result is bound to the route that is actually removed, which is
    // not necessarily the current top when the call is postponed.
    change((stack) {
      if (stack.length < 2) return stack;
      _results[stack.last.key] = result;
      return stack..removeLast();
    });
    return true;
  }

  /// Tries to close the visible route the same way the system back button
  /// does.
  ///
  /// Unlike [pop] it respects [PopScope] and closes the imperative routes
  /// (e.g. a `showDialog` or a menu) opened on top of the declarative stack
  /// first. When the stack cannot be popped and the controller belongs to a
  /// group of tabs, the group switches back to the previously selected tab.
  ///
  /// Returns `true` when the back navigation was handled.
  Future<bool> maybePop() async {
    if (_disposed) return false;
    final group = _group;
    if (group != null && !group.isActiveMember(this)) return false;
    final navigator = this.navigator;
    if (navigator != null) {
      if (await navigator.maybePop()) return true;
    } else if (pop()) {
      return true;
    }
    return group?.popGroupMember() ?? false;
  }

  /// Removes the routes from the top of the stack until [predicate] returns
  /// `true` for the visible route.
  ///
  /// The root route is never removed.
  void popUntil(bool Function(NavigationRoute route) predicate) =>
      change((stack) {
        while (stack.length > 1 && !predicate(stack.last)) stack.removeLast();
        return stack;
      });

  /// Removes everything except the root route.
  void popToRoot() => change((stack) => stack..length = 1);

  /// Removes the route with the same key as [route] and completes its
  /// [pushForResult] future with [result].
  bool remove(NavigationRoute route, [Object? result]) =>
      removeKey(route.key, result);

  /// Removes the route with the given [key] and completes its
  /// [pushForResult] future with [result].
  ///
  /// Returns `false` when the stack has no such route. When called from a
  /// guard, an observer or a listener, the removal is postponed until the
  /// current change is committed and `true` only means that it has been
  /// scheduled.
  bool removeKey(LocalKey key, [Object? result]) {
    if (!_processing && !containsKey(key)) return false;
    change((stack) {
      final length = stack.length;
      stack.removeWhere((route) => route.key == key);
      if (stack.length != length) _results[key] = result;
      return stack;
    });
    return true;
  }

  /// Removes every route matching [test].
  void removeWhere(bool Function(NavigationRoute route) test) =>
      change((stack) => stack..removeWhere(test));

  /// Removes every route marked with [tag].
  ///
  /// The most common use case is closing all the modals at once:
  ///
  /// ```dart
  /// controller.removeTag(kModalTag);
  /// ```
  void removeTag(String tag) =>
      removeWhere((route) => route.tags.contains(tag));

  /* #endregion */

  /* #region Internal */

  /// Attaches a widget rendering this controller.
  @internal
  void attach(NavigationAttachment attachment) {
    if (_attachments.contains(attachment)) return;
    _attachments.add(attachment);
  }

  /// Detaches a widget rendering this controller.
  @internal
  void detach(NavigationAttachment attachment) =>
      _attachments.remove(attachment);

  /// Whether this controller may react to the back button: it does not
  /// belong to a group or it is the active member of its group.
  @internal
  bool get isActiveInGroup => _group?.isActiveMember(this) ?? true;

  /// Whether the group of this controller handles a back button press that
  /// the controller itself cannot handle.
  @internal
  bool get canPopGroupMember => _group?.canPopGroupMember ?? false;

  /// Tells the widgets rendering this controller that its group has changed.
  @internal
  void didChangeGroup() {
    for (final attachment in List<NavigationAttachment>.of(_attachments)) {
      attachment.didChangeGroup();
    }
  }

  /// Joins a group of controllers, e.g. a set of tabs.
  @internal
  // ignore: use_setters_to_change_properties
  void joinGroup(NavigationGroup group) => _group = group;

  /// Leaves the group of controllers.
  @internal
  void leaveGroup(NavigationGroup group) {
    if (identical(_group, group)) _group = null;
  }

  /// Applies a single change: mutation, guards and commit.
  void _transition(NavigationChange fn) {
    try {
      final previous = _stack;
      NavigationStack next;
      try {
        next = fn(List<NavigationRoute>.of(previous));
      } on Object catch (error, stackTrace) {
        _reportError(error, stackTrace, 'changing the navigation stack');
        return;
      }
      next = _dedupe(_runGuards(_dedupe(next)));
      // A guard may dispose the controller, e.g. on sign out.
      if (_disposed) return;
      if (next.isEmpty) {
        // Reported instead of asserted: an exception here would drop the
        // changes queued after this one.
        _reportError(
          StateError('The navigation stack cannot be empty'),
          StackTrace.current,
          'committing a change rejected by the guards',
        );
        return;
      }
      if (_sameStack(previous, next)) return;
      _stack = UnmodifiableListView<NavigationRoute>(
        List<NavigationRoute>.of(next),
      );
      _completeRemoved(previous, next);
      _notifyListeners();
      _notifyObservers(previous, next);
    } finally {
      // A result belongs to the change that set it: the result of a pop
      // cancelled by a guard must not leak into a later removal.
      _results.clear();
    }
  }

  /// Runs all the guards, skipping the failed ones.
  NavigationStack _runGuards(NavigationStack candidate) {
    var next = candidate;
    for (final guard in guards) {
      try {
        next = guard(this, List<NavigationRoute>.of(next));
      } on Object catch (error, stackTrace) {
        _reportError(error, stackTrace, 'running the guard $guard');
      }
    }
    return next;
  }

  /// Keeps the last route for every key, so that pushing an already existing
  /// route moves it to the top instead of breaking the [Navigator].
  NavigationStack _dedupe(NavigationStack stack) {
    if (stack.length < 2) return stack;
    final keys = <LocalKey>{};
    var duplicates = false;
    for (final route in stack) {
      if (keys.add(route.key)) continue;
      duplicates = true;
      break;
    }
    if (!duplicates) return stack;
    final unique = <LocalKey>{};
    final result = <NavigationRoute>[];
    for (var i = stack.length - 1; i >= 0; i--) {
      final route = stack[i];
      if (unique.add(route.key)) result.add(route);
    }
    return result.reversed.toList(growable: true);
  }

  /// Compares two stacks route by route.
  static bool _sameStack(NavigationStack a, NavigationStack b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i], y = b[i];
      if (identical(x, y) || x == y) continue;
      return false;
    }
    return true;
  }

  /// Completes the futures of the routes that left the stack.
  void _completeRemoved(NavigationStack previous, NavigationStack next) {
    if (_completers.isEmpty && _results.isEmpty) return;
    final keys = <LocalKey>{for (final route in next) route.key};
    for (final route in previous) {
      final key = route.key;
      if (keys.contains(key)) {
        // The route is still there: the result of a cancelled pop is stale.
        _results.remove(key);
        continue;
      }
      _completers.remove(key)?.complete(_results.remove(key));
    }
  }

  void _notifyListeners() {
    if (!_deferNotifications) return notifyListeners();
    _scheduleNotifications();
  }

  /// Notifies the listeners and the observers at the end of the frame.
  void _scheduleNotifications() {
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _notificationScheduled = false;
        if (_disposed) return;
        notifyListeners();
        final events = List<(NavigationStack, NavigationStack)>.of(
          _deferredObserverEvents,
        );
        _deferredObserverEvents.clear();
        for (final (previous, next) in events) {
          if (_disposed) return;
          _dispatchObservers(previous, next);
        }
      }, debugLabel: 'NavigationController.notifyListeners')
      ..ensureVisualUpdate();
  }

  /// Completes the futures of the routes that are not in the stack once all
  /// the queued changes have been committed, e.g. a [pushForResult] requested
  /// from a listener and then rejected by a guard, and drops the results that
  /// were not consumed by any removal.
  void _settleResults() {
    _results.clear();
    if (_completers.isEmpty) return;
    final keys = <LocalKey>{for (final route in _stack) route.key};
    final orphans = <Completer<Object?>>[];
    _completers.removeWhere((key, completer) {
      if (keys.contains(key)) return false;
      orphans.add(completer);
      return true;
    });
    for (final completer in orphans) {
      if (!completer.isCompleted) completer.complete(null);
    }
  }

  void _notifyObservers(NavigationStack previous, NavigationStack next) {
    if (observers.isEmpty) return;
    if (!_deferNotifications && _deferredObserverEvents.isEmpty) {
      return _dispatchObservers(previous, next);
    }
    // An observer may mark widgets dirty, which is not allowed during the
    // build: report the transition at the end of the frame, in order.
    _deferredObserverEvents.add((previous, next));
    _scheduleNotifications();
  }

  void _dispatchObservers(NavigationStack previous, NavigationStack next) {
    final before = <LocalKey>{for (final route in previous) route.key};
    final after = <LocalKey>{for (final route in next) route.key};
    for (final observer in observers) {
      // Every callback is isolated, so a failed one does not swallow the
      // remaining events of the same observer.
      _notifyObserver(observer, () => observer.onChange(this, previous, next));
      for (final route in next) {
        if (before.contains(route.key)) continue;
        _notifyObserver(observer, () => observer.onAdd(this, route));
      }
      for (final route in previous) {
        if (after.contains(route.key)) continue;
        _notifyObserver(observer, () => observer.onRemove(this, route));
      }
    }
  }

  void _notifyObserver(NavigationObserver observer, void Function() fn) {
    try {
      fn();
    } on Object catch (error, stackTrace) {
      _reportError(error, stackTrace, 'notifying the observer $observer');
    }
  }

  void _reportError(Object error, StackTrace stackTrace, String context) =>
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'squid',
          context: ErrorDescription('while $context of $this'),
        ),
      );

  /* #endregion */

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _revalidate?.removeListener(revalidate);
    _attachments.clear();
    for (final completer in _completers.values) {
      if (!completer.isCompleted) completer.complete(null);
    }
    _completers.clear();
    _results.clear();
    _deferredObserverEvents.clear();
    super.dispose();
  }

  @override
  String toString() {
    final buffer = StringBuffer('NavigationController(');
    if (debugLabel != null) buffer.write('$debugLabel: ');
    buffer
      ..writeAll(_stack.map<String>((route) => route.name), ' > ')
      ..write(')');
    return buffer.toString();
  }
}
