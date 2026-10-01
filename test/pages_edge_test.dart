import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squid/squid.dart';

import 'src/routes.dart';

/// A dialog that only closes through its own button.
final class _StickyDialogRoute with NavigationRoute, DialogRouteMixin {
  const _StickyDialogRoute();

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => Colors.red;

  @override
  bool get useSafeArea => false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    content: const Text('sticky dialog'),
    actions: <Widget>[
      TextButton(
        onPressed: () => context.navigation.pop('done'),
        child: const Text('close'),
      ),
    ],
  );
}

/// A sheet that neither a drag nor a tap on the barrier can close.
final class _StickySheetRoute with NavigationRoute, BottomSheetRouteMixin {
  const _StickySheetRoute();

  @override
  bool get isDismissible => false;

  @override
  bool get enableDrag => false;

  @override
  bool? get showDragHandle => false;

  @override
  bool get useSafeArea => true;

  @override
  ShapeBorder? get shape => const RoundedRectangleBorder();

  @override
  BoxConstraints? get constraints => const BoxConstraints(maxWidth: 400);

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 120, child: Center(child: Text('sticky sheet')));
}

/// A translucent popup without any transition, closed by its barrier.
final class _PopupRoute with NavigationRoute {
  const _PopupRoute();

  @override
  Page<Object?> page(BuildContext context) => NoTransitionPage<Object?>(
    key: key,
    name: name,
    opaque: false,
    barrierColor: Colors.black54,
    barrierDismissible: true,
    barrierLabel: 'close',
    child: Builder(builder: build),
  );

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(width: 100, height: 100, child: Text('popup')),
  );
}

Widget _blank(BuildContext context) => const SizedBox.shrink();

