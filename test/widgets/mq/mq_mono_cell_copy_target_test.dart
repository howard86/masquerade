import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';

Widget _wrap(Widget child, {double textScale = 1.0}) => CupertinoApp(
  home: MqTheme(
    tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
    child: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: CupertinoPageScaffold(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  final Finder copyTarget = find.byKey(
    const ValueKey<String>('mqMonoCellCopyTarget'),
  );

  testWidgets('copy button hit target is at least 44x44 at default scale', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(const MqMonoCell(label: 'HEX', value: '0xFF')),
    );
    await tester.pumpAndSettle();

    expect(copyTarget, findsOneWidget);
    final Size size = tester.getSize(copyTarget);
    expect(size.width, greaterThanOrEqualTo(44.0));
    expect(size.height, greaterThanOrEqualTo(44.0));
  });

  testWidgets('copy button hit target stays >=44x44 under large Dynamic Type', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(const MqMonoCell(label: 'HEX', value: '0xFF'), textScale: 3.0),
    );
    await tester.pumpAndSettle();

    expect(copyTarget, findsOneWidget);
    final Size size = tester.getSize(copyTarget);
    expect(size.width, greaterThanOrEqualTo(44.0));
    expect(size.height, greaterThanOrEqualTo(44.0));
  });

  testWidgets('glyph stays 14px at default scale (visual unchanged)', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _wrap(const MqMonoCell(label: 'HEX', value: '0xFF')),
    );
    await tester.pumpAndSettle();

    final Icon icon = tester.widget<Icon>(
      find.descendant(of: copyTarget, matching: find.byType(Icon)),
    );
    expect(icon.size, 14);
  });
}
