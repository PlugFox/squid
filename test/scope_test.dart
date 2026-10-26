import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squid/squid.dart';

import 'src/routes.dart';

enum _Scope { outer, middle, inner, missing }

void main() => group('scope', () {
  NavigationController controller(NavigationStack stack, {Object? scope}) {
    final controller = NavigationController(stack, scope: scope);
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  BuildContext contextOf(WidgetTester tester, String text) =>
      tester.element(find.text(text));

  testWidgets('finds the closest controller with the scope, the closest '
      'controller included, skipping the others', (tester) async {
    final inner = controller(<NavigationRoute>[
      Routes.home,
    ], scope: _Scope.inner);
    final unscoped = controller(<NavigationRoute>[_ShellRoute(inner)]);
    final middle = controller(<NavigationRoute>[
      _ShellRoute(unscoped),
    ], scope: _Scope.middle);
    final outer = controller(<NavigationRoute>[
      _ShellRoute(middle),
    ], scope: _Scope.outer);
    await pumpApp(tester, NavigationView(controller: outer));

    final context = contextOf(tester, 'screen:home');
    expect(NavigationScope.find(context, scope: _Scope.inner), same(inner));
    expect(NavigationScope.find(context, scope: _Scope.middle), same(middle));
    expect(NavigationScope.find(context, scope: _Scope.outer), same(outer));
    expect(
      NavigationScope.maybeFind(context, scope: _Scope.outer),
      same(outer),
    );
  });

  testWidgets('the closest of the controllers with the same scope wins', (
    tester,
  ) async {
    final inner = controller(<NavigationRoute>[
      Routes.home,
    ], scope: _Scope.inner);
    final outer = controller(<NavigationRoute>[
      _ShellRoute(inner),
    ], scope: _Scope.inner);
    await pumpApp(tester, NavigationView(controller: outer));

    expect(
      NavigationScope.find(
        contextOf(tester, 'screen:home'),
        scope: _Scope.inner,
      ),
      same(inner),
    );
  });

  testWidgets('scopes are compared with ==', (tester) async {
    final only = controller(<NavigationRoute>[Routes.home], scope: 'flow');
    await pumpApp(tester, NavigationView(controller: only));

    // Another instance of an equal string.
    final scope = <String>['fl', 'ow'].join();
    expect(
      NavigationScope.find(contextOf(tester, 'screen:home'), scope: scope),
      same(only),
    );
  });

  testWidgets('an unknown scope: maybeFind returns null, find throws', (
    tester,
  ) async {
    final inner = controller(<NavigationRoute>[
      Routes.home,
    ], scope: _Scope.inner);
    final outer = controller(<NavigationRoute>[
      _ShellRoute(inner),
    ], scope: _Scope.outer);
    await pumpApp(tester, NavigationView(controller: outer));

    final context = contextOf(tester, 'screen:home');
    expect(NavigationScope.maybeFind(context, scope: _Scope.missing), isNull);
    expect(
      () => NavigationScope.find(context, scope: _Scope.missing),
      throwsFlutterError,
    );
  });

  testWidgets('nothing is found without a scope above', (tester) async {
    late BuildContext context;
    await pumpApp(
      tester,
      Builder(
        builder: (builderContext) {
          context = builderContext;
          return const SizedBox();
        },
      ),
    );

    expect(NavigationScope.maybeFind(context, scope: _Scope.outer), isNull);
    expect(
      () => NavigationScope.find(context, scope: _Scope.outer),
      throwsFlutterError,
    );
  });

  testWidgets('a NavigationScope without a view is found as well', (
    tester,
  ) async {
    final standalone = controller(<NavigationRoute>[
      Routes.settings,
    ], scope: _Scope.outer);
    final view = controller(<NavigationRoute>[Routes.home]);
    await pumpApp(
      tester,
      NavigationScope(
        controller: standalone,
        child: NavigationView(controller: view),
      ),
    );

    expect(
      NavigationScope.find(
        contextOf(tester, 'screen:home'),
        scope: _Scope.outer,
      ),
      same(standalone),
    );
  });

  testWidgets('views side by side with the same scope find their own: the '
      'search follows the tree', (tester) async {
    final leftInner = controller(<NavigationRoute>[Routes.home]);
    final left = controller(<NavigationRoute>[
      _ShellRoute(leftInner),
    ], scope: _Scope.outer);
    final rightInner = controller(<NavigationRoute>[Routes.catalog]);
    final right = controller(<NavigationRoute>[
      _ShellRoute(rightInner),
    ], scope: _Scope.outer);
    await pumpApp(
      tester,
      Row(
        children: <Widget>[
          Expanded(child: NavigationView(controller: left)),
          Expanded(child: NavigationView(controller: right)),
        ],
      ),
    );

    expect(
      NavigationScope.find(
        contextOf(tester, 'screen:home'),
        scope: _Scope.outer,
      ),
      same(left),
    );
    expect(
      NavigationScope.find(
        contextOf(tester, 'screen:catalog'),
        scope: _Scope.outer,
      ),
      same(right),
    );
  });

  for (final listen in <bool>[true, false]) {
    testWidgets('listen: $listen depends on the found controller only', (
      tester,
    ) async {
      var builds = 0;
      final inner = controller(<NavigationRoute>[
        _ProbeRoute(listen: listen, onBuild: () => builds++),
      ]);
      final outer = controller(<NavigationRoute>[
        _ShellRoute(inner),
      ], scope: _Scope.outer);
      await pumpApp(tester, NavigationView(controller: outer));
      final initial = builds;

      // A change of the found controller that keeps the probe on screen.
      outer.change((stack) => <NavigationRoute>[Routes.home, ...stack]);
      await tester.pumpAndSettle();
      expect(builds, equals(listen ? initial + 1 : initial));

      // A change of the closer controller.
      inner.push(Routes.catalog);
      await tester.pumpAndSettle();
      inner.pop();
      await tester.pumpAndSettle();
      expect(builds, equals(listen ? initial + 1 : initial));
    });
  }
});

final class _ShellRoute with NavigationRoute {
  const _ShellRoute(this.controller);

  final NavigationController controller;

  @override
  String get name => 'shell';

  @override
  Widget build(BuildContext context) => NavigationView(controller: controller);
}

/// Reports its builds and finds the controller of the outer scope while
/// building.
final class _ProbeRoute with NavigationRoute {
  const _ProbeRoute({required this.listen, required this.onBuild});

  final bool listen;

  final VoidCallback onBuild;

  @override
  String get name => 'probe';

  @override
  Widget build(BuildContext context) {
    onBuild();
    NavigationScope.find(context, scope: _Scope.outer, listen: listen);
    return const Text('probe');
  }
}
