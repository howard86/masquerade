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
  matching: find.byWidgetPredicate(
    (Widget w) =>
        w is ConstrainedBox &&
        w.constraints.minWidth == 44 &&
        w.constraints.minHeight == 44,
  ),
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

      final AnimatedCrossFade crossFade = tester.widget<AnimatedCrossFade>(
        find.descendant(
          of: find.byType(AnimatedCopyIcon),
          matching: find.byType(AnimatedCrossFade),
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

      final AnimatedCrossFade crossFade = tester.widget<AnimatedCrossFade>(
        find.descendant(
          of: find.byType(AnimatedCopyIcon),
          matching: find.byType(AnimatedCrossFade),
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

      // Let the 3s auto-dismiss timer fire so no timer outlives the tree.
      await tester.pump(const Duration(seconds: 3));
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
}
