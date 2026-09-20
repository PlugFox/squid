# Squid: A Declarative Navigator for Flutter

[![Pub](https://img.shields.io/pub/v/squid.svg)](https://pub.dev/packages/squid)
[![Actions Status](https://github.com/PlugFox/squid/actions/workflows/checkout.yml/badge.svg)](https://github.com/PlugFox/squid/actions)
[![Coverage](https://codecov.io/gh/PlugFox/squid/branch/master/graph/badge.svg)](https://codecov.io/gh/PlugFox/squid)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![Linter](https://img.shields.io/badge/style-linter-40c4ff.svg)](https://pub.dev/packages/linter)
[![GitHub stars](https://img.shields.io/github/stars/plugfox/squid?style=social)](https://github.com/plugfox/squid/)

**The whole navigation is a list of routes. Rewrite the list — the screens follow.**

```dart
controller.change((stack) => <NavigationRoute>[
      Routes.home,
      const ProductRoute(42),
    ]);
```

There is no hidden state, no route table to keep in sync, no imperative
`push` / `pop` pairs to balance. There is a list, a widget that renders it,
and the guards that decide what the list is allowed to look like.

---

## Table of contents

- [Why](#why) · [Installation](#installation) · [Quick start](#quick-start)
- [Routes](#routes) — [with parameters](#routes-with-parameters),
  [dialogs and sheets](#dialogs-and-bottom-sheets)
- [Navigating](#navigating) · [Guards](#guards) ·
  [Observers](#observers) · [Tabs](#tabs)
- [The back button](#the-back-button) · [Testing](#testing)
- [Coming from octopus](#coming-from-octopus) ·
  [Design notes](#design-notes)

## Why

Most routers describe the navigation as a set of destinations and let the
user walk between them one command at a time. It works until the moment the
application needs to say something about the navigation *as a whole*: "a
signed out user sees the sign in screen and nothing else", "the paywall
closes the moment the subscription is active", "dialogs always float above
the screens", "going back never leaves the tab".

With a declarative stack those rules are ordinary code over an ordinary
list — written once, applied everywhere, testable without a widget tree.

- 🧾 **The state is a list.** `List<NavigationRoute>`, nothing else. Whatever
  you can do to a list, you can do to your navigation.
- 🛡️ **Guards.** Pure functions that validate every change of the stack and
  re-run whenever the state they depend on changes.
- 🧩 **Routes are values.** An `enum` for the simple ones, a `sealed class`
  for the ones with parameters. Exhaustive `switch`, real types, no strings.
- 🪟 **Dialogs and bottom sheets are routes too.** No `showDialog` running
  next to the navigation and getting out of sync with it.
- 🗂️ **Many navigators, one application.** One controller per tab, and any
  tab can rewrite the stack of any other tab.
- 📐 **Adaptive.** A guard can read the window size, the theme or an
  inherited scope, and re-runs by itself whenever any of them changes.
- 🔌 **No magic.** No code generation, no singletons, no global state, no
  dependencies besides Flutter.
- 🧪 **Testable.** A controller is a plain `ChangeNotifier`: most of the
  navigation can be tested without pumping a single widget.

## Installation

```yaml
dependencies:
  squid: ^0.1.0
```

## Quick start

### 1. Declare the routes

An enum is enough when the routes have no parameters — the name, the key and
the equality come for free:

```dart
enum Routes with NavigationRoute {
  home,
  catalog,
  settings;

  @override
  Widget build(BuildContext context) => switch (this) {
        Routes.home => const HomeScreen(),
        Routes.catalog => const CatalogScreen(),
        Routes.settings => const SettingsScreen(),
      };
}
```

### 2. Create a controller

```dart
final controller = NavigationController(<NavigationRoute>[Routes.home]);
```

### 3. Render it

```dart
MaterialApp(
  home: NavigationView(controller: controller),
);
```

### 4. Navigate

```dart
context.navigation.push(Routes.settings);
context.navigation.pop();
context.navigation.change((stack) => stack.withoutTag(kModalTag));
```

That is the whole package. Everything below is the detail.

## Routes

A route is an **immutable description of a screen**, not a command that opens
it. The only required member is `build`.

| Member      | Default                            | What it is for                          |
| ----------- | ---------------------------------- | --------------------------------------- |
| `build`     | —                                  | The content of the route                |
| `name`      | enum value name / type name        | Debugging, analytics, the default key   |
| `key`       | `ValueKey(name + arguments)`       | Identity inside the stack               |
| `tags`      | `{}`                               | Addressing groups of routes in guards   |
| `priority`  | `0`                                | Ordering, applied by the `PriorityGuard`|
| `arguments` | `{}`                               | Untyped parameters, mostly for analytics|
| `page`      | `MaterialPage`                     | Transitions, dialogs, sheets            |

### Routes with parameters

Use a sealed class and keep the parameters typed. The **only** rule is that
such routes must override `key`, otherwise all the products in the world are
the same entry of the stack:

```dart
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
  Widget build(BuildContext context) => ProductScreen(id: id);
}
```

Two routes with the same key are the same screen: Flutter keeps its state
instead of recreating it, and pushing an already present route moves it to
the top of the stack instead of duplicating it.

### Dialogs and bottom sheets

A dialog is a route with another `page`, and the package ships the two
common ones:

```dart
final class ConfirmRoute extends AppRoute with DialogRouteMixin {
  const ConfirmRoute(this.question);

  final String question;

  @override
  Widget build(BuildContext context) => AlertDialog(
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

final confirmed = await context.navigation.pushForResult<bool>(
  const ConfirmRoute('Delete the account?'),
);
```

`pushForResult` completes with the value passed to `pop`, or with `null` when
the route is closed in any other way — a tap on the barrier, the system back
button or a guard. Both mixins tag their routes with `kModalTag` and give
them a positive priority, so `controller.removeTag(kModalTag)` closes every
popup at once and the `PriorityGuard` keeps them above the screens.

`BottomSheetRouteMixin` works the same way, and `NoTransitionRouteMixin`
removes the animation. For anything else override `page` and return whatever
`Page` you like — including your own `PageRoute` with a custom transition.

## Navigating

`change` is the only method that matters, the rest are shortcuts:

```dart
controller.change((stack) => <NavigationRoute>[...stack, Routes.settings]);

controller.push(Routes.settings);           // add on top
controller.pop();                           // remove the visible route
controller.popUntil((route) => route is ProductRoute);
controller.popToRoot();                     // keep the root only
controller.replaceTop(Routes.catalog);      // swap the visible route
controller.removeTag(kModalTag);            // close every popup
controller.removeWhere((route) => route is ProductRoute);
controller.stack = <NavigationRoute>[Routes.home, const ProductRoute(1)];
```

A deep link is not a special case — it is a stack:

```dart
void openDeepLink(Uri uri) => controller.stack = <NavigationRoute>[
      Routes.home,
      Routes.catalog,
      ProductRoute(int.parse(uri.pathSegments.last)),
    ];
```

Inside a widget the controller is one extension away:

```dart
context.navigation             // the closest controller
context.maybeNavigation        // ...or null
NavigationScope.stackOf(context) // the stack, rebuilds on every change
```

The stack itself has a small vocabulary of helpers that never modify the
receiver: `topOrNull`, `containsKey`, `containsTag`, `containsType<T>()`,
`findKey`, `findName`, `findType<T>()`, `whereTag`, `withoutTag`,
`withoutType<T>()`, `without`, `withRoute`.

## Guards

A guard receives the stack the application *wants* and returns the stack it
*gets*. It runs on every change and every time the state it depends on
notifies, which is exactly what makes the rules of the application
declarative:

```dart
final controller = NavigationController(
  <NavigationRoute>[Routes.home],
  guards: <NavigationGuard>[
    RootGuard(() => Routes.home),
    GateGuard(
      isOpen: () => authentication.isSignedIn,
      tag: 'unauthenticated',
      closed: () => <NavigationRoute>[Routes.signIn],
      opened: () => <NavigationRoute>[Routes.home],
    ),
    const PriorityGuard(),
    const LimitGuard(16),
  ],
  // Re-runs the guards when the user signs in or out.
  revalidate: authentication,
);
```

Nothing above says "navigate to the sign in screen". Signing out changes a
flag; the guard rewrites every stack that violates the new rule. That is the
whole point of the declarative model: **the rules live in one place and
cannot be forgotten at a call site.**

| Guard           | Rule                                                        |
| --------------- | ----------------------------------------------------------- |
| `PriorityGuard` | Sorts the stack by `priority`: modals float, roots sink      |
| `RootGuard`     | Keeps a route at the bottom and the stack non empty          |
| `LimitGuard`    | Limits the depth, dropping the oldest routes in the middle   |
| `GateGuard`     | Keeps the application behind a gate until a condition holds  |
| `ContextGuard`  | Base class for the rules that depend on the widget tree      |

A guard is either a function or a class with state:

```dart
// A function.
NavigationGuard((controller, stack) => stack.withoutType<DraftRoute>());

// A class, when it needs a dependency or a memory.
class PaywallGuard implements NavigationGuard {
  PaywallGuard(this._payment);

  final PaymentController _payment;
  bool _shown = false;

  @override
  NavigationStack call(
    NavigationController controller,
    NavigationStack stack,
  ) {
    if (_payment.hasSubscription) return stack.withoutTag('paywall');
    if (_shown || stack.containsTag('paywall')) return stack;
    _shown = true;
    return <NavigationRoute>[...stack, Routes.paywall];
  }
}
```

### Guards and the widget tree

Not every rule is about the application state. "The side pane exists only on
a wide window", "this screen is only for the dark theme", "the repository
lives in an inherited scope" — those need the context. Extend `ContextGuard`
and it is right there:

```dart
class AdaptiveGuard extends ContextGuard {
  const AdaptiveGuard();

  @override
  NavigationStack guard(BuildContext context, NavigationStack stack) =>
      MediaQuery.sizeOf(context).width >= 900
          ? stack.withRoute(const SidePaneRoute())
          : stack.withoutTag('side-pane');
}
```

Nothing else has to be wired up: reading an inherited widget from a guard
subscribes the navigator to it, so resizing the window, switching the theme
or updating the scope re-runs the guards with the new value. A navigator
whose guards read nothing from the context keeps no dependencies at all and
pays nothing for this.

The context of the widget rendering the controller is also available
directly, as `controller.context`, for the guards that need it only
sometimes. It is `null` while no widget is mounted — during the validation
of the initial stack, for example — and `ContextGuard` is simply skipped
until then.

Three things worth knowing:

1. **The order matters.** Guards are applied one after another, each one
   receiving the result of the previous one, so the guard that must have the
   last word goes last.
2. **Returning `controller.stack` cancels the change.** The controller has
   not committed anything yet when the guards run, so the previous stack is
   always available.
3. **A throwing guard is skipped**, reported to `FlutterError` and does not
   break the navigation.

## Observers

Guards decide, observers watch. Analytics, logging and the window title
belong here:

```dart
class AnalyticsObserver with NavigationObserver {
  AnalyticsObserver(this._analytics);

  final Analytics _analytics;

  @override
  void onAdd(NavigationController controller, NavigationRoute route) =>
      _analytics.logScreenView(route.name);
}

NavigationController(
  <NavigationRoute>[Routes.home],
  observers: <NavigationObserver>[
    AnalyticsObserver(analytics),
    if (kDebugMode) const NavigationLogger(),
  ],
);
```

## Tabs

A tab is just another stack, so a tabbed application is a map of
controllers:

```dart
final tabs = NavigationTabsController<AppTab>(
  tabs: <AppTab, NavigationController>{
    AppTab.shop: NavigationController(<NavigationRoute>[Routes.catalog]),
    AppTab.cart: NavigationController(<NavigationRoute>[Routes.cart]),
  },
);

ListenableBuilder(
  listenable: tabs,
  builder: (context, _) => Scaffold(
    body: IndexedStack(
      index: tabs.activeIndex,
      children: <Widget>[
        for (final controller in tabs.tabs.values)
          NavigationView(controller: controller),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tabs.activeIndex,
      onDestinationSelected: (index) => tabs.select(AppTab.values[index]),
      destinations: const <Widget>[...],
    ),
  ),
);
```

Because a controller is an ordinary object, one tab can rewrite the stack of
another one:

```dart
tabs[AppTab.cart].push(ProductRoute(id));
tabs.select(AppTab.cart, popToRoot: false);
```

The back button is routed automatically: the inactive tabs never react to
it, the active tab pops its stack, and when it has nothing left to pop the
controller returns to the previously selected tab instead of closing the
application. Selecting the tab that is already active pops it to the root —
pass `popToRoot: false` to keep the stack.

## The back button

`NavigationView` handles the system back button by asking the underlying
`Navigator` to pop, so `PopScope` and the imperative routes opened on top of
the declarative stack keep working. Override the behaviour when a screen
needs something else:

```dart
NavigationView(
  controller: controller,
  onBackButtonPressed: (controller) async {
    if (controller.top.tags.contains('checkout')) {
      controller.stack = <NavigationRoute>[Routes.home];
      return true;
    }
    return controller.maybePop();
  },
);
```

Set `interceptBackButton: false` for a view that must never react to it.

## Testing

Most of the navigation is tested without a widget tree at all:

```dart
test('a signed out user cannot leave the sign in screen', () {
  final controller = NavigationController(
    <NavigationRoute>[Routes.home],
    guards: <NavigationGuard>[
      GateGuard(
        isOpen: () => false,
        tag: 'unauthenticated',
        closed: () => <NavigationRoute>[Routes.signIn],
        opened: () => <NavigationRoute>[Routes.home],
      ),
    ],
  );

  controller.push(Routes.settings);

  expect(controller.stack, equals(<NavigationRoute>[Routes.signIn]));
});
```

A guard is a pure function, so it can also be called directly:

```dart
expect(
  const PriorityGuard()(controller, <NavigationRoute>[dialog, home]),
  equals(<NavigationRoute>[home, dialog]),
);
```

## Coming from octopus

[octopus](https://pub.dev/packages/octopus) is the ancestor of this package
and shares its philosophy — navigation as a state you mutate. Squid keeps
the ideas and drops the machinery:

| octopus                                   | squid                                  |
| ----------------------------------------- | -------------------------------------- |
| A tree of nodes with names and arguments  | A flat `List<NavigationRoute>`         |
| Nested navigation inside the state tree   | One controller per navigator           |
| Routes are matched by name at runtime     | Routes are the objects themselves      |
| The state is serialized into the URL      | No URL layer, a deep link is a stack   |
| Asynchronous guards, transactions, queue  | Synchronous pure guards                |
| A singleton router and a `RouterConfig`   | Plain objects you create and own       |

Choose octopus when the navigation tree must survive in the address bar and
the browser history. Choose squid when you want the declarative model
without the serialization layer — a mobile application, a nested navigator,
a tabbed shell.

## Design notes

- **An empty stack is impossible.** A change that would empty it is rejected.
- **Keys are unique.** Adding a route whose key is already present moves that
  route to the top instead of breaking the `Navigator`.
- **Nothing is notified twice.** A change that produces an equal stack is a
  no-op, so guards can be idempotent without fear.
- **Reentrancy is safe.** A change requested from a guard, an observer or a
  listener is applied right after the current one instead of corrupting it.
- **The controller outlives the widgets.** It can be created, mutated and
  inspected before the first frame and after the last one. The widget tree
  is an optional input of the guards, never a requirement.
- **Guards must be idempotent.** They run on every change, on every
  revalidation and every time an inherited widget they read changes, so
  `guard(guard(stack))` has to equal `guard(stack)`.

## Example

The [example](example) is a small shop with three tabs, an authentication
gate, a dialog that returns a value, a bottom sheet, cross tab navigation
and a stack limit — around 500 lines in total.

## Maintainers

- [Matiunin Mikhail aka Plague Fox](https://plugfox.dev)

## Funding

If you want to support the development of our library, there are several
ways you can do it:

- [Buy me a coffee](https://www.buymeacoffee.com/plugfox)
- [Support on Patreon](https://www.patreon.com/plugfox)
- [Subscribe through Boosty](https://boosty.to/plugfox)

We appreciate any form of support, whether it's a financial donation or just
a star on GitHub. It helps us to continue developing and improving our
library. Thank you for your support!

## [MIT License](https://opensource.org/licenses/MIT)
