import 'package:flutter/foundation.dart';

/// The state the navigation depends on.
///
/// Any [Listenable] fits: a [ChangeNotifier], a `ValueNotifier`, a BLoC
/// adapter or a merged bunch of them.
class Authentication with ChangeNotifier {
  Authentication._();

  /// The single instance used by the example.
  static final Authentication instance = Authentication._();

  bool _isSignedIn = false;

  /// Whether the user is signed in.
  bool get isSignedIn => _isSignedIn;

  /// Signs the user in and revalidates the navigation.
  void signIn() {
    if (_isSignedIn) return;
    _isSignedIn = true;
    notifyListeners();
  }

  /// Signs the user out and revalidates the navigation.
  void signOut() {
    if (!_isSignedIn) return;
    _isSignedIn = false;
    notifyListeners();
  }
}
