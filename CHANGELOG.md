# Changelog

All notable changes to this project will be documented in this file.

## 0.1.1

- **Fixed**: on Android with the predictive back gesture, the back button
  no longer closes the application when a `NavigationTabsController` can
  return to the previous tab or a `NavigationView` has its own
  `onBackButtonPressed`: the view tells the platform that the framework
  handles the press, and an inactive tab no longer speaks for the visible
  one.
- **Fixed**: a page built from the context of the view (the locale, the
  theme, an inherited scope read in `NavigationRoute.page`) is built again
  when that context changes instead of being taken from the cache.
- **Fixed**: the default `key` of a route escapes `%`, `&` and `=` in the
  arguments and writes a `null` argument without a value, so different
  arguments, e.g. `{'q': 'a&b=c'}` and `{'q': 'a', 'b': 'c'}`, or `null` and
  `'null'`, no longer produce the same key.
- **Fixed**: observers are notified at the end of the frame, together with
  the listeners, when a `ContextGuard` changes the stack during the build,
  so an observer calling `setState` no longer throws.
- **Fixed**: an exception in one callback of an observer no longer swallows
  the remaining events of the same transition for that observer.
- **Fixed**: a guard returning an empty stack is reported to `FlutterError`
  instead of throwing an assertion, which dropped the changes queued after
  it in a debug build.
- **Fixed**: `pop` and `removeKey` called from a guard, an observer or a
  listener are postponed instead of being checked against the stack that is
  about to change, e.g. `push(route)` followed by `remove(route)`.
- **Fixed**: the result of a `pop` cancelled by a guard is no longer passed
  to a later removal of the same route.
- **Fixed**: a guard disposing the controller no longer leads to a
  notification of a disposed controller.
- **Docs**: a guard keeping a route closed by the user brings back a new
  instance of it, use a `PopScope` to prevent the closing.
- **Docs**: the name of a class route is minified in an obfuscated build,
  routes compare by instance in a plain `List`, overridden `tags` must keep
  `kModalTag`, `pushForResult` completes the previous waiter of the same
  route with `null`, `controller.stack` while the guards run.
- **CI**: a manual publication must start from the tag of the version, the
  pub cache depends on the pubspecs, a `.pubignore` keeps the development
  files out of the package.

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
