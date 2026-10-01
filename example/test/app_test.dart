import 'package:example/src/app.dart';
import 'package:example/src/authentication.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() => group('example', () {
  setUp(Authentication.instance.signOut);
  tearDown(Authentication.instance.signOut);

  testWidgets('the whole flow of the application', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    // The gate is closed: every tab shows the sign in screen and there is
    // no navigation bar at all.
    expect(find.text('You are signed out'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // Signing in re-runs the guards of all the three controllers.
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Catalog'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    // A bottom sheet is a route.
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    expect(find.text('Filters'), findsOneWidget);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Filters'), findsNothing);

    // Open a product and add it to the cart through a dialog.
    await tester.tap(find.text('Product #3'));
    await tester.pumpAndSettle();
    expect(find.text('Product #3'), findsWidgets);

    await tester.tap(find.text('Add to the cart'));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure?'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // The cart tab has been filled from the shop tab and is now selected.
    expect(find.text('Are you sure?'), findsNothing);
    expect(find.text('Product #3'), findsWidgets);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      equals(1),
    );

    // The system back button pops the stack of the active tab...
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(
      find.text('Add a product from the catalog to see it here'),
      findsOneWidget,
    );

    // ...and then returns to the previously selected tab.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      isZero,
    );

    // The shop tab kept its stack while the cart was visible.
    expect(find.text('Product #3'), findsWidgets);

    // Signing out rewrites every stack, wherever the user was.
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('You are signed out'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // ...and signing back in restores a clean navigation.
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget, reason: 'the account tab');
  });

  testWidgets('the stack cannot grow forever', (tester) async {
    Authentication.instance.signIn();
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Product #0'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 20; i++) {
      await tester.tap(find.text('Open product #${i + 1}'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Product #20'), findsWidgets);

    // The LimitGuard keeps the stack at 16 routes, so going back is finite.
    var pops = 0;
    while (await tester.binding.handlePopRoute()) {
      await tester.pumpAndSettle();
      if (++pops > 32) fail('The stack is endless');
    }
    expect(pops, equals(15));
    expect(find.text('Catalog'), findsOneWidget);
  });

  testWidgets('popModals closes the declarative and the imperative popups', (
    tester,
  ) async {
    Authentication.instance.signIn();
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    // A declarative sheet...
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    // ...and an imperative dialog above it.
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Reset the filters?'), findsOneWidget);

    await tester.tap(find.text('Reset and close'));
    await tester.pumpAndSettle();
    expect(find.text('Reset the filters?'), findsNothing);
    expect(find.text('Filters'), findsNothing);
    expect(find.text('Catalog'), findsOneWidget);

    // Nothing is left in the stack: the back button has nothing to close.
    expect(await tester.binding.handlePopRoute(), isFalse);
  });
});
