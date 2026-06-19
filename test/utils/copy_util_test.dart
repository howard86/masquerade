import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utils/copy_util.dart';

/// Wraps [child] in the minimal CupertinoApp + MqTheme scope `AnimatedCopyIcon`
/// needs to read `context.mq`.
Widget _harness(Widget child) => CupertinoApp(
  home: MqTheme(
    tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
    child: CupertinoPageScaffold(child: Center(child: child)),
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
}
