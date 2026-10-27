import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utils/copy_util.dart';
import 'package:masquerade/widgets/mq/mq_icons.dart';

/// Wraps [child] in the minimal CupertinoApp + MqTheme scope `AnimatedCopyIcon`
/// needs to read `context.mq`. Optionally forces a [textScaler] so the hit
/// target can be checked under Dynamic Type, or [disableAnimations] to
/// simulate iOS's Reduce Motion accessibility setting.
///
/// `MqTheme`/`MediaQuery` are applied via `CupertinoApp.builder` — same as
/// production `app.dart` — rather than nested under `home`, so they also
/// scope `Overlay`-inserted content (the `CopyToClipboardUtil` toast lives in
/// its own `OverlayEntry`, a sibling of the route content, not a descendant
/// of `home`).
Widget _harness(
  Widget child, {
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
}) => CupertinoApp(
  builder: (BuildContext context, Widget? navigator) => MqTheme(
    tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: textScaler, disableAnimations: disableAnimations),
      child: navigator!,
    ),
  ),
  home: CupertinoPageScaffold(child: Center(child: child)),
);

/// The 44×44 min-size hit region inside an [AnimatedCopyIcon].
Finder _hitTarget() => find.descendant(
  of: find.byType(AnimatedCopyIcon),
  matching: find.byType(CupertinoButton),
);

