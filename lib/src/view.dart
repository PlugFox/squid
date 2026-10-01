import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:squid/src/controller.dart';
import 'package:squid/src/route.dart';

/// {@template squid.view}
/// Renders a [NavigationController] with a [Navigator].
///
/// ```dart
/// MaterialApp(
///   home: NavigationView(controller: controller),
/// );
/// ```
///
/// The widget is a thin adapter: it converts the routes of the controller
/// into pages, reports the routes closed by the user (a swipe back, a tap on
/// the barrier of a dialog) back to the controller and handles the system
/// back button.
///
/// An application can have as many views as it has independent stacks — for
/// example one per tab of a bottom navigation bar — and every one of them is
/// driven by its own controller.
/// {@endtemplate}
class NavigationView extends StatefulWidget {
  /// {@macro squid.view}
  const NavigationView({
    required this.controller,
    this.transitionDelegate = const DefaultTransitionDelegate<Object?>(),
    this.observers = const <NavigatorObserver>[],
    this.interceptBackButton = true,
    this.onBackButtonPressed,
    this.restorationScopeId,
    this.requestFocus = true,
    this.clipBehavior = Clip.hardEdge,
    this.reportsRouteUpdateToEngine = false,
    super.key,
  });

  /// Owner of the navigation stack rendered by this widget.
  final NavigationController controller;

  /// Decides how the routes are animated when the stack changes.
  final TransitionDelegate<Object?> transitionDelegate;

  /// Observers of the underlying [Navigator].
  ///
  /// These are the low level [NavigatorObserver]s of Flutter. To observe the
  /// navigation stack itself use the observers of the controller instead.
  final List<NavigatorObserver> observers;

  /// Whether this view reacts to the system back button.
  ///
  /// Set it to `false` for the views that must never handle the back button,
  /// for example an inactive tab that is kept alive by an [IndexedStack].
  /// Tabs created with a `NavigationTabsController` handle this
  /// automatically.
  ///
  /// Nested views are asked first: a press is handled by the deepest visible
  /// [NavigationView], and only when it cannot go back any further does the
  /// press reach the view that contains it. A nested view is visible while
  /// the route that contains it is the current route of the outer
  /// navigator. Disabling this flag disables the nested views as well.
  final bool interceptBackButton;

  /// Overrides the reaction to the system back button.
  ///
  /// Return `true` when the press has been handled, otherwise the press is
  /// passed to the rest of the application and may close it.
  ///
  /// Called only when the press reaches this view: it is not called when
  /// [interceptBackButton] is `false`, when the controller is an inactive
  /// tab of a `NavigationTabsController`, or when a visible nested view has
  /// already handled the press.
  final Future<bool> Function(NavigationController controller)?
  onBackButtonPressed;

  /// Identifier used to save and restore the state of the navigator,
  /// see [Navigator.restorationScopeId].
  final String? restorationScopeId;

  /// Whether the navigator requests the focus when a route is shown.
  final bool requestFocus;

  /// How the content of the navigator is clipped.
  final Clip clipBehavior;

  /// Whether the navigator reports route changes to the engine.
  ///
  /// Keep it `false` for the nested navigators, otherwise they overwrite
  /// each other in the browser address bar.
  final bool reportsRouteUpdateToEngine;

  /// The controller of the closest [NavigationView] above [context].
  static NavigationController of(BuildContext context) =>
      NavigationScope.of(context);

  /// The controller of the closest [NavigationView] above [context],
  /// if there is one.
  static NavigationController? maybeOf(BuildContext context) =>
      NavigationScope.maybeOf(context);

  @override
  State<NavigationView> createState() => _NavigationViewState();
}

