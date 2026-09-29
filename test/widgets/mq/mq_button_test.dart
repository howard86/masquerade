import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_button.dart';

Widget _host(Widget child) => CupertinoApp(
  home: MqTheme(
    tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
    child: CupertinoPageScaffold(child: Center(child: child)),
  ),
);

void main() {
  testWidgets('small buttons keep a 44-point touch target', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(MqButton(label: 'Action', size: MqButtonSize.sm, onPressed: () {})),
    );

    final Size size = tester.getSize(find.byType(MqButton));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('exposes one labelled semantics node with the enabled state', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(
      _host(
        Column(
          children: <Widget>[
            MqButton(label: 'Save', onPressed: () {}),
            const MqButton(
              label: 'Delete',
              semanticsLabel: 'Delete saved workflow',
            ),
          ],
        ),
      ),
    );

    expect(find.bySemanticsLabel('Save'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete saved workflow'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete'), findsNothing);

    final SemanticsNode enabled = tester.getSemantics(
      find.bySemanticsLabel('Save'),
    );
    final SemanticsNode disabled = tester.getSemantics(
      find.bySemanticsLabel('Delete saved workflow'),
    );
    expect(enabled.flagsCollection.isButton, isTrue);
    expect(enabled.flagsCollection.isEnabled, Tristate.isTrue);
    expect(enabled.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(disabled.flagsCollection.isButton, isTrue);
    expect(disabled.flagsCollection.isEnabled, Tristate.isFalse);
    expect(disabled.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);

    handle.dispose();
  });
}
