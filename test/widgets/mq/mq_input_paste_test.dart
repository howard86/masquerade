import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_input.dart';

void main() {
  Widget host({
    required TextEditingController controller,
    ValueChanged<String>? onPaste,
    ValueChanged<String>? onChanged,
  }) {
    return MqTheme(
      tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
      child: CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: MqInput(
              controller: controller,
              onChanged: onChanged,
              onPaste: onPaste,
            ),
          ),
        ),
      ),
    );
  }

  group('MqInput.onPaste', () {
    testWidgets('fires when text grows by ≥4 chars in one onChanged tick', (
      WidgetTester tester,
    ) async {
      String? received;
      final TextEditingController c = TextEditingController();
      await tester.pumpWidget(
        host(controller: c, onPaste: (String s) => received = s),
      );

      await tester.enterText(find.byType(EditableText), 'pasted-content');
      expect(received, 'pasted-content');
    });

    testWidgets('does not fire on single-char typing', (
      WidgetTester tester,
    ) async {
      String? received;
      final TextEditingController c = TextEditingController();
      await tester.pumpWidget(
        host(controller: c, onPaste: (String s) => received = s),
      );

      // enterText replaces text in one shot; simulate single-char growth via
      // incremental enterTexts.
      await tester.enterText(find.byType(EditableText), 'a');
      await tester.enterText(find.byType(EditableText), 'ab');
      await tester.enterText(find.byType(EditableText), 'abc');
      expect(received, isNull);
    });

    testWidgets('also fires on a typed onChanged event ≥4 chars', (
      WidgetTester tester,
    ) async {
      // Heuristic flags any single-tick growth of ≥4 chars as paste-class —
      // that is the documented behaviour. Dictation / autocomplete commits
      // count as paste; this is a deliberate trade-off.
      String? received;
      final TextEditingController c = TextEditingController();
      await tester.pumpWidget(
        host(controller: c, onPaste: (String s) => received = s),
      );
      await tester.enterText(find.byType(EditableText), 'hello');
      expect(received, 'hello');
    });
  });
}
