# Changelog

All notable changes to this project will be documented in this file.

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
