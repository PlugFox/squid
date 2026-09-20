import 'package:example/src/routes.dart';
import 'package:flutter/widgets.dart';
import 'package:squid/squid.dart';

/// {@template example.tabs_scope}
/// Provides the [NavigationTabsController] to the whole application, so that
/// any screen can rewrite the stack of any tab.
/// {@endtemplate}
class AppTabsScope extends InheritedWidget {
  /// {@macro example.tabs_scope}
  const AppTabsScope({required this.tabs, required super.child, super.key});

  /// The tabs of the application.
  final NavigationTabsController<AppTab> tabs;

  /// The tabs above the given context.
  static NavigationTabsController<AppTab> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppTabsScope>()!.tabs;

  @override
  bool updateShouldNotify(covariant AppTabsScope oldWidget) =>
      !identical(tabs, oldWidget.tabs);
}
