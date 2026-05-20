import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';

Widget _wrap(Widget child) => CupertinoApp(
  home: MqTheme(
    tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
    child: CupertinoPageScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('wraps a long no-whitespace value without overflow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // A long token with no break opportunities (e.g. a base64 blob) must wrap
    // to multiple lines rather than overflow the cell width.
    final String value = 'a' * 600;
    await tester.pumpWidget(_wrap(MqMonoCell(label: 'BASE64', value: value)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(value), findsOneWidget);
  });
}
