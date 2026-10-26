import 'package:example/src/authentication.dart';
import 'package:example/src/navigation.dart';
import 'package:example/src/routes.dart';
import 'package:example/src/tabs_scope.dart';
import 'package:flutter/material.dart';
import 'package:squid/squid.dart';

/// Root of the shop tab.
class CatalogScreen extends StatelessWidget {
  /// Creates the catalog screen.
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Catalog'),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.filter_list),
          // A bottom sheet is opened by changing the stack, not by awaiting
          // an imperative `showModalBottomSheet`.
          onPressed: () => context.nav.push(const FiltersRoute()),
        ),
      ],
    ),
    body: ListView.builder(
      itemCount: 20,
      itemBuilder: (context, index) => ListTile(
        leading: CircleAvatar(child: Text('$index')),
        title: Text('Product #$index'),
        onTap: () => context.nav.push(ProductRoute(index)),
      ),
    ),
  );
}

/// Details of a product.
class ProductScreen extends StatelessWidget {
  /// Creates the screen of the product [id].
  const ProductScreen({required this.id, super.key});

  /// Identifier of the product.
  final int id;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Product #$id')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: <Widget>[
          Text('Product #$id', style: Theme.of(context).textTheme.titleLarge),
          FilledButton(
            onPressed: () => _addToCart(context),
            child: const Text('Add to the cart'),
          ),
          // Deep navigation: every product opens the next one.
          TextButton(
            onPressed: () => context.nav.push(ProductRoute(id + 1)),
            child: Text('Open product #${id + 1}'),
          ),
        ],
      ),
    ),
  );

  Future<void> _addToCart(BuildContext context) async {
    // Everything is captured before the gap: the controllers outlive the
    // widgets, so nothing here depends on the context being still mounted.
    final navigation = context.navigation;
    final tabs = AppTabsScope.of(context);
    // A dialog returns a value, exactly like `showDialog` does.
    final confirmed = await navigation.pushForResult<bool>(
      ConfirmRoute('Add the product #$id to the cart?'),
    );
    if (confirmed ?? false) {
      // One tab writes into the stack of another one and switches to it.
      tabs[AppTab.cart].push(ProductRoute(id));
      tabs.select(AppTab.cart, popToRoot: false);
    }
  }
}

/// Root of the cart tab.
class CartScreen extends StatelessWidget {
  /// Creates the cart screen.
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cart')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: <Widget>[
          const Text('Add a product from the catalog to see it here'),
          FilledButton(
            onPressed: () => context.nav.push(Routes.checkout),
            child: const Text('Checkout'),
          ),
        ],
      ),
    ),
  );
}

/// A flow with a navigator of its own, on top of the cart tab.
class CheckoutScreen extends StatefulWidget {
  /// Creates the checkout.
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final NavigationController _checkoutController;

  @override
  void initState() {
    super.initState();
    _checkoutController = NavigationController(<NavigationRoute>[
      CheckoutStep.address,
    ], debugLabel: 'checkout');
  }

  @override
  void dispose() {
    _checkoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    // The back button of this app bar belongs to the cart tab: it closes
    // the whole checkout.
    appBar: AppBar(title: const Text('Checkout')),
    body: NavigationView(controller: _checkoutController),
  );
}

/// The first step of the checkout.
class AddressStepScreen extends StatelessWidget {
  /// Creates the address step.
  const AddressStepScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        // The closest navigator is the one of the checkout.
        onPressed: () => context.nav.push(CheckoutStep.payment),
        child: const Text('Next'),
      ),
    ),
  );
}

/// The last step of the checkout.
class PaymentStepScreen extends StatelessWidget {
  /// Creates the payment step.
  const PaymentStepScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        // The checkout is a route of the cart tab: it is closed in the
        // navigator of the tab, found by its scope.
        onPressed: () => NavigationScope.find(
          context,
          scope: AppTab.cart,
        ).remove(Routes.checkout),
        child: const Text('Pay'),
      ),
    ),
  );
}

/// Root of the account tab.
class AccountScreen extends StatelessWidget {
  /// Creates the account screen.
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: <Widget>[
          FilledButton(
            onPressed: () => context.nav.push(Routes.settings),
            child: const Text('Settings'),
          ),
          OutlinedButton(
            // Signing out notifies the `revalidate` listenable of every
            // controller, the gate closes and all the stacks are rewritten
            // by the guard. No navigation code here at all.
            onPressed: Authentication.instance.signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
    ),
  );
}

/// Regular screen pushed on top of the account tab.
class SettingsScreen extends StatelessWidget {
  /// Creates the settings screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: const Center(child: Text('Nothing to configure yet')),
  );
}

/// The gate of the application.
class SignInScreen extends StatelessWidget {
  /// Creates the sign in screen.
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: <Widget>[
          const Text('You are signed out'),
          FilledButton(
            onPressed: Authentication.instance.signIn,
            child: const Text('Sign in'),
          ),
        ],
      ),
    ),
  );
}

/// Content of the filters bottom sheet.
class FiltersView extends StatelessWidget {
  /// Creates the filters view.
  const FiltersView({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: <Widget>[
          Text('Filters', style: Theme.of(context).textTheme.titleLarge),
          const Text('The sheet is a route: try the system back button'),
          FilledButton(
            onPressed: () => context.nav.pop(),
            child: const Text('Apply'),
          ),
          TextButton(
            // An imperative dialog above a declarative sheet: popModals
            // closes both of them with a single call.
            onPressed: () => showDialog<void>(
              context: context,
              // The dialog is opened on the root navigator of the
              // application, above every NavigationView: there is no
              // controller in its context, so the context of the sheet
              // is used instead.
              builder: (_) => AlertDialog(
                content: const Text('Reset the filters?'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => context.nav.popModals(),
                    child: const Text('Reset and close'),
                  ),
                ],
              ),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    ),
  );
}
