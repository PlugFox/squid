import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:squid/src/controller.dart';

/// {@template squid.tabs}
/// A set of independent navigation stacks where only one is visible at a
/// time: the tabs of a bottom navigation bar, the sections of a side rail,
/// the panes of a desktop layout.
///
/// Every tab keeps its own [NavigationController], so switching between the
/// tabs does not lose their stacks, and one tab can rewrite the stack of
/// another one:
///
/// ```dart
/// final tabs = NavigationTabsController<AppTab>(
///   tabs: <AppTab, NavigationController>{
///     AppTab.feed: NavigationController(<NavigationRoute>[Routes.feed]),
///     AppTab.cart: NavigationController(<NavigationRoute>[Routes.cart]),
///   },
/// );
///
/// // From the feed: put the product into the cart tab and open it.
/// tabs[AppTab.cart].push(ProductRoute(id));
/// tabs.select(AppTab.cart);
/// ```
///
/// The back button is routed to the active tab automatically: the inactive
/// tabs never react to it, and when the active tab cannot go back any
/// further, the controller returns to the previously selected tab instead of
/// closing the application.
///
/// The controller notifies its listeners both when the selected tab changes
/// and when the stack of any tab changes, so a shell built with a
/// [ListenableBuilder] around it always sees the current navigation.
/// {@endtemplate}
class NavigationTabsController<K extends Object>
    with ChangeNotifier
    implements ValueListenable<K>, NavigationGroup {
  /// {@macro squid.tabs}
  ///
  /// [initial] defaults to the first tab of [tabs].
  /// Set [disposeTabs] to `false` when the controllers are owned by
  /// somebody else, e.g. by a dependency injection container.
  NavigationTabsController({
    required Map<K, NavigationController> tabs,
    K? initial,
    this.disposeTabs = true,
  }) : assert(tabs.isNotEmpty, 'At least one tab is required'),
       assert(
         initial == null || tabs.containsKey(initial),
         'The initial tab must be one of the tabs',
       ),
       tabs = UnmodifiableMapView<K, NavigationController>(
         Map<K, NavigationController>.of(tabs),
       ),
       _active = initial ?? tabs.keys.first,
       _history = <K>[] {
    for (final controller in this.tabs.values) {
      controller
        ..joinGroup(this)
        ..addListener(notifyListeners);
    }
  }

  /// The controllers of all the tabs, in their declaration order.
  final Map<K, NavigationController> tabs;

  /// Whether [dispose] also disposes the controllers of the [tabs].
  final bool disposeTabs;

  final List<K> _history;
  K _active;

  /// The selected tab.
  K get active => _active;

  @override
  K get value => _active;

  /// The controller of the selected tab.
  NavigationController get controller => tabs[_active]!;

  /// The tabs to return to, the oldest first.
  ///
  /// Every tab appears in the history at most once, so going back always
  /// terminates instead of bouncing between two tabs forever.
  List<K> get history => UnmodifiableListView<K>(_history);

  /// The controller of the given tab.
  NavigationController operator [](K tab) {
    final controller = tabs[tab];
    if (controller != null) return controller;
    throw ArgumentError.value(tab, 'tab', 'Unknown tab');
  }

  /// The index of the given tab, handy for a [BottomNavigationBar].
  ///
  /// Returns `-1` for a tab that does not belong to this controller.
  int indexOf(K tab) => tabs.keys.toList(growable: false).indexOf(tab);

  /// The index of the selected tab.
  int get activeIndex => indexOf(_active);

  /// Selects [tab].
  ///
  /// Selecting the already active tab pops its stack to the root, which is
  /// the behavior users expect from a bottom navigation bar. Pass
  /// `popToRoot: false` to keep the stack untouched.
  void select(K tab, {bool popToRoot = true}) {
    if (!tabs.containsKey(tab)) {
      throw ArgumentError.value(tab, 'tab', 'Unknown tab');
    }
    if (tab == _active) {
      if (popToRoot) controller.popToRoot();
      return;
    }
    _history
      ..remove(tab)
      ..add(_active);
    _active = tab;
    notifyListeners();
    _didChangeGroup();
  }

  /// Returns to the previously selected tab.
  ///
  /// Returns `false` when there is nothing to return to.
  bool back() {
    if (_history.isEmpty) return false;
    _active = _history.removeLast();
    notifyListeners();
    _didChangeGroup();
    return true;
  }

  /// Lets the views of the tabs report to the platform whether the back
  /// button is handled, e.g. by returning to the previous tab.
  void _didChangeGroup() {
    for (final controller in tabs.values) {
      controller.didChangeGroup();
    }
  }

  /// Tries to close the visible route of the active tab, and returns to the
  /// previously selected tab when it cannot be closed.
  ///
  /// Returns `true` when the back navigation was handled.
  Future<bool> maybePop() => controller.maybePop();

  @override
  bool isActiveMember(NavigationController controller) =>
      identical(controller, tabs[_active]);

  @override
  bool popGroupMember() => back();

  @override
  bool get canPopGroupMember => _history.isNotEmpty;

  @override
  void dispose() {
    for (final controller in tabs.values) {
      controller
        ..removeListener(notifyListeners)
        ..leaveGroup(this);
      if (disposeTabs) controller.dispose();
    }
    _history.clear();
    super.dispose();
  }

  @override
  String toString() => 'NavigationTabsController($_active)';
}
