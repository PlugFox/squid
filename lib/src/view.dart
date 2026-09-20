import 'package:flutter/foundation.dart';
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
  final bool interceptBackButton;

  /// Overrides the reaction to the system back button.
  ///
  /// Return `true` when the press has been handled, otherwise the press is
  /// passed to the rest of the application and may close it.
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
  /// Observer used to reach the [NavigatorState] without a global key.
  final NavigatorObserver _spy = NavigatorObserver();

  /// Cache of the pages, so that an unchanged route is not rebuilt.
  final Map<LocalKey, ({NavigationRoute route, Page<Object?> page})> _cache =
      <LocalKey, ({NavigationRoute route, Page<Object?> page})>{};

  late List<NavigatorObserver> _observers;

  /// Whether the stack is being revalidated because the dependencies of this
  /// element changed. A rebuild is already on its way in that case.
  bool _revalidating = false;

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
    WidgetsBinding.instance.addObserver(this);
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
    _revalidating = true;
    try {
      widget.controller.revalidate();
    } finally {
      _revalidating = false;
    }
  }

  @override
  void didUpdateWidget(covariant NavigationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.observers, oldWidget.observers)) {
      _observers = <NavigatorObserver>[_spy, ...widget.observers];
    }
    if (identical(widget.controller, oldWidget.controller)) return;
    oldWidget.controller
      ..removeListener(_handleStackChanged)
      ..detach(this);
    widget.controller
      ..attach(this)
      ..addListener(_handleStackChanged);
    _cache.clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller
      ..removeListener(_handleStackChanged)
      ..detach(this);
    _cache.clear();
    super.dispose();
  }

  /* #endregion */

  void _handleStackChanged() {
    if (!mounted || _revalidating) return;
    setState(() {});
  }

  @override
  Future<bool> didPopRoute() {
    if (!widget.interceptBackButton) return SynchronousFuture<bool>(false);
    final handler = widget.onBackButtonPressed;
    if (handler != null) return handler(widget.controller);
    return widget.controller.maybePop();
  }

  /// Called by the [Navigator] when a route has been closed by the user
  /// or by the framework: a swipe back, a tap on the barrier of a dialog,
  /// the button of an [AppBar].
  void _handleDidRemovePage(Page<Object?> page) {
    final key = page.key;
    if (key == null) return;
    widget.controller.removeKey(key);
  }

  /// Converts the routes into pages, reusing the unchanged ones.
  List<Page<Object?>> _buildPages(BuildContext context) {
    final stack = widget.controller.stack;
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
    return pages;
  }

  @override
  Widget build(BuildContext context) => NavigationScope(
    controller: widget.controller,
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
  );
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
  const NavigationScope({
    required NavigationController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

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
