import 'package:example/src/authentication.dart';
import 'package:example/src/deep_links.dart';
import 'package:example/src/routes.dart';
import 'package:example/src/tabs_scope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:squid/squid.dart';

/// {@template example.app}
/// Root widget of the example.
///
/// It owns one [NavigationController] per tab and a
/// [NavigationTabsController] that keeps them together.
/// {@endtemplate}
class App extends StatefulWidget {
  /// {@macro example.app}
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  late final NavigationTabsController<AppTab> _tabs;

  @override
  void initState() {
    super.initState();
    final authentication = Authentication.instance;
    _tabs = NavigationTabsController<AppTab>(
      tabs: <AppTab, NavigationController>{
        for (final tab in AppTab.values)
          tab: NavigationController(
            <NavigationRoute>[_root(tab)],
            debugLabel: tab.name,
            // The order matters: every guard receives the result
            // of the previous one.
            guards: <NavigationGuard>[
              // 1. The root of the tab is always at the bottom, so going
              //    back always leads to it and never out of the tab.
              RootGuard(() => _root(tab)),
              // 2. Nobody gets further than the sign in screen while the
              //    user is signed out. It runs after the root guard, and
              //    therefore has the last word about the root screen.
              GateGuard(
                isOpen: () => authentication.isSignedIn,
                tag: Routes.tagUnauthenticated,
                closed: () => <NavigationRoute>[Routes.signIn],
                opened: () => <NavigationRoute>[_root(tab)],
              ),
              // 3. Dialogs and sheets always float on top.
              const PriorityGuard(),
              // 4. A user cannot build an endless stack of products.
              const LimitGuard(16),
            ],
            // Re-run the guards whenever the authentication changes.
            revalidate: authentication,
            observers: <NavigationObserver>[
              if (kDebugMode) const NavigationLogger(),
            ],
          ),
      },
    );

    // The link the application has been launched with.
    final initial = initialDeepLink();
    if (initial != null) _openDeepLink(initial);
    // The links that arrive while the application is running.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) =>
      SynchronousFuture<bool>(_openDeepLink(routeInformation.uri));

  /// Returns `false` for an unknown link, so that the platform can handle it
  /// instead, e.g. open it in the browser.
  bool _openDeepLink(Uri uri) {
    // Any of the three parsers of `deep_links.dart` fits here.
    final link = parseDeepLinkWithSwitch(uri);
    if (link == null) return false;
    openDeepLink(_tabs, link);
    return true;
  }

  static NavigationRoute _root(AppTab tab) => switch (tab) {
    AppTab.shop => Routes.catalog,
    AppTab.cart => Routes.cart,
    AppTab.account => Routes.account,
  };

  late final Widget _home = AppTabsScope(
    tabs: _tabs,
    child: const _HomeScreen(),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Squid',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorSchemeSeed: Colors.teal,
      brightness: Brightness.light,
    ),
    darkTheme: ThemeData(
      colorSchemeSeed: Colors.teal,
      brightness: Brightness.dark,
    ),
    // The deep link is handled by the controllers, not by `MaterialApp`:
    // without this callback it would try to open the link as a named route
    // and report that there is no such route.
    onGenerateInitialRoutes: (_) => <Route<void>>[
      MaterialPageRoute<void>(builder: (_) => _home),
    ],
    // No named routes: the navigation lives in the controllers.
    onGenerateRoute: (_) => null,
  );
}

/// Bottom navigation bar with one [NavigationView] per tab.
class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    final tabs = AppTabsScope.of(context);
    return ListenableBuilder(
      listenable: tabs,
      builder: (context, _) => Scaffold(
        // Every tab keeps its stack alive while the other one is visible.
        body: IndexedStack(
          index: tabs.activeIndex,
          children: <Widget>[
            for (final controller in tabs.tabs.values)
              NavigationView(controller: controller),
          ],
        ),
        // The sign in screen takes the whole window.
        bottomNavigationBar: tabs.controller.top == Routes.signIn
            ? null
            : NavigationBar(
                selectedIndex: tabs.activeIndex,
                onDestinationSelected: (index) =>
                    tabs.select(AppTab.values[index]),
                destinations: const <Widget>[
                  NavigationDestination(
                    icon: Icon(Icons.storefront_outlined),
                    selectedIcon: Icon(Icons.storefront),
                    label: 'Shop',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.shopping_cart_outlined),
                    selectedIcon: Icon(Icons.shopping_cart),
                    label: 'Cart',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Account',
                  ),
                ],
              ),
      ),
    );
  }
}