class _NavigationViewState extends State<NavigationView>
    with WidgetsBindingObserver
    implements NavigationAttachment {
  /// Observer used to reach the [NavigatorState] without a global key and
  /// to catch the results of the routes popped by the [Navigator] itself.
  late final _NavigationViewObserver _spy = _NavigationViewObserver(
    (key, result) => _popResults[key] = result,
  );

  /// Results passed to `Navigator.pop`, waiting for [_handleDidRemovePage].
  final Map<LocalKey, Object?> _popResults = <LocalKey, Object?>{};

  /// The closest [NavigationView] above this one, `null` for a top level
  /// view, which receives the back button from the [WidgetsBinding].
  _NavigationViewState? _parent;

  /// The nested views, in the order they were mounted.
  final List<_NavigationViewState> _children = <_NavigationViewState>[];

  /// The route of the outer navigator this view is shown in.
  ModalRoute<Object?>? _route;

  /// Cache of the pages, so that an unchanged route is not rebuilt.
  final Map<LocalKey, ({NavigationRoute route, Page<Object?> page})> _cache =
      <LocalKey, ({NavigationRoute route, Page<Object?> page})>{};

  late List<NavigatorObserver> _observers;

  /// The stack rendered by the last build, used to skip the notifications
  /// about a stack this view has already built.
  NavigationStack? _built;

  bool _reportScheduled = false;

  @override
  NavigatorState? get navigator => _spy.navigator;

  /* #region Lifecycle */

  @override
  void initState() {
    super.initState();
    _observers = <NavigatorObserver>[_spy, ...widget.observers];
    widget.controller
      ..attach(this)
      ..addListener(_handleStackChanged);
    _register();
  }

  @override
  void activate() {
    super.activate();
    _register();
  }

  @override
  void deactivate() {
    _unregister();
    super.deactivate();
  }

  /// Subscribes this view to the back button: either through the closest
  /// view above, or directly through the [WidgetsBinding].
  void _register() {
    final parent = context
        .getElementForInheritedWidgetOfExactType<_NavigationViewMarker>()
        ?.widget;
    if (parent is _NavigationViewMarker) {
      _parent = parent.state.._children.add(this);
    } else {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  void _unregister() {
    final parent = _parent;
    if (parent == null) {
      WidgetsBinding.instance.removeObserver(this);
    } else {
      parent._children.remove(this);
      _parent = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A guard is free to read the context of this widget through
    // `controller.context`: the media query, the theme, an inherited scope
    // with the dependencies of the application. Such a read subscribes this
    // element to that inherited widget, so every change of it lands here —
    // and the guards have to run again to see the new value.
    //
    // When no guard reads anything, this element has no dependencies at all
    // and the callback is invoked exactly once, right after the mount.
    //
    // `NavigationRoute.page` is built with this context too: a page reading
    // the locale or the theme has to be built again, not taken from the
    // cache.
    _cache.clear();
    widget.controller.revalidateDuringBuild();
  }

  @override
  void didUpdateWidget(covariant NavigationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.observers, oldWidget.observers)) {
      _observers = <NavigatorObserver>[_spy, ...widget.observers];
    }
    if (!identical(widget.controller, oldWidget.controller) ||
        widget.interceptBackButton != oldWidget.interceptBackButton ||
        (widget.onBackButtonPressed == null) !=
            (oldWidget.onBackButtonPressed == null)) {
      _reportBackButton();
    }
    if (identical(widget.controller, oldWidget.controller)) return;
    oldWidget.controller
      ..removeListener(_handleStackChanged)
      ..detach(this);
    widget.controller
      ..attach(this)
      ..addListener(_handleStackChanged);
    _cache.clear();
    _popResults.clear();
    _built = null;
    // The guards of the new controller have never seen this context.
    widget.controller.revalidateDuringBuild();
  }

  @override
  void dispose() {
    widget.controller
      ..removeListener(_handleStackChanged)
      ..detach(this);
    _cache.clear();
    super.dispose();
  }

  /* #endregion */

  void _handleStackChanged() {
    if (!mounted || identical(widget.controller.stack, _built)) return;
    setState(() {});
  }

  @override
  Future<bool> didPopRoute() => _handleBackButton();

  /// Whether the back button may reach this view: the route of the outer
  /// navigator that contains it is not covered by anything.
  bool get _visible => mounted && (_route?.isCurrent ?? true);

  /// Offers the back button to the visible nested views first, then handles
  /// it with the controller of this view.
  Future<bool> _handleBackButton() async {
    final controller = widget.controller;
    if (!widget.interceptBackButton || !controller.isActiveInGroup) {
      return false;
    }
    for (final child in _children.reversed.toList(growable: false)) {
      if (!child._visible) continue;
      if (await child._handleBackButton()) return true;
    }
    // The widget may have been updated while the children were asked.
    if (!mounted) return false;
    final handler = widget.onBackButtonPressed;
    if (handler != null) return handler(widget.controller);
    return widget.controller.maybePop();
  }

  /// Whether this view handles the back button even when its navigator
  /// cannot pop: it has its own handler or its tabs return to the previous
  /// one.
  bool get _claimsBackButton =>
      widget.interceptBackButton &&
      widget.controller.isActiveInGroup &&
      (widget.onBackButtonPressed != null ||
          widget.controller.canPopGroupMember);

  /// Tells the platform whether the framework handles the back button.
  ///
  /// The navigator reports `canHandlePop: false` when it has a single route,
  /// so on Android with the predictive back gesture the press would close
  /// the application without ever reaching [didPopRoute].
  bool _handleNavigationNotification(NavigationNotification notification) {
    // An inactive tab kept alive by an `IndexedStack` must not speak for
    // the visible one.
    if (widget.interceptBackButton && !widget.controller.isActiveInGroup) {
      return true;
    }
    if (notification.canHandlePop || !_claimsBackButton) return false;
    const NavigationNotification(canHandlePop: true).dispatch(context);
    return true;
  }

  /// Reports the current state of the back button, when it may have changed
  /// without a change of the navigator, e.g. another tab has been selected.
  void _reportBackButton() {
    if (_reportScheduled) return;
    _reportScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (!mounted || !_visible) return;
      if (!widget.interceptBackButton || !widget.controller.isActiveInGroup) {
        return;
      }
      final canPop = navigator?.canPop() ?? false;
      NavigationNotification(
        canHandlePop: canPop || _claimsBackButton,
      ).dispatch(context);
    }, debugLabel: 'NavigationView.reportBackButton');
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeGroup() => _reportBackButton();

  /// Called by the [Navigator] when a route has been closed by the user
  /// or by the framework: a swipe back, a tap on the barrier of a dialog,
  /// the button of an [AppBar], a `Navigator.pop(context, result)`.
  void _handleDidRemovePage(Page<Object?> page) {
    final key = page.key;
    if (key == null) return;
    final controller = widget.controller
      ..removeKey(key, _popResults.remove(key));
    // A guard has kept the route: the navigator has already dropped it, so
    // the pages have to be rebuilt to bring it back.
    if (mounted && controller.containsKey(key)) setState(() {});
  }

  /// Converts the routes into pages, reusing the unchanged ones.
  List<Page<Object?>> _buildPages(BuildContext context) {
    final stack = _built = widget.controller.stack;
    final keys = <LocalKey>{};
    final pages = <Page<Object?>>[];
    for (final route in stack) {
      final key = route.key;
      keys.add(key);
      final cached = _cache[key];
      if (cached != null && identical(cached.route, route)) {
        pages.add(cached.page);
        continue;
      }
      final page = route.page(context);
      assert(
        page.key == key,
        'The page of $route must use the key of the route, '
        'otherwise the navigator cannot match them',
      );
      _cache[key] = (route: route, page: page);
      pages.add(page);
    }
    _cache.removeWhere((key, _) => !keys.contains(key));
    _popResults.removeWhere((key, _) => !keys.contains(key));
    return pages;
  }

  @override
  Widget build(BuildContext context) => _NavigationViewMarker(
    state: this,
    child: _RouteProbe(
      onRoute: (route) => _route = route,
      child: NavigationScope(
        controller: widget.controller,
        child: NotificationListener<NavigationNotification>(
          onNotification: _handleNavigationNotification,
          child: Navigator(
            pages: _buildPages(context),
            onDidRemovePage: _handleDidRemovePage,
            transitionDelegate: widget.transitionDelegate,
            observers: _observers,
            restorationScopeId: widget.restorationScopeId,
            requestFocus: widget.requestFocus,
            clipBehavior: widget.clipBehavior,
            reportsRouteUpdateToEngine: widget.reportsRouteUpdateToEngine,
          ),
        ),
      ),
    ),
  );
}