void main() => group('pages edge cases', () {
  Future<void> pumpView(WidgetTester tester, NavigationController controller) =>
      tester.pumpWidget(
        MaterialApp(home: NavigationView(controller: controller)),
      );

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            result = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('a dialog with barrierDismissible false survives a tap on '
      'the barrier', (tester) async {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);
    await pumpView(tester, controller);

    var completed = false;
    final result = controller.pushForResult<String>(const _StickyDialogRoute());
    unawaited(result.then((_) => completed = true));
    await tester.pumpAndSettle();
    expect(find.text('sticky dialog'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('sticky dialog'), findsOneWidget);
    expect(controller.length, equals(2));
    expect(completed, isFalse);

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();
    expect(await result, equals('done'));
    expect(controller.stack, equals(<NavigationRoute>[Routes.home]));
    expect(find.text('sticky dialog'), findsNothing);
  });

  testWidgets('a bottom sheet closed by a drag leaves the stack with a '
      'null result', (tester) async {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);
    await pumpView(tester, controller);

    final result = controller.pushForResult<int>(const FiltersSheetRoute());
    await tester.pumpAndSettle();
    expect(find.text('filters'), findsOneWidget);

    await tester.drag(find.text('filters'), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(find.text('filters'), findsNothing);
    expect(controller.stack, equals(<NavigationRoute>[Routes.home]));
    expect(await result, isNull);
  });

  testWidgets('a bottom sheet closed by a tap on the barrier leaves the '
      'stack with a null result', (tester) async {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);
    await pumpView(tester, controller);

    final result = controller.pushForResult<int>(const FiltersSheetRoute());
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('filters'), findsNothing);
    expect(controller.stack, equals(<NavigationRoute>[Routes.home]));
    expect(await result, isNull);
  });

  testWidgets('a sheet that is neither dismissible nor draggable waits '
      'for pop', (tester) async {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);
    await pumpView(tester, controller);

    final result = controller.pushForResult<String>(const _StickySheetRoute());
    await tester.pumpAndSettle();
    expect(find.text('sticky sheet'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.drag(find.text('sticky sheet'), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('sticky sheet'), findsOneWidget);
    expect(controller.length, equals(2));

    expect(controller.pop('kept'), isTrue);
    await tester.pumpAndSettle();
    expect(await result, equals('kept'));
    expect(find.text('sticky sheet'), findsNothing);
  });

  testWidgets('a translucent page keeps the screen below visible and its '
      'barrier closes it', (tester) async {
    final controller = NavigationController(<NavigationRoute>[Routes.home]);
    addTearDown(controller.dispose);
    await pumpView(tester, controller);

    final result = controller.pushForResult<String>(const _PopupRoute());
    await tester.pump();
    expect(find.text('popup'), findsOneWidget);
    expect(find.text('screen:home'), findsOneWidget, reason: 'opaque false');

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('popup'), findsNothing);
    expect(controller.stack, equals(<NavigationRoute>[Routes.home]));
    expect(await result, isNull);

    // An opaque page without a transition hides the screen below.
    controller.push(const FastRoute());
    await tester.pump();
    expect(find.text('fast'), findsOneWidget);
    expect(find.text('screen:home'), findsNothing);
  });

  testWidgets('the mixins forward their properties to the pages', (
    tester,
  ) async {
    final context = await pumpContext(tester);

    expect(
      const _StickyDialogRoute().page(context),
      isA<DialogPage<Object?>>()
          .having((page) => page.key, 'key', const _StickyDialogRoute().key)
          .having((page) => page.name, 'name', '_StickyDialogRoute')
          .having((page) => page.arguments, 'arguments', isEmpty)
          .having(
            (page) => page.barrierDismissible,
            'barrierDismissible',
            isFalse,
          )
          .having((page) => page.barrierColor, 'barrierColor', Colors.red)
          .having((page) => page.useSafeArea, 'useSafeArea', isFalse),
    );

    expect(
      const _StickySheetRoute().page(context),
      isA<BottomSheetPage<Object?>>()
          .having((page) => page.key, 'key', const _StickySheetRoute().key)
          .having(
            (page) => page.isScrollControlled,
            'isScrollControlled',
            isFalse,
          )
          .having((page) => page.isDismissible, 'isDismissible', isFalse)
          .having((page) => page.enableDrag, 'enableDrag', isFalse)
          .having((page) => page.showDragHandle, 'showDragHandle', isFalse)
          .having((page) => page.useSafeArea, 'useSafeArea', isTrue)
          .having((page) => page.shape, 'shape', const RoundedRectangleBorder())
          .having(
            (page) => page.constraints,
            'constraints',
            const BoxConstraints(maxWidth: 400),
          ),
    );

    expect(
      const FiltersSheetRoute().page(context),
      isA<BottomSheetPage<Object?>>()
          .having(
            (page) => page.isScrollControlled,
            'isScrollControlled',
            isTrue,
          )
          .having((page) => page.isDismissible, 'isDismissible', isTrue)
          .having((page) => page.enableDrag, 'enableDrag', isTrue)
          .having((page) => page.showDragHandle, 'showDragHandle', isNull)
          .having((page) => page.useSafeArea, 'useSafeArea', isFalse)
          .having((page) => page.shape, 'shape', isNull)
          .having((page) => page.constraints, 'constraints', isNull),
    );

    expect(
      const FastRoute().page(context),
      isA<NoTransitionPage<Object?>>()
          .having((page) => page.key, 'key', const FastRoute().key)
          .having((page) => page.name, 'name', 'FastRoute')
          .having((page) => page.opaque, 'opaque', isTrue)
          .having((page) => page.maintainState, 'maintainState', isTrue)
          .having((page) => page.fullscreenDialog, 'fullscreenDialog', isFalse)
          .having((page) => page.barrierColor, 'barrierColor', isNull)
          .having(
            (page) => page.barrierDismissible,
            'barrierDismissible',
            isFalse,
          )
          .having((page) => page.barrierLabel, 'barrierLabel', isNull),
    );
  });

  testWidgets('the pages create routes with the same properties', (
    tester,
  ) async {
    final context = await pumpContext(tester);

    expect(
      const DialogPage<Object?>(
        builder: _blank,
        barrierDismissible: false,
        barrierColor: Colors.red,
        barrierLabel: 'dismiss',
        useSafeArea: false,
        key: ValueKey<String>('dialog'),
      ).createRoute(context),
      isA<DialogRoute<Object?>>()
          .having(
            (route) => route.barrierDismissible,
            'barrierDismissible',
            isFalse,
          )
          .having((route) => route.barrierColor, 'barrierColor', Colors.red)
          .having((route) => route.barrierLabel, 'barrierLabel', 'dismiss')
          .having((route) => route.opaque, 'opaque', isFalse)
          .having(
            (route) => route.settings,
            'settings',
            isA<DialogPage<Object?>>(),
          ),
    );

    // The dialog label defaults to the localized one.
    expect(
      const DialogPage<Object?>(builder: _blank).createRoute(context),
      isA<DialogRoute<Object?>>()
          .having(
            (route) => route.barrierDismissible,
            'barrierDismissible',
            isTrue,
          )
          .having(
            (route) => route.barrierLabel,
            'barrierLabel',
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
          ),
    );

    expect(
      const BottomSheetPage<Object?>(
        builder: _blank,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        key: ValueKey<String>('sheet'),
      ).createRoute(context),
      isA<ModalBottomSheetRoute<Object?>>()
          .having((route) => route.isDismissible, 'isDismissible', isFalse)
          .having(
            (route) => route.barrierDismissible,
            'barrierDismissible',
            isFalse,
          )
          .having((route) => route.enableDrag, 'enableDrag', isFalse)
          .having(
            (route) => route.isScrollControlled,
            'isScrollControlled',
            isTrue,
          )
          .having((route) => route.barrierColor, 'barrierColor', Colors.black54)
          .having(
            (route) => route.barrierLabel,
            'barrierLabel',
            MaterialLocalizations.of(context).scrimLabel,
          )
          .having(
            (route) => route.settings,
            'settings',
            isA<BottomSheetPage<Object?>>(),
          ),
    );

    expect(
      const BottomSheetPage<Object?>(
        builder: _blank,
        barrierColor: Colors.green,
        barrierLabel: 'scrim',
      ).createRoute(context),
      isA<ModalBottomSheetRoute<Object?>>()
          .having((route) => route.barrierColor, 'barrierColor', Colors.green)
          .having((route) => route.barrierLabel, 'barrierLabel', 'scrim'),
    );

    expect(
      const NoTransitionPage<Object?>(
        child: SizedBox.shrink(),
        opaque: false,
        barrierColor: Colors.black54,
        barrierDismissible: true,
        barrierLabel: 'close',
        maintainState: false,
        fullscreenDialog: true,
        key: ValueKey<String>('popup'),
        name: 'popup',
      ).createRoute(context),
      isA<PageRoute<Object?>>()
          .having((route) => route.opaque, 'opaque', isFalse)
          .having((route) => route.barrierColor, 'barrierColor', Colors.black54)
          .having(
            (route) => route.barrierDismissible,
            'barrierDismissible',
            isTrue,
          )
          .having((route) => route.barrierLabel, 'barrierLabel', 'close')
          .having((route) => route.maintainState, 'maintainState', isFalse)
          .having((route) => route.fullscreenDialog, 'fullscreenDialog', isTrue)
          .having(
            (route) => route.transitionDuration,
            'transitionDuration',
            Duration.zero,
          )
          .having(
            (route) => route.reverseTransitionDuration,
            'reverseTransitionDuration',
            Duration.zero,
          )
          .having((route) => route.settings.name, 'name', 'popup'),
    );

    expect(
      const NoTransitionPage<Object?>(
        child: SizedBox.shrink(),
      ).createRoute(context),
      isA<PageRoute<Object?>>()
          .having((route) => route.opaque, 'opaque', isTrue)
          .having((route) => route.barrierColor, 'barrierColor', isNull)
          .having(
            (route) => route.barrierDismissible,
            'barrierDismissible',
            isFalse,
          )
          .having((route) => route.barrierLabel, 'barrierLabel', isNull)
          .having((route) => route.maintainState, 'maintainState', isTrue)
          .having(
            (route) => route.fullscreenDialog,
            'fullscreenDialog',
            isFalse,
          ),
    );

    // The whole chain: a route with a mixin, its page, and the Flutter route.
    expect(
      const _StickyDialogRoute().page(context).createRoute(context),
      isA<DialogRoute<Object?>>()
          .having(
            (route) => route.barrierDismissible,
            'barrierDismissible',
            isFalse,
          )
          .having((route) => route.barrierColor, 'barrierColor', Colors.red),
    );
  });

  test('the modal mixins tag and prioritize, the no transition one does '
      'not', () {
    expect(
      const _StickyDialogRoute().tags,
      equals(<String>{kModalTag, 'dialog'}),
    );
    expect(
      const _StickySheetRoute().tags,
      equals(<String>{kModalTag, 'bottom_sheet'}),
    );
    expect(const _StickyDialogRoute().priority, equals(1));
    expect(const _StickySheetRoute().priority, equals(1));
    expect(const FastRoute().tags, isEmpty);
    expect(const FastRoute().priority, isZero);
  });
});
