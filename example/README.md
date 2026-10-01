# Squid example

A small shop that uses every feature of the package:

- `lib/src/routes.dart` — enum routes, a sealed class route with a
  parameter, a dialog route and a bottom sheet route.
- `lib/src/app.dart` — three tabs, one `NavigationController` each, with the
  guards that keep them consistent.
- `lib/src/screens.dart` — the screens, including a dialog that returns a
  value and a product that is added to the stack of another tab.
- `lib/src/navigation.dart` — `context.nav`, an extension type with the
  navigation shortcuts of the application and `popModals`, which closes the
  declarative and the imperative popups at once.
- `lib/src/deep_links.dart` — the link the application has been launched
  with and three ways to parse a link: a `switch` over the path segments, a
  table of regular expressions, and every segment as a route.
- `test/app_test.dart` — the whole flow of the application as a widget test.
- `test/deep_links_test.dart` — the parsers, a launch from a link, a link
  received while running and a link blocked by the authentication gate.

On the web, open a deep link such as `/#/shop/product/3` in the address
bar.

```bash
flutter create . --platforms=android,ios,macos,web
flutter run
```
