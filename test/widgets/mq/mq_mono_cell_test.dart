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
  testWidgets('accent hints use accent ink', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        const MqMonoCell(
          label: 'Result',
          value: 'value',
          hint: 'hint',
          accent: true,
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('hint')).style?.color,
      MqColors.light().accentInk,
    );
  });

  testWidgets('copy button supports keyboard activation', (
    WidgetTester tester,
  ) async {
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
      _wrap(
        const Column(
          children: <Widget>[
            MqMonoCell(label: 'Hint', value: 'skip', copyable: false),
            MqMonoCell(label: 'Result', value: 'exact value'),
          ],
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(clipboard, 'exact value');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

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

  testWidgets('sensitivity follows value changes across rebuilds', (
    WidgetTester tester,
  ) async {
    // Caption-less cells name their copy button by a safe preview, which
    // masks protected values — so the label shows the memoized verdict.
    Future<void> show(String value, {String? copyValue}) async {
      await tester.pumpWidget(
        _wrap(MqMonoCell(label: '', value: value, copyValue: copyValue)),
      );
    }

    await show('plain-fixture');
    expect(find.bySemanticsLabel('Copy plain-fixture'), findsOneWidget);

    await show('password=hunter2-fixture');
    expect(find.bySemanticsLabel('Copy ••••'), findsOneWidget);

    await show('plain-fixture');
    expect(find.bySemanticsLabel('Copy plain-fixture'), findsOneWidget);

    // A sensitive copyValue alone protects the cell.
    await show('plain-fixture', copyValue: 'password=hunter2-fixture');
    expect(find.bySemanticsLabel('Copy ••••'), findsOneWidget);
  });
}
