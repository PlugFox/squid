import 'package:example/src/screens.dart';
import 'package:flutter/material.dart';
import 'package:squid/squid.dart';

/// Tabs of the application, every one of them owns its own stack.
enum AppTab { shop, cart, account }

/// The simple, parameterless routes of the application.
///
/// An enum is enough when a route is just "that screen": the name, the key
/// and the equality come for free.
enum Routes with NavigationRoute {
  /// Root of the shop tab.
  catalog,

  /// Root of the cart tab.
  cart,

  /// Root of the account tab.
  account,

  /// Sign in screen, the gate of the application.
  signIn,

  /// Regular screen pushed on top of the account tab.
  settings;

  /// Marks the screens a signed out user is allowed to see.
  static const String tagUnauthenticated = 'unauthenticated';

  @override
  Set<String> get tags => switch (this) {
    Routes.signIn => const <String>{tagUnauthenticated},
    _ => const <String>{},
  };

  /// The roots of the tabs must always stay at the bottom of their stack.
  @override
  int get priority => switch (this) {
    Routes.catalog || Routes.cart || Routes.account || Routes.signIn => -1,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) => switch (this) {
    Routes.catalog => const CatalogScreen(),
    Routes.cart => const CartScreen(),
    Routes.account => const AccountScreen(),
    Routes.signIn => const SignInScreen(),
    Routes.settings => const SettingsScreen(),
  };
}

/// The routes that carry parameters.
///
/// A sealed class keeps them typed: no string maps, no casts, and the
/// compiler checks every `switch` over the hierarchy.
sealed class AppRoute with NavigationRoute {
  const AppRoute();
}

/// Details of a single product.
final class ProductRoute extends AppRoute {
  /// Creates a route to the product [id].
  const ProductRoute(this.id);

  /// Identifier of the product.
  final int id;

  @override
  String get name => 'product';

  /// Every product is a separate entry of the stack, so the key must
  /// include the identifier.
  @override
  LocalKey get key => ValueKey<String>('product/$id');

  @override
  Map<String, Object?> get arguments => <String, Object?>{'id': id};

  @override
  Widget build(BuildContext context) => ProductScreen(id: id);
}

/// A dialog is a route as well: it lives in the stack, guards can see it and
/// remove it, and it cannot get out of sync with the navigation.
final class ConfirmRoute extends AppRoute with DialogRouteMixin {
  /// Asks the user to confirm [question].
  const ConfirmRoute(this.question);

  /// The question shown to the user.
  final String question;

  @override
  String get name => 'confirm';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Are you sure?'),
    content: Text(question),
    actions: <Widget>[
      TextButton(
        onPressed: () => context.navigation.pop(false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => context.navigation.pop(true),
        child: const Text('Confirm'),
      ),
    ],
  );
}

/// A bottom sheet is a route too.
final class FiltersRoute extends AppRoute with BottomSheetRouteMixin {
  /// Opens the filters of the catalog.
  const FiltersRoute();

  @override
  String get name => 'filters';

  @override
  bool get isScrollControlled => true;

  @override
  bool? get showDragHandle => true;

  @override
  Widget build(BuildContext context) => const FiltersView();
}
