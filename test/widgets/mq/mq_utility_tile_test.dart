import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_utility_tile.dart';

Widget _host(Widget child, {MqColors? colors}) => CupertinoApp(
  home: MqTheme(
    tokens: MqTokens(
      colors: colors ?? MqColors.light(),
      brightness: Brightness.light,
    ),
    child: CupertinoPageScaffold(child: Center(child: child)),
  ),
);

void main() {
  testWidgets('vertical layout renders the name and description', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const MqUtilityTile(
          name: 'JSON',
          icon: CupertinoIcons.doc_text,
          tint: CupertinoColors.systemBlue,
          description: 'Pretty-print and validate',
        ),
      ),
    );

    expect(find.text('JSON'), findsOneWidget);
    expect(find.text('Pretty-print and validate'), findsOneWidget);
  });

  testWidgets('description is optional', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        const MqUtilityTile(
          name: 'UUID',
          icon: CupertinoIcons.number,
          tint: CupertinoColors.systemGreen,
        ),
      ),
    );

    expect(find.text('UUID'), findsOneWidget);
  });

  testWidgets('compact layout renders the name and description', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const MqUtilityTile(
          name: 'Base64',
          icon: CupertinoIcons.lock,
          tint: CupertinoColors.systemOrange,
          description: 'Encode/decode',
          compact: true,
        ),
      ),
    );

    expect(find.text('Base64'), findsOneWidget);
    expect(find.text('Encode/decode'), findsOneWidget);
  });

  testWidgets('invokes onTap when tapped', (WidgetTester tester) async {
    int tapCount = 0;

    await tester.pumpWidget(
      _host(
        MqUtilityTile(
          name: 'Hash',
          icon: CupertinoIcons.padlock,
          tint: CupertinoColors.systemRed,
          onTap: () => tapCount++,
        ),
      ),
    );

    await tester.tap(find.byType(MqUtilityTile));
    await tester.pumpAndSettle();

    expect(tapCount, 1);
  });

  testWidgets('does not throw when tapped with no onTap callback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const MqUtilityTile(
          name: 'Color',
          icon: CupertinoIcons.paintbrush,
          tint: CupertinoColors.systemPurple,
        ),
      ),
    );

    await tester.tap(find.byType(MqUtilityTile));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes a single labelled button semantics node', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(
      _host(
        const MqUtilityTile(
          name: 'Cron',
          icon: CupertinoIcons.clock,
          tint: CupertinoColors.systemTeal,
        ),
      ),
    );

    // Semantics is not `excludeSemantics`, so the outer button label merges
    // with the descendant Text's own semantics label.
    final SemanticsNode node = tester.getSemantics(
      find.bySemanticsLabel(RegExp('Cron')),
    );
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    handle.dispose();
  });

  testWidgets('reads surface and border color from theme tokens', (
    WidgetTester tester,
  ) async {
    final MqColors darkColors = MqColors.dark();

    await tester.pumpWidget(
      _host(
        const MqUtilityTile(
          name: 'Diff',
          icon: CupertinoIcons.arrow_left_right,
          tint: CupertinoColors.systemYellow,
        ),
        colors: darkColors,
      ),
    );

    final Container surfaceContainer = tester.widget<Container>(
      find.byType(Container).first,
    );
    final BoxDecoration decoration =
        surfaceContainer.decoration! as BoxDecoration;

    expect(decoration.color, darkColors.surface);
    expect(decoration.border, isA<Border>());
    final Border border = decoration.border! as Border;
    expect(border.top.color, darkColors.border);
  });

  testWidgets('shows the accent border color while pressed', (
    WidgetTester tester,
  ) async {
    final MqColors colors = MqColors.light();

    await tester.pumpWidget(
      _host(
        const MqUtilityTile(
          name: 'Regex',
          icon: CupertinoIcons.textformat,
          tint: CupertinoColors.systemIndigo,
        ),
        colors: colors,
      ),
    );

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(MqUtilityTile)),
    );
    await tester.pump();

    final Container surfaceContainer = tester.widget<Container>(
      find.byType(Container).first,
    );
    final BoxDecoration decoration =
        surfaceContainer.decoration! as BoxDecoration;
    final Border border = decoration.border! as Border;
    expect(border.top.color, colors.accent);

    await gesture.up();
    await tester.pump();
  });
}
