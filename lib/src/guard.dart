import 'package:flutter/widgets.dart';
import 'package:squid/src/controller.dart';
import 'package:squid/src/route.dart';

/// Signature of a function that validates the navigation stack.
///
/// See [NavigationGuard] for the details.
typedef NavigationGuardCallback =
    NavigationStack Function(
      NavigationController controller,
      NavigationStack stack,
    );

/// {@template squid.guard}
/// A validator of the navigation stack.
///
/// A guard receives the stack the application *wants* to show and returns the
/// stack that will actually be shown. It is a pure function of the stack, so
/// it is trivial to reason about and to unit test:
///
/// ```dart
/// NavigationGuard(
///   (controller, stack) => authentication.isSignedIn
///       ? stack.without(Routes.signIn)
///       : <NavigationRoute>[Routes.signIn],
/// );
/// ```
///
/// Guards run on **every** change of the stack and every time the
/// `revalidate` listenable of the controller notifies, so they are the right
/// place for the rules that must always hold: "an unauthenticated user can
/// only see the sign in screen", "the home screen is always at the bottom",
/// "dialogs float above the screens", "the paywall disappears as soon as the
/// subscription is active".
///
/// A guard may return:
/// * the same stack — nothing changes;
/// * a different stack — the navigation is redirected;
/// * `controller.stack` — the change is cancelled.
///
/// A route closed by the user — a swipe back, a tap on the barrier of a
/// dialog — has already left the navigator when the guards see its removal.
/// A guard keeping it brings back a new instance of the route, with a new
/// state. To prevent the user from closing a route, use a [PopScope] or the
/// `canPop` of its page instead.
///
/// While a change is validated, `controller.stack` is the stack committed
/// before it. The only exception is the validation of the initial stack in
/// the constructor, where `controller.stack` is already the requested stack.
///
/// Guards are applied in the order they are declared, each one receiving the
/// result of the previous one. An exception thrown by a guard is reported
/// to `FlutterError` and the guard is skipped, so a broken rule cannot break
/// the navigation of the whole application.
///
/// A guard that needs the widget tree — the size of the window, the theme,
/// an inherited scope with the dependencies of the application — reads it
/// through `controller.context`, or extends [ContextGuard] which does it for
/// you. Such a read subscribes the navigator to that inherited widget, so
/// the guards run again whenever it changes.
///
/// A guard that needs its own state — a dependency, a counter, a "shown
/// once" latch — is a class implementing this interface:
///
/// ```dart
/// class PaywallGuard implements NavigationGuard {
///   PaywallGuard(this._payment);
///
///   final PaymentController _payment;
///   bool _shown = false;
///
///   @override
///   NavigationStack call(
///     NavigationController controller,
///     NavigationStack stack,
///   ) {
///     if (_payment.hasSubscription) return stack.withoutTag('paywall');
///     if (_shown) return stack;
///     _shown = true;
///     return <NavigationRoute>[...stack, Routes.paywall];
///   }
/// }
/// ```
/// {@endtemplate}
// A single member interface is intentional here: a guard is a function with
// a name, a state and a place in the type system.
// ignore: one_member_abstracts
abstract interface class NavigationGuard {
  /// Creates a guard from a plain function.
  ///
  /// {@macro squid.guard}
  const factory NavigationGuard(NavigationGuardCallback callback) =
      _CallbackGuard;

  /// Validates [stack] and returns the stack to show.
  NavigationStack call(NavigationController controller, NavigationStack stack);
}

/// A guard built from a plain function.
class _CallbackGuard implements NavigationGuard {
  const _CallbackGuard(this._callback);

  final NavigationGuardCallback _callback;

  @override
  NavigationStack call(
    NavigationController controller,
    NavigationStack stack,
  ) => _callback(controller, stack);

  @override
  String toString() => 'NavigationGuard()';
}

/// {@template squid.context_guard}
/// A guard that depends on the widget tree.
///
/// Extend it when the rule is about the *environment* rather than about the
/// application state: the size of the window, the orientation, the theme, an
/// inherited scope with the dependencies:
///
/// ```dart
/// class AdaptiveGuard extends ContextGuard {
///   const AdaptiveGuard();
///
///   @override
///   NavigationStack guard(BuildContext context, NavigationStack stack) =>
///       MediaQuery.sizeOf(context).width >= 900
///           ? stack // the detail pane is shown next to the master one
///           : stack.withoutTag('side-pane');
/// }
/// ```
///
/// Reading an inherited widget here subscribes the [NavigationView] to it,
/// so the guards are re-run on every change of the window size, of the
/// theme or of the scope — there is nothing else to wire up.
///
/// The guard is skipped while no widget renders the controller: there is no
/// context to read yet. It runs again as soon as one is mounted, which is
/// before the first frame.
/// {@endtemplate}
abstract class ContextGuard implements NavigationGuard {
  /// {@macro squid.context_guard}
  const ContextGuard();

  /// Validates [stack] with the context of the widget rendering the
  /// controller.
  NavigationStack guard(BuildContext context, NavigationStack stack);

  @override
  NavigationStack call(NavigationController controller, NavigationStack stack) {
    final context = controller.context;
    return context == null ? stack : guard(context, stack);
  }

  @override
  String toString() => 'ContextGuard()';
}
