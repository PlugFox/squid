import 'package:flutter/material.dart';
import 'package:squid/src/pages.dart';
import 'package:squid/src/route.dart';

/// Tag added to every route that covers the screen with a barrier:
/// dialogs, bottom sheets and any other popup.
///
/// Makes it possible to close all of them at once without knowing
/// their types:
///
/// ```dart
/// controller.removeTag(kModalTag);
/// ```
const String kModalTag = 'modal';

/// {@template squid.dialog_route_mixin}
/// Turns a [NavigationRoute] into a modal dialog.
///
/// ```dart
/// final class ConfirmDialog extends AppRoute with DialogRouteMixin {
///   const ConfirmDialog({required this.question});
///
///   final String question;
///
///   @override
///   LocalKey get key => const ValueKey<String>('confirm');
///
///   @override
///   Widget build(BuildContext context) => AlertDialog(
///         content: Text(question),
///         actions: <Widget>[
///           TextButton(
///             onPressed: () => context.navigation.pop(true),
///             child: const Text('Yes'),
///           ),
///         ],
///       );
/// }
/// ```
///
/// The route is tagged with [kModalTag] and gets a positive [priority], so
/// the `PriorityGuard` keeps it above the regular screens.
/// {@endtemplate}
mixin DialogRouteMixin on NavigationRoute {
  /// Whether a tap on the barrier closes the dialog.
  bool get barrierDismissible => true;

  /// Color of the barrier behind the dialog.
  Color? get barrierColor => Colors.black54;

  /// Whether the dialog content is wrapped with a [SafeArea].
  bool get useSafeArea => true;

  @override
  Set<String> get tags => const <String>{kModalTag, 'dialog'};

  @override
  int get priority => 1;

  @override
  Page<Object?> page(BuildContext context) => DialogPage<Object?>(
    key: key,
    name: name,
    arguments: arguments,
    builder: build,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    useSafeArea: useSafeArea,
  );
}

/// {@template squid.bottom_sheet_route_mixin}
/// Turns a [NavigationRoute] into a modal bottom sheet.
///
/// ```dart
/// final class FiltersSheet extends AppRoute with BottomSheetRouteMixin {
///   const FiltersSheet();
///
///   @override
///   bool get isScrollControlled => true;
///
///   @override
///   Widget build(BuildContext context) => const FiltersView();
/// }
/// ```
///
/// The route is tagged with [kModalTag] and gets a positive [priority], so
/// the `PriorityGuard` keeps it above the regular screens.
/// {@endtemplate}
mixin BottomSheetRouteMixin on NavigationRoute {
  /// Whether the sheet can take the full height of the screen.
  bool get isScrollControlled => false;

  /// Whether a tap on the barrier closes the sheet.
  bool get isDismissible => true;

  /// Whether the sheet can be closed by a downwards drag.
  bool get enableDrag => true;

  /// Whether to show the material drag handle.
  bool? get showDragHandle => null;

  /// Whether the sheet avoids system intrusions on the top, left and right.
  bool get useSafeArea => false;

  /// Shape of the sheet.
  ShapeBorder? get shape => null;

  /// Size constraints of the sheet.
  BoxConstraints? get constraints => null;

  @override
  Set<String> get tags => const <String>{kModalTag, 'bottom_sheet'};

  @override
  int get priority => 1;

  @override
  Page<Object?> page(BuildContext context) => BottomSheetPage<Object?>(
    key: key,
    name: name,
    arguments: arguments,
    builder: build,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    shape: shape,
    constraints: constraints,
  );
}

/// {@template squid.no_transition_route_mixin}
/// Removes the transition animation of a [NavigationRoute].
///
/// Handy for the root screens of tabs and for screens that are swapped by a
/// guard, where an animation would look like a glitch.
/// {@endtemplate}
mixin NoTransitionRouteMixin on NavigationRoute {
  @override
  Page<Object?> page(BuildContext context) => NoTransitionPage<Object?>(
    key: key,
    name: name,
    arguments: arguments,
    child: Builder(builder: build),
  );
}