/// Links a [NavigationView] with the views nested into its routes.
class _NavigationViewMarker extends InheritedWidget {
  const _NavigationViewMarker({required this.state, required super.child});

  final _NavigationViewState state;

  @override
  bool updateShouldNotify(_NavigationViewMarker oldWidget) => false;
}

/// Tracks the route of the outer navigator a [NavigationView] is shown in.
///
/// A separate element, so that the dependency on the [ModalRoute] does not
/// re-run the guards of the view on every transition of the outer navigator.
class _RouteProbe extends StatefulWidget {
  const _RouteProbe({required this.onRoute, required this.child});

  final ValueChanged<ModalRoute<Object?>?> onRoute;

  final Widget child;

  @override
  State<_RouteProbe> createState() => _RouteProbeState();
}

class _RouteProbeState extends State<_RouteProbe> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.onRoute(ModalRoute.of(context));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Catches the results of the routes popped by the [Navigator] itself, e.g.
/// with `Navigator.pop(context, result)`, before the page is reported as
/// removed.
class _NavigationViewObserver extends NavigatorObserver {
  _NavigationViewObserver(this._onPop);

  final void Function(LocalKey key, Object? result) _onPop;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _track(newRoute);
  }

  void _track(Route<dynamic> route) {
    if (route is! ModalRoute<Object?>) return;
    final key = switch (route.settings) {
      Page<Object?>(:final key?) => key,
      _ => null,
    };
    if (key == null) return;
    route.registerPopEntry(_PopResultEntry(key, _onPop));
  }
}

