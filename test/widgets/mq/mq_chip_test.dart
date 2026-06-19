import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_chip.dart';

Widget _wrap(Widget child) => CupertinoApp(
  home: MqTheme(
    tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
    child: CupertinoPageScaffold(child: Center(child: child)),
  ),
);

void main() {
  testWidgets('tappable chip exposes button Semantics with its label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(MqChip(label: 'Dedupe', onTap: () {})));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Dedupe')),
      isSemantics(isButton: true, label: 'Dedupe'),
    );
  });

  testWidgets('non-tappable chip is not announced as a button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const MqChip(label: 'Detected JSON')));

    // The plain Text still supplies the label to the a11y tree, but the chip
    // claims no button role when it has no tap action.
    expect(
      tester.getSemantics(find.bySemanticsLabel('Detected JSON')),
      isSemantics(isButton: false),
    );
  });

  testWidgets('selected drives the selected Semantics flag', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(MqChip(label: 'URL-safe', selected: true, onTap: () {})),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('URL-safe')),
      isSemantics(isButton: true, isSelected: true),
    );

    await tester.pumpWidget(
      _wrap(MqChip(label: 'URL-safe', selected: false, onTap: () {})),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('URL-safe')),
      isSemantics(isSelected: false),
    );
  });

  testWidgets('decorative accent chip does NOT announce selected', (
    WidgetTester tester,
  ) async {
    // An always-accent ACTION chip (e.g. open_in_footer's "Diff with…") is
    // decorative emphasis, not a toggle — it must not claim the selected state
    // to screen readers even though it paints the accent visual.
    await tester.pumpWidget(
      _wrap(MqChip(label: 'Diff with…', accent: true, onTap: () {})),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Diff with…')),
      isSemantics(isButton: true, isSelected: false),
    );
  });

  testWidgets('tap fires the callback and a selection haptic', (
    WidgetTester tester,
  ) async {
    final List<MethodCall> haptics = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    int taps = 0;
    await tester.pumpWidget(
      _wrap(MqChip(label: 'Tap me', onTap: () => taps++)),
    );

    await tester.tap(find.text('Tap me'));
    expect(taps, 1);
    expect(haptics, isNotEmpty);
  });
}
