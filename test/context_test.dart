import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squid/squid.dart';

import 'src/routes.dart';

/// A scope with something a guard may depend on, e.g. the dependencies of
/// the application or a feature flag.
class FeatureScope extends InheritedWidget {
  const FeatureScope({required this.enabled, required super.child, super.key});

  final bool enabled;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FeatureScope>()?.enabled ??
      true;

  @override
  bool updateShouldNotify(covariant FeatureScope oldWidget) =>
      oldWidget.enabled != enabled;
}

/// The side pane exists only on a wide window and only while the feature
/// is enabled.
class _AdaptiveGuard extends ContextGuard {
  const _AdaptiveGuard();

  static const String tag = 'side-pane';

  @override
  NavigationStack guard(BuildContext context, NavigationStack stack) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    if (!wide || !FeatureScope.of(context)) return stack.withoutTag(tag);
    return stack.containsTag(tag)
        ? stack
        : <NavigationRoute>[...stack, const _SidePaneRoute()];
  }
}

final class _SidePaneRoute with NavigationRoute {
  const _SidePaneRoute();

  @override
  Set<String> get tags => const <String>{_AdaptiveGuard.tag};

  @override
  Widget build(BuildContext context) => const Text('side-pane');
}

void main() => group('context', () {
  testWidgets('a guard follows the size of the window', (tester) async {
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      guards: <NavigationGuard>[const _AdaptiveGuard()],
    );
    addTearDown(controller.dispose);

    // Before the first widget there is no context at all, and the guard is
    // simply skipped instead of crashing.
    expect(controller.stack, equals(<NavigationRoute>[Routes.home]));

    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: NavigationView(controller: controller)),
    );
    await tester.pumpAndSettle();

    // Mounting the widget gives the guard its context.
    expect(controller.stack.containsTag(_AdaptiveGuard.tag), isTrue);

    // Resizing the window re-runs the guards: nothing had to be wired up,
    // reading the media query subscribed the navigator to it.
    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    expect(controller.stack.containsTag(_AdaptiveGuard.tag), isFalse);

    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    expect(controller.stack.containsTag(_AdaptiveGuard.tag), isTrue);
  });

  testWidgets('a guard follows an inherited scope above the navigator', (
    tester,
  ) async {
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      guards: <NavigationGuard>[const _AdaptiveGuard()],
    );
    addTearDown(controller.dispose);

    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var enabled = true;
    late StateSetter setScope;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setScope = setState;
            return FeatureScope(
              enabled: enabled,
              child: NavigationView(controller: controller),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.stack.containsTag(_AdaptiveGuard.tag), isTrue);

    setScope(() => enabled = false);
    await tester.pumpAndSettle();
    expect(controller.stack.containsTag(_AdaptiveGuard.tag), isFalse);

    setScope(() => enabled = true);
    await tester.pumpAndSettle();
    expect(controller.stack.containsTag(_AdaptiveGuard.tag), isTrue);
  });

  testWidgets('the theme is reachable from a guard', (tester) async {
    Brightness? seen;
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      guards: <NavigationGuard>[
        NavigationGuard((controller, stack) {
          final context = controller.context;
          if (context != null) seen = Theme.of(context).brightness;
          return stack;
        }),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: NavigationView(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(seen, equals(Brightness.dark));
  });

  testWidgets('a navigator without context aware guards has no extra work', (
    tester,
  ) async {
    var passes = 0;
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      guards: <NavigationGuard>[
        NavigationGuard((controller, stack) {
          passes++;
          return stack;
        }),
      ],
    );
    addTearDown(controller.dispose);

    expect(passes, equals(1), reason: 'the initial validation');

    await tester.pumpWidget(
      MaterialApp(home: NavigationView(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(passes, equals(2), reason: 'once more when the widget is mounted');

    // The guard reads nothing from the context, so the navigator has no
    // dependencies and a resize does not run the guards again.
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();
    expect(passes, equals(2));
  });

  for (final layoutBuilder in <bool>[false, true]) {
    testWidgets(
      'a guard redirecting during the build does not break an '
      'ancestor listening to the controller (layoutBuilder: $layoutBuilder)',
      (tester) async {
        final controller = NavigationController(
          <NavigationRoute>[Routes.home],
          guards: <NavigationGuard>[const _AdaptiveGuard()],
        );
        addTearDown(controller.dispose);

        Widget app(double width) {
          Widget view() => NavigationView(controller: controller);
          return MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(width, 600)),
              // A shell above the view, e.g. a bottom navigation bar.
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => Column(
                  children: <Widget>[
                    Text('top:${controller.top.name}'),
                    Expanded(
                      child: layoutBuilder
                          ? LayoutBuilder(builder: (_, _) => view())
                          : view(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(app(800));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('top:_SidePaneRoute'), findsOneWidget);
        expect(find.text('side-pane'), findsOneWidget);

        await tester.pumpWidget(app(300));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('top:home'), findsOneWidget);
        expect(find.text('side-pane'), findsNothing);
      },
    );
  }

  testWidgets('an observer marking an ancestor dirty during a build time '
      'change is notified at the end of the frame', (tester) async {
    final current = ValueNotifier<String>('');
    addTearDown(current.dispose);
    final controller = NavigationController(
      <NavigationRoute>[Routes.home],
      guards: <NavigationGuard>[const _AdaptiveGuard()],
      observers: <NavigationObserver>[_TopObserver(current)],
    );
    addTearDown(controller.dispose);

    Widget app(double width) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 600)),
        child: ValueListenableBuilder<String>(
          valueListenable: current,
          builder: (context, top, _) => Column(
            children: <Widget>[
              Text('observed:$top'),
              Expanded(child: NavigationView(controller: controller)),
            ],
          ),
        ),
      ),
    );

    await tester.pumpWidget(app(800));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('observed:_SidePaneRoute'), findsOneWidget);

    await tester.pumpWidget(app(300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('observed:home'), findsOneWidget);
  });

  testWidgets('a page reading the stack follows a build time change '
      'in the same frame', (tester) async {
    final controller = NavigationController(
      <NavigationRoute>[const _StackLengthRoute()],
      guards: <NavigationGuard>[const _AdaptiveGuard()],
    );
    addTearDown(controller.dispose);

    Widget app(double width) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 600)),
        child: NavigationView(controller: controller),
      ),
    );

    await tester.pumpWidget(app(800));
    await tester.pumpAndSettle();
    expect(find.text('length:2', skipOffstage: false), findsOneWidget);

    await tester.pumpWidget(app(300));
    expect(controller.length, equals(1));
    expect(find.text('length:1'), findsOneWidget, reason: 'the same frame');
  });
});

final class _StackLengthRoute with NavigationRoute {
  const _StackLengthRoute();

  @override
  Widget build(BuildContext context) =>
      Text('length:${NavigationScope.stackOf(context).length}');
}

class _TopObserver with NavigationObserver {
  _TopObserver(this.current);

  final ValueNotifier<String> current;

  @override
  void onChange(
    NavigationController controller,
    NavigationStack previous,
    NavigationStack next,
  ) => current.value = next.last.name;
}
