import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';

Widget _wrap(Widget child) => CupertinoApp(
  builder: (BuildContext _, Widget? root) => MqTheme(
    tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
    child: root ?? const SizedBox.shrink(),
  ),
  home: CupertinoPageScaffold(
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
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

  testWidgets('sensitive copy keeps raw clipboard data but masks previews', (
    WidgetTester tester,
  ) async {
    const String raw = 'opaque-generated-fixture';
    String? clipboard;
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map<dynamic, dynamic>)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      _wrap(const MqMonoCell(label: 'Password', value: raw, sensitive: true)),
    );

    expect(find.bySemanticsLabel('Copy Password'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Copy Password'));
    await tester.pump();

    expect(clipboard, raw);
    expect(find.text(raw), findsOneWidget);
    expect(find.text('••••'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
