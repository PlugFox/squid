/// A simple, reliable and extensible declarative navigator for Flutter.
///
/// The whole navigation is a plain list of routes: rewrite the list and the
/// screens follow. Guards validate every change, so the rules of the
/// application are declared once instead of being repeated at every call
/// site.
library;

export 'package:squid/src/controller.dart'
    show NavigationChange, NavigationController;
export 'package:squid/src/extensions.dart';
export 'package:squid/src/guard.dart';
export 'package:squid/src/guards.dart';
export 'package:squid/src/observer.dart';
export 'package:squid/src/pages.dart';
export 'package:squid/src/route.dart';
export 'package:squid/src/route_mixins.dart';
export 'package:squid/src/tabs.dart';
export 'package:squid/src/view.dart';
