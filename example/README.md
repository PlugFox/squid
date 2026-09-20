# Squid example

A small shop that uses every feature of the package:

- `lib/src/routes.dart` — enum routes, a sealed class route with a
  parameter, a dialog route and a bottom sheet route.
- `lib/src/app.dart` — three tabs, one `NavigationController` each, with the
  guards that keep them consistent.
- `lib/src/screens.dart` — the screens, including a dialog that returns a
  value and a product that is added to the stack of another tab.
- `test/app_test.dart` — the whole flow of the application as a widget test.

```bash
flutter create . --platforms=android,ios,macos,web
flutter run
```
