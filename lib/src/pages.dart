import 'package:flutter/material.dart';

/// {@template squid.dialog_page}
/// A [Page] that shows its content as a modal dialog.
///
/// It is the declarative counterpart of [showDialog]: instead of an
/// imperative call that lives outside of the navigation state, the dialog is
/// just another entry of the [NavigationStack] and can be added, removed and
/// inspected by guards like any other route.
/// {@endtemplate}
class DialogPage<T> extends Page<T> {
  /// {@macro squid.dialog_page}
  const DialogPage({
    required this.builder,
    this.barrierDismissible = true,
    this.barrierColor = Colors.black54,
    this.barrierLabel,
    this.useSafeArea = true,
    this.anchorPoint,
    this.traversalEdgeBehavior,
    this.animationStyle,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    super.canPop,
    super.onPopInvoked,
  });

  /// Builds the content of the dialog.
  final WidgetBuilder builder;

  /// Whether a tap on the barrier closes the dialog.
  final bool barrierDismissible;

  /// Color of the barrier behind the dialog.
  final Color? barrierColor;

  /// Semantic label of the barrier, used by accessibility frameworks.
  final String? barrierLabel;

  /// Whether the dialog content is wrapped with a [SafeArea].
  final bool useSafeArea;

  /// The point used to pick the sub screen on a device with a hinge or a
  /// fold, see [DisplayFeatureSubScreen.anchorPoint].
  final Offset? anchorPoint;

  /// How the focus traversal behaves at the edges of the route.
  final TraversalEdgeBehavior? traversalEdgeBehavior;

  /// Animation style of the dialog transition.
  final AnimationStyle? animationStyle;

  @override
  Route<T> createRoute(BuildContext context) => DialogRoute<T>(
    context: context,
    settings: this,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    anchorPoint: anchorPoint,
    traversalEdgeBehavior: traversalEdgeBehavior,
    animationStyle: animationStyle,
  );
}

/// {@template squid.bottom_sheet_page}
/// A [Page] that shows its content as a modal bottom sheet.
///
/// It is the declarative counterpart of [showModalBottomSheet]: the sheet is
/// a normal entry of the [NavigationStack], so it survives rebuilds, can be
/// restored after a deep link and can be closed by a guard.
/// {@endtemplate}
class BottomSheetPage<T> extends Page<T> {
  /// {@macro squid.bottom_sheet_page}
  const BottomSheetPage({
    required this.builder,
    this.isScrollControlled = false,
    this.isDismissible = true,
    this.enableDrag = true,
    this.showDragHandle,
    this.useSafeArea = false,
    this.backgroundColor,
    this.barrierColor,
    this.barrierLabel,
    this.elevation,
    this.shape,
    this.clipBehavior,
    this.constraints,
    this.anchorPoint,
    this.sheetAnimationStyle,
    this.scrollControlDisabledMaxHeightRatio = 9.0 / 16.0,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    super.canPop,
    super.onPopInvoked,
  });

  /// Builds the content of the sheet.
  final WidgetBuilder builder;

  /// Whether the sheet can take the full height of the screen.
  final bool isScrollControlled;

  /// Whether a tap on the barrier closes the sheet.
  final bool isDismissible;

  /// Whether the sheet can be closed by a downwards drag.
  final bool enableDrag;

  /// Whether to show the material drag handle.
  final bool? showDragHandle;

  /// Whether the sheet avoids system intrusions on the top, left and right.
  final bool useSafeArea;

  /// Background color of the sheet.
  final Color? backgroundColor;

  /// Color of the barrier behind the sheet.
  final Color? barrierColor;

  /// Semantic label of the barrier, used by accessibility frameworks.
  final String? barrierLabel;

  /// Elevation of the sheet.
  final double? elevation;

  /// Shape of the sheet.
  final ShapeBorder? shape;

  /// Content clip behavior of the sheet.
  final Clip? clipBehavior;

  /// Size constraints of the sheet.
  final BoxConstraints? constraints;

  /// The point used to pick the sub screen on a device with a hinge or a
  /// fold, see [DisplayFeatureSubScreen.anchorPoint].
  final Offset? anchorPoint;

  /// Animation style of the sheet transition.
  final AnimationStyle? sheetAnimationStyle;

  /// Max height ratio when [isScrollControlled] is `false`.
  final double scrollControlDisabledMaxHeightRatio;

  @override
  Route<T> createRoute(BuildContext context) => ModalBottomSheetRoute<T>(
    settings: this,
    builder: builder,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor,
    modalBarrierColor:
        barrierColor ?? Theme.of(context).bottomSheetTheme.modalBarrierColor,
    barrierLabel: barrierLabel ?? MaterialLocalizations.of(context).scrimLabel,
    elevation: elevation,
    shape: shape,
    clipBehavior: clipBehavior,
    constraints: constraints,
    anchorPoint: anchorPoint,
    sheetAnimationStyle: sheetAnimationStyle,
    scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
  );
}

/// {@template squid.no_transition_page}
/// A [Page] without any transition animation.
///
/// Useful for the root screens of tabs, where a cross-fade or a slide would
/// look out of place, and for tests.
/// {@endtemplate}
class NoTransitionPage<T> extends Page<T> {
  /// {@macro squid.no_transition_page}
  const NoTransitionPage({
    required this.child,
    this.maintainState = true,
    this.fullscreenDialog = false,
    this.opaque = true,
    this.barrierColor,
    this.barrierDismissible = false,
    this.barrierLabel,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    super.canPop,
    super.onPopInvoked,
  });

  /// Content of the page.
  final Widget child;

  /// Whether the content stays in the tree while another route covers it.
  final bool maintainState;

  /// Whether the route is a full screen modal dialog.
  final bool fullscreenDialog;

  /// Whether the route obscures the routes below it.
  final bool opaque;

  /// Color of the barrier behind the route, `null` for no barrier.
  final Color? barrierColor;

  /// Whether a tap on the barrier closes the route.
  final bool barrierDismissible;

  /// Semantic label of the barrier, used by accessibility frameworks.
  final String? barrierLabel;

  @override
  Route<T> createRoute(BuildContext context) => _NoTransitionRoute<T>(this);
}

/// Route without transition animations, created by [NoTransitionPage].
class _NoTransitionRoute<T> extends PageRoute<T> {
  _NoTransitionRoute(NoTransitionPage<T> page)
    : super(settings: page, fullscreenDialog: page.fullscreenDialog);

  NoTransitionPage<T> get _page => settings as NoTransitionPage<T>;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get opaque => _page.opaque;

  @override
  Color? get barrierColor => _page.barrierColor;

  @override
  bool get barrierDismissible => _page.barrierDismissible;

  @override
  String? get barrierLabel => _page.barrierLabel;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _page.child;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