/// A [PopEntry] that never blocks the pop and only records its result.
class _PopResultEntry extends PopEntry<Object?> {
  _PopResultEntry(this._key, this._onPop);

  final LocalKey _key;
  final void Function(LocalKey key, Object? result) _onPop;

  @override
  final ValueListenable<bool> canPopNotifier = const _AlwaysTrue();

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (didPop) _onPop(_key, result);
  }
}

/// A constant `true` that never changes and keeps no listeners.
class _AlwaysTrue implements ValueListenable<bool> {
  const _AlwaysTrue();

  @override
  bool get value => true;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// {@template squid.scope}
/// Provides a [NavigationController] to the widgets below.
///
/// [NavigationView] creates one automatically, so inside a screen the
/// controller is always one `context.navigation` away:
///
/// ```dart
/// ElevatedButton(
///   onPressed: () => context.navigation.push(Routes.settings),
///   child: const Text('Settings'),
/// );
/// ```
/// {@endtemplate}
class NavigationScope extends InheritedNotifier<NavigationController> {
  /// {@macro squid.scope}
  NavigationScope({
    required NavigationController controller,
    required super.child,
    super.key,
  }) : _stack = controller.stack,
       super(notifier: controller);

  /// The stack at the moment this widget was built.
  ///
  /// Lets the dependents follow a stack committed during the build of the
  /// [NavigationView] in the same frame, before the controller notifies.
  final NavigationStack _stack;

  @override
  bool updateShouldNotify(covariant NavigationScope oldWidget) =>
      !identical(oldWidget._stack, _stack) ||
      super.updateShouldNotify(oldWidget);

  /// The closest controller above [context].
  ///
  /// Pass `listen: true` to rebuild the widget on every change of
  /// the stack.
  static NavigationController of(BuildContext context, {bool listen = false}) {
    final controller = maybeOf(context, listen: listen);
    if (controller != null) return controller;
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary('No NavigationScope found above this widget'),
      ErrorDescription(
        'The widget that called NavigationScope.of() is not a descendant '
        'of a NavigationView.',
      ),
      ErrorHint(
        'Wrap the widget with a NavigationView or a NavigationScope, or use '
        'NavigationScope.maybeOf() to handle the absence of a controller.',
      ),
      context.describeElement('The context used was'),
    ]);
  }

  /// The closest controller above [context], if there is one.
  ///
  /// Pass `listen: true` to rebuild the widget on every change of
  /// the stack.
  static NavigationController? maybeOf(
    BuildContext context, {
    bool listen = false,
  }) {
    if (listen) {
      return context
          .dependOnInheritedWidgetOfExactType<NavigationScope>()
          ?.notifier;
    }
    final element = context
        .getElementForInheritedWidgetOfExactType<NavigationScope>();
    return (element?.widget as NavigationScope?)?.notifier;
  }

  /// The stack of the closest controller above [context].
  ///
  /// The widget is rebuilt on every change of the stack.
  static NavigationStack stackOf(BuildContext context) =>
      of(context, listen: true).stack;
}
