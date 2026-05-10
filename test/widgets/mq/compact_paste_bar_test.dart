import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/compact_paste_bar.dart';

class _Hooks {
  int paste = 0;
  int clear = 0;
  int scan = 0;
}

Widget _harness({
  required TextEditingController controller,
  required FocusNode focusNode,
  required _Hooks hooks,
}) {
  return CupertinoApp(
    home: MqTheme(
      tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
      child: CupertinoPageScaffold(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: CompactPasteBar(
            controller: controller,
            focusNode: focusNode,
            onPaste: () => hooks.paste++,
            onClear: () => hooks.clear++,
            onScan: () => hooks.scan++,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('idle: paste + scan icons trailing, no Clear button', (
    WidgetTester tester,
  ) async {
    final TextEditingController c = TextEditingController();
    final FocusNode f = FocusNode();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    final _Hooks hooks = _Hooks();

    await tester.pumpWidget(
      _harness(controller: c, focusNode: f, hooks: hooks),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Paste'), findsOneWidget);
    expect(find.bySemanticsLabel('Scan QR'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
  });

  testWidgets('content: button row reveals Paste + Clear', (
    WidgetTester tester,
  ) async {
    final TextEditingController c = TextEditingController(text: 'hello');
    final FocusNode f = FocusNode();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    final _Hooks hooks = _Hooks();

    await tester.pumpWidget(
      _harness(controller: c, focusNode: f, hooks: hooks),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paste'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
  });

  testWidgets('tap inline scan icon fires onScan', (WidgetTester tester) async {
    final TextEditingController c = TextEditingController();
    final FocusNode f = FocusNode();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    final _Hooks hooks = _Hooks();

    await tester.pumpWidget(
      _harness(controller: c, focusNode: f, hooks: hooks),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Scan QR'));
    expect(hooks.scan, 1);
    expect(hooks.paste, 0);
  });

  testWidgets('tap inline paste icon fires onPaste', (
    WidgetTester tester,
  ) async {
    final TextEditingController c = TextEditingController();
    final FocusNode f = FocusNode();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    final _Hooks hooks = _Hooks();

    await tester.pumpWidget(
      _harness(controller: c, focusNode: f, hooks: hooks),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Paste'));
    expect(hooks.paste, 1);
  });

  testWidgets('tap Clear button fires onClear', (WidgetTester tester) async {
    final TextEditingController c = TextEditingController(text: 'hello');
    final FocusNode f = FocusNode();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    final _Hooks hooks = _Hooks();

    await tester.pumpWidget(
      _harness(controller: c, focusNode: f, hooks: hooks),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    expect(hooks.clear, 1);
  });
}
