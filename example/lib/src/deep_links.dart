import 'package:example/src/routes.dart';
import 'package:flutter/widgets.dart';
import 'package:squid/squid.dart';

/// Where a deep link leads: the tab to select and the stack of that tab.
typedef DeepLink = ({AppTab tab, NavigationStack stack});

/// The link the application has been opened with, or `null`.
///
/// The engine hands it to the framework as the initial route name:
/// * on the web it is the path of the address bar — `/shop/product/3`;
/// * on Android and iOS it is the path of the link that launched the
///   application, once deep linking is enabled for the platform
///   (`flutter_deeplinking_enabled` in `AndroidManifest.xml` / `Info.plist`);
/// * otherwise it is `/`.
///
/// The links that arrive while the application is already running are
/// delivered to [WidgetsBindingObserver.didPushRouteInformation] instead.
Uri? initialDeepLink() {
  final name = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  if (name.isEmpty || name == Navigator.defaultRouteName) return null;
  return Uri.tryParse(name);
}

/// Squid does not dictate the format of the links: a link is converted to a
/// stack by a plain function. Below are three ways to write it, pick the one
/// that matches the shape of your links.

/* #region 1. A switch over the path segments */

/// A `switch` with patterns over [Uri.pathSegments].
///
/// The most readable option while the links are few: every shape of a link
/// is a single line, the arguments are extracted and validated in place.
DeepLink? parseDeepLinkWithSwitch(Uri uri) => switch (uri.pathSegments) {
  [] || ['shop'] => (tab: AppTab.shop, stack: <NavigationRoute>[]),
  ['shop', 'filters'] => (
    tab: AppTab.shop,
    stack: <NavigationRoute>[const FiltersRoute()],
  ),
  ['shop', 'product', final id] when int.tryParse(id) != null => (
    tab: AppTab.shop,
    stack: <NavigationRoute>[ProductRoute(int.parse(id))],
  ),
  ['cart'] => (tab: AppTab.cart, stack: <NavigationRoute>[]),
  ['account'] => (tab: AppTab.account, stack: <NavigationRoute>[]),
  ['account', 'settings'] => (
    tab: AppTab.account,
    stack: <NavigationRoute>[Routes.settings],
  ),
  _ => null,
};

/* #endregion */

/* #region 2. A table of regular expressions */

/// A table of `(pattern, builder)` pairs, the first match wins.
///
/// Handy when the links are many, come from the backend or from marketing,
/// and are easier to maintain as data than as code.
final List<(RegExp, DeepLink Function(RegExpMatch match))> deepLinkTable =
    <(RegExp, DeepLink Function(RegExpMatch match))>[
      (
        RegExp(r'^/shop/product/(?<id>\d+)/?$'),
        (match) => (
          tab: AppTab.shop,
          stack: <NavigationRoute>[
            ProductRoute(int.parse(match.namedGroup('id')!)),
          ],
        ),
      ),
      (
        RegExp(r'^/shop/filters/?$'),
        (_) =>
            (tab: AppTab.shop, stack: <NavigationRoute>[const FiltersRoute()]),
      ),
      (
        RegExp(r'^/account/settings/?$'),
        (_) => (tab: AppTab.account, stack: <NavigationRoute>[Routes.settings]),
      ),
      (
        RegExp(r'^/(?<tab>shop|cart|account)?/?$'),
        (match) => (
          tab: AppTab.values.byName(match.namedGroup('tab') ?? 'shop'),
          stack: <NavigationRoute>[],
        ),
      ),
    ];

/// Resolves [uri] with the [deepLinkTable].
DeepLink? parseDeepLinkWithTable(Uri uri) {
  final path = uri.path.isEmpty ? '/' : uri.path;
  for (final (pattern, build) in deepLinkTable) {
    final match = pattern.firstMatch(path);
    if (match != null) return build(match);
  }
  return null;
}

/* #endregion */

/* #region 3. Every segment is a route */

/// Every segment of the path becomes a route of the stack:
/// `/shop/product-3/product-4/filters` opens the product 3, the product 4
/// above it and the filters on top.
///
/// The most flexible option: any combination of the screens can be linked
/// without declaring it in advance, and the address mirrors the stack, which
/// is exactly what the web expects. The guards still have the last word, so
/// a nonsensical combination is fixed by them the same way as a mistake in
/// the code would be.
DeepLink? parseDeepLinkBySegments(Uri uri) {
  final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
  if (segments.isEmpty) return (tab: AppTab.shop, stack: <NavigationRoute>[]);
  final tab = AppTab.values.asNameMap()[segments.first];
  if (tab == null) return null;
  final stack = <NavigationRoute>[];
  for (final segment in segments.skip(1)) {
    final route = switch (segment.split('-')) {
      ['product', final id] when int.tryParse(id) != null => ProductRoute(
        int.parse(id),
      ),
      ['filters'] => const FiltersRoute(),
      ['settings'] => Routes.settings,
      // An unknown segment is skipped instead of failing the whole link.
      _ => null,
    };
    if (route != null) stack.add(route);
  }
  return (tab: tab, stack: stack);
}

/* #endregion */

/// Opens [link] in [tabs]: the routes of the link are put on top of the root
/// of the tab, and the tab is selected.
///
/// The stack is replaced as a whole, so the guards validate the final
/// result only once: a signed out user still lands on the sign in screen.
void openDeepLink(NavigationTabsController<AppTab> tabs, DeepLink link) {
  tabs[link.tab].change(
    (stack) => <NavigationRoute>[stack.first, ...link.stack],
  );
  tabs.select(link.tab, popToRoot: false);
}