void main() {
  testWidgets('AnimatedCopyIcon exposes a copy button semantics label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_harness(AnimatedCopyIcon(onCopy: () {})));

    expect(find.bySemanticsLabel('Copy'), findsOneWidget);

    // The labelled node is a button (matches the MqMonoCell copy-button bar).
    final Finder semantics = find.descendant(
      of: find.byType(AnimatedCopyIcon),
      matching: find.byType(Semantics),
    );
    final Semantics widget = tester.widget<Semantics>(semantics.first);
    expect(widget.properties.button, isTrue);
    expect(widget.properties.label, 'Copy');
  });

  testWidgets('AnimatedCopyIcon honours a custom semantics label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _harness(AnimatedCopyIcon(onCopy: () {}, semanticsLabel: 'Copy diff')),
    );

    expect(find.bySemanticsLabel('Copy diff'), findsOneWidget);
  });

  testWidgets('AnimatedCopyIcon fires HapticFeedback.selectionClick on tap', (
    WidgetTester tester,
  ) async {
    final List<MethodCall> calls = <MethodCall>[];
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall call,
    ) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    bool copied = false;
    await tester.pumpWidget(
      _harness(AnimatedCopyIcon(onCopy: () => copied = true)),
    );

    await tester.tap(find.byType(AnimatedCopyIcon));
    await tester.pump();

    expect(copied, isTrue, reason: 'onCopy should still fire');
    expect(
      calls.any(
        (MethodCall c) =>
            c.method == 'HapticFeedback.vibrate' &&
            c.arguments == 'HapticFeedbackType.selectionClick',
      ),
      isTrue,
      reason: 'tap should trigger HapticFeedback.selectionClick()',
    );

    // Let the copied → idle reset timer fire so no timer outlives the tree.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('AnimatedCopyIcon supports keyboard activation', (
    WidgetTester tester,
  ) async {
    int copies = 0;
    await tester.pumpWidget(_harness(AnimatedCopyIcon(onCopy: () => copies++)));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(copies, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(copies, 2);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('AnimatedCopyIcon hit target is ≥ 44×44 at default scale', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_harness(AnimatedCopyIcon(onCopy: () {})));

    final Size size = tester.getSize(_hitTarget());
    expect(size.width, greaterThanOrEqualTo(44.0));
    expect(size.height, greaterThanOrEqualTo(44.0));

    // The visible glyph is unchanged: still the 16px copy icon at default scale.
    final Icon icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(AnimatedCopyIcon),
        matching: find.byIcon(MqIcons.copy),
      ),
    );
    expect(icon.size, 16);
  });

  testWidgets('AnimatedCopyIcon hit target stays ≥ 44×44 under large text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        AnimatedCopyIcon(onCopy: () {}),
        textScaler: const TextScaler.linear(3.0),
      ),
    );

    final Size size = tester.getSize(_hitTarget());
    expect(size.width, greaterThanOrEqualTo(44.0));
    expect(size.height, greaterThanOrEqualTo(44.0));
  });

  testWidgets(
    'AnimatedCopyIcon cross-fade duration collapses to zero under Reduce Motion',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(AnimatedCopyIcon(onCopy: () {}), disableAnimations: true),
      );

      final CopyFlipIcon crossFade = tester.widget<CopyFlipIcon>(
        find.descendant(
          of: find.byType(AnimatedCopyIcon),
          matching: find.byType(CopyFlipIcon),
        ),
      );
      expect(
        crossFade.duration,
        Duration.zero,
        reason: 'Reduce Motion must skip the 250ms cross-fade entirely',
      );

      await tester.tap(find.byType(AnimatedCopyIcon));
      // Let the copied → idle reset timer fire so no timer outlives the tree.
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'AnimatedCopyIcon keeps its 250ms cross-fade with motion enabled',
    (WidgetTester tester) async {
      await tester.pumpWidget(_harness(AnimatedCopyIcon(onCopy: () {})));

      final CopyFlipIcon crossFade = tester.widget<CopyFlipIcon>(
        find.descendant(
          of: find.byType(AnimatedCopyIcon),
          matching: find.byType(CopyFlipIcon),
        ),
      );
      expect(crossFade.duration, const Duration(milliseconds: 250));

      await tester.tap(find.byType(AnimatedCopyIcon));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'CopyToClipboardUtil toast appears instantly under Reduce Motion',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (BuildContext context) => CupertinoButton(
              onPressed: () =>
                  CopyToClipboardUtil.copyToClipboard(context, 'hello'),
              child: const Text('go'),
            ),
          ),
          disableAnimations: true,
        ),
      );

      await tester.tap(find.byType(CupertinoButton));
      await tester.pump(); // single frame — no 300ms slide-in wait needed

      expect(find.text('Copied to clipboard'), findsOneWidget);
      // Scoped to the toast's own SlideTransition: a `CupertinoPageRoute`
      // page transition is also a SlideTransition and (with motion enabled)
      // coexists in the tree, so an unscoped `find.byType` is ambiguous.
      final SlideTransition slide = tester.widget<SlideTransition>(
        find.ancestor(
          of: find.text('Copied to clipboard'),
          matching: find.byType(SlideTransition),
        ),
      );
      expect(slide.position.value, Offset.zero);

      final Finder dismiss = find.bySemanticsLabel('Dismiss copy notification');
      expect(dismiss, findsOneWidget);
      expect(tester.getSize(dismiss), const Size(44, 44));
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: dismiss, matching: find.byType(Icon)),
            )
            .size,
        14,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text('Copied to clipboard'), findsNothing);

      // Let the 3s auto-dismiss timer fire so no timer outlives the tree.
      await tester.pump(const Duration(seconds: 3));
      semantics.dispose();
    },
  );

  testWidgets(
    'CopyToClipboardUtil toast still starts its 300ms slide-in with motion enabled',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (BuildContext context) => CupertinoButton(
              onPressed: () =>
                  CopyToClipboardUtil.copyToClipboard(context, 'hello'),
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CupertinoButton));
      await tester.pump(); // mounts the toast; the slide-in has not ticked yet

      // Scoped to the toast's own SlideTransition: a `CupertinoPageRoute`
      // page transition is also a SlideTransition and (with motion enabled)
      // coexists in the tree, so an unscoped `find.byType` is ambiguous.
      final SlideTransition slide = tester.widget<SlideTransition>(
        find.ancestor(
          of: find.text('Copied to clipboard'),
          matching: find.byType(SlideTransition),
        ),
      );
      expect(
        slide.position.value,
        isNot(Offset.zero),
        reason: 'motion enabled must still start off-screen and slide in',
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 3));
    },
  );

  group('CopyFlipIcon', () {
    const Widget first = SizedBox(key: ValueKey<String>('first'), width: 16);
    const Widget second = SizedBox(key: ValueKey<String>('second'), width: 16);
    Widget flip(bool showSecond, {Duration? duration}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: CopyFlipIcon(
          showSecond: showSecond,
          first: first,
          second: second,
          duration: duration ?? const Duration(milliseconds: 200),
        ),
      ),
    );
    Finder fades() => find.descendant(
      of: find.byType(CopyFlipIcon),
      matching: find.byType(FadeTransition),
    );

    testWidgets('paints the shown icon without a fade layer at rest', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(flip(false));
      expect(find.byKey(const ValueKey<String>('first')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('second')), findsNothing);
      expect(fades(), findsNothing);
    });

    testWidgets('cross-fades only while flipping, then drops the fades', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(flip(false));
      await tester.pumpWidget(flip(true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fades(), findsNWidgets(2));
      final List<FadeTransition> both = tester
          .widgetList<FadeTransition>(fades())
          .toList();
      expect(both.first.opacity.value, closeTo(0.5, 0.01));
      expect(both.last.opacity.value, closeTo(0.5, 0.01));

      await tester.pump(const Duration(milliseconds: 150));
      expect(fades(), findsNothing);
      expect(find.byKey(const ValueKey<String>('second')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('first')), findsNothing);
    });

    testWidgets('a zero duration swaps instantly', (WidgetTester tester) async {
      await tester.pumpWidget(flip(false, duration: Duration.zero));
      await tester.pumpWidget(flip(true, duration: Duration.zero));
      expect(fades(), findsNothing);
      expect(find.byKey(const ValueKey<String>('second')), findsOneWidget);
    });
  });
}
