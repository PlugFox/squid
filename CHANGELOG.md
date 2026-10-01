# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

- **Docs**: "Helpers of your application" — an extension type over
  `BuildContext` with application specific shortcuts and `popModals`, which
  closes the declarative and the imperative popups at once.
- **Docs**: "Deep links" — the initial link from the binding, the links
  received while running, and three ways to parse a link into a stack.
- **Example**: `context.nav`, `popModals` and deep links with tests.
- **Fixed**: the system back button now reaches the deepest visible nested
  `NavigationView` first; previously the outer view closed the whole nested
  flow at once.
- **Fixed**: a nested `NavigationView` covered by a route or a dialog of the
  outer navigator no longer reacts to the back button, and
  `interceptBackButton: false` disables the nested views as well.
- **Fixed**: `Navigator.pop(context, result)` completes `pushForResult` with
  `result` instead of `null`.
- **Fixed**: a route closed by the user and kept by a guard is brought back on
  screen instead of leaving the navigator out of sync with the controller.
- **Fixed**: a `pushForResult` requested from a listener, a guard or an
  observer and then rejected by a guard completes with `null` instead of
  never.
- **Fixed**: the result of a `pop` cancelled by a guard is no longer delivered
  by a later removal of the same route, and a postponed `pop` binds its
  result to the route it actually removes.
- **Fixed**: disposing the controller from an observer no longer applies the
  remaining queued changes to a disposed controller.
- **Fixed**: a `ContextGuard` changing the stack when the window size, the
  theme or a scope changes no longer throws `setState() or markNeedsBuild()
  called during build` in a widget above the view that listens to the
  controller (e.g. the shell of the tabs): the view renders the new stack in
  the same frame, the listeners are notified at the end of it.
- **Changed**: `onBackButtonPressed` is called only when the press reaches
  the view: not for an inactive tab and not when a nested view has handled
  it. `NavigationScope` is no longer a `const` constructor.
- **Fixed**: `GateGuard` with an open gate replaces an empty stack with
  `opened()`, the same way a closed gate falls back to `closed()`.
- **Fixed**: replacing the controller of a `NavigationView` runs its guards
  with the context of the view, so a `ContextGuard` sees it immediately.

## 0.1.0

- Initial release.
- `NavigationRoute` — a route is an immutable value: an `enum` value when it
  has no parameters, a `sealed class` when it has.
- `NavigationController` — the owner of the stack, usable without any widget,
  with guards, observers and revalidation built in.
- `NavigationView` — renders a controller with a `Navigator`, reports the
  routes closed by the user and handles the system back button.
- `DialogRouteMixin` and `BottomSheetRouteMixin` — dialogs and bottom sheets
  as ordinary entries of the navigation stack.
- `NavigationGuard` with the built-in `PriorityGuard`, `RootGuard`,
  `LimitGuard` and `GateGuard`.
- `ContextGuard` — the rules that depend on the widget tree (the size of the
  window, the theme, an inherited scope) re-run by themselves whenever what
  they read changes.
- `NavigationObserver` and `NavigationLogger`.
- `NavigationTabsController` — several stacks side by side, cross tab
  navigation and automatic routing of the back button.
