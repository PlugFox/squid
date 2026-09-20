import 'package:flutter/material.dart';
import 'package:squid/squid.dart';

/// Enum based routes: the simplest possible way to declare a navigation.
enum Routes with NavigationRoute {
  home,
  catalog,
  settings,
  signIn;

  @override
  Set<String> get tags => switch (this) {
    Routes.home => const <String>{'root'},
    Routes.signIn => const <String>{'unauthenticated'},
    _ => const <String>{},
  };

  @override
  int get priority => switch (this) {
    Routes.home => -1,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(name)),
    body: Center(child: Text('screen:$name')),
  );
}

/// Class based routes: the way to go when a route has parameters.
sealed class AppRoute with NavigationRoute {
  const AppRoute();
}

final class ProductRoute extends AppRoute {
  const ProductRoute(this.id);

  final int id;

  @override
  String get name => 'product';

  @override
  LocalKey get key => ValueKey<String>('product/$id');

  @override
  Map<String, Object?> get arguments => <String, Object?>{'id': id};

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('product:$id')));
}

final class ConfirmDialogRoute extends AppRoute with DialogRouteMixin {
  const ConfirmDialogRoute();

  @override
  Widget build(BuildContext context) => AlertDialog(
    content: const Text('confirm?'),
    actions: <Widget>[
      TextButton(
        onPressed: () => context.navigation.pop(true),
        child: const Text('yes'),
      ),
      TextButton(
        onPressed: () => context.navigation.pop(false),
        child: const Text('no'),
      ),
    ],
  );
}

final class FiltersSheetRoute extends AppRoute with BottomSheetRouteMixin {
  const FiltersSheetRoute();

  @override
  bool get isScrollControlled => true;

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 200, child: Center(child: Text('filters')));
}

final class FastRoute extends AppRoute with NoTransitionRouteMixin {
  const FastRoute();

  @override
  Widget build(BuildContext context) => const Center(child: Text('fast'));
}

/// A controller that notifies about the changes of a flag,
/// used to test `revalidate`.
class Flag with ChangeNotifier {
  Flag({bool value = false}) : _value = value;

  bool _value;

  bool get value => _value;

  set value(bool value) {
    if (_value == value) return;
    _value = value;
    notifyListeners();
  }
}
