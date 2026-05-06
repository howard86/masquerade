import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/tool_bodies/open_in_footer.dart';

Widget _harness(Widget child) {
  return CupertinoApp(
    // MqTheme must wrap the navigator/overlay so the copy toast (inserted
    // via Overlay) can read tokens via `context.mq`.
    builder: (BuildContext _, Widget? root) => MqTheme(
      tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
      child: HistoryScope(
        controller: HistoryController(),
        child: root ?? const SizedBox.shrink(),
      ),
    ),
    home: CupertinoPageScaffold(child: child),
  );
}

void main() {
  group('OpenInFooter', () {
    testWidgets('renders nothing when output is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          OpenInFooter(
            output: null,
            excludeUtilityId: 'timestamp',
            onSwitchTool: (_, _) {},
          ),
        ),
      );
      expect(find.text('OPEN IN'), findsNothing);
    });

    testWidgets('renders nothing when output is empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          OpenInFooter(
            output: '',
            excludeUtilityId: 'timestamp',
            onSwitchTool: (_, _) {},
          ),
        ),
      );
      expect(find.text('OPEN IN'), findsNothing);
    });

    testWidgets('renders nothing when onSwitchTool is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const OpenInFooter(
            output: '1700000000',
            excludeUtilityId: 'timestamp',
          ),
        ),
      );
      expect(find.text('OPEN IN'), findsNothing);
    });

    testWidgets('excludes the self utility from chips', (
      WidgetTester tester,
    ) async {
      // 1700000000 detects as Number Base + Timestamp. Excluding timestamp
      // leaves Number Base only.
      await tester.pumpWidget(
        _harness(
          OpenInFooter(
            output: '1700000000',
            excludeUtilityId: 'timestamp',
            onSwitchTool: (_, _) {},
          ),
        ),
      );
      expect(find.text('OPEN IN'), findsOneWidget);
      expect(find.text('Number Base'), findsOneWidget);
      expect(find.text('Timestamp'), findsNothing);
    });

    testWidgets('renders nothing when only self detects', (
      WidgetTester tester,
    ) async {
      // {"a":1} detects only as JSON. Excluding json leaves empty.
      await tester.pumpWidget(
        _harness(
          OpenInFooter(
            output: '{"a":1}',
            excludeUtilityId: 'json',
            onSwitchTool: (_, _) {},
          ),
        ),
      );
      expect(find.text('OPEN IN'), findsNothing);
    });

    testWidgets('tap fires onSwitchTool with descriptor and output', (
      WidgetTester tester,
    ) async {
      UtilityDescriptor? tapped;
      String? receivedInput;
      await tester.pumpWidget(
        _harness(
          OpenInFooter(
            output: '1700000000',
            excludeUtilityId: 'timestamp',
            onSwitchTool: (UtilityDescriptor u, String input) {
              tapped = u;
              receivedInput = input;
            },
          ),
        ),
      );

      await tester.tap(find.text('Number Base'));
      await tester.pumpAndSettle();

      expect(tapped, isNotNull);
      expect(tapped!.id, 'number_base');
      expect(receivedInput, '1700000000');
    });

    testWidgets('long-press copies to clipboard and fires onSwitchTool', (
      WidgetTester tester,
    ) async {
      UtilityDescriptor? tapped;
      // Capture clipboard sets through the platform channel so we don't rely
      // on a real clipboard implementation in the test environment.
      final List<String> clipboardWrites = <String>[];
      final TestDefaultBinaryMessenger messenger =
          tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (
        MethodCall call,
      ) async {
        if (call.method == 'Clipboard.setData') {
          final Map<dynamic, dynamic> args = call.arguments as Map;
          clipboardWrites.add(args['text'] as String);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(
        _harness(
          OpenInFooter(
            output: '1700000000',
            excludeUtilityId: 'timestamp',
            onSwitchTool: (UtilityDescriptor u, _) => tapped = u,
          ),
        ),
      );

      await tester.longPress(find.text('Number Base'));
      await tester.pumpAndSettle();

      expect(clipboardWrites, contains('1700000000'));
      expect(tapped, isNotNull);
      expect(tapped!.id, 'number_base');

      // Drain the toast's 3s auto-dismiss timer so the test ends clean.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });
}
