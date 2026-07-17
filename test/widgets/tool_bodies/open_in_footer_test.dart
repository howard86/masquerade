import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/state/detection_preference_controller.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/mq/mq_chip.dart';
import 'package:masquerade/widgets/tool_bodies/open_in_footer.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _harness(
  Widget child, {
  DetectionPreferenceController? detectionPreferenceController,
}) {
  return CupertinoApp(
    // MqTheme must wrap the navigator/overlay so the copy toast (inserted
    // via Overlay) can read tokens via `context.mq`.
    builder: (BuildContext _, Widget? root) => MqTheme(
      tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
      child: DetectionPreferenceScope(
        controller:
            detectionPreferenceController ?? DetectionPreferenceController(),
        child: HistoryScope(
          controller: HistoryController(),
          child: root ?? const SizedBox.shrink(),
        ),
      ),
    ),
    home: CupertinoPageScaffold(child: child),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

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

    testWidgets('renders nothing for a protected source', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          OpenInFooter(
            output: '1700000000',
            excludeUtilityId: 'generator',
            protectedSource: true,
            onSwitchTool: (_, _) {},
          ),
        ),
      );

      expect(find.text('OPEN IN'), findsNothing);
      expect(find.text('Timestamp'), findsNothing);
    });

    testWidgets('renders nothing for detected credential content', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          OpenInFooter(
            output: '{"password":"raw-credential-fixture"}',
            excludeUtilityId: 'base64',
            onSwitchTool: (_, _) {},
          ),
        ),
      );

      expect(find.text('OPEN IN'), findsNothing);
      expect(find.textContaining('raw-credential-fixture'), findsNothing);
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

    testWidgets('saved preference reorders compatible Open in targets', (
      WidgetTester tester,
    ) async {
      final DetectionPreferenceController preferences =
          DetectionPreferenceController();
      await preferences.prefer(
        UtilityCatalog.detectArtifacts('1700000000'),
        ArtifactKind.number,
      );
      await tester.pumpWidget(
        _harness(
          OpenInFooter(
            output: '1700000000',
            excludeUtilityId: 'generator',
            onSwitchTool: (_, _) {},
          ),
          detectionPreferenceController: preferences,
        ),
      );

      expect(
        tester
            .widgetList<MqChip>(find.byType(MqChip))
            .map((MqChip chip) => chip.label)
            .toList(),
        <String>['Number Base', 'Timestamp'],
      );
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

    testWidgets('filters shape matches incompatible with source output type', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          OpenInFooter(
            output: '#336699',
            excludeUtilityId: 'math',
            onSwitchTool: (_, _) {},
          ),
        ),
      );

      expect(find.text('OPEN IN'), findsNothing);
      expect(find.text('Color'), findsNothing);
    });

    testWidgets('source-only Generator can route a safe UUID output', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          OpenInFooter(
            output: '550e8400-e29b-41d4-a716-446655440000',
            excludeUtilityId: 'generator',
            onSwitchTool: (_, _) {},
          ),
        ),
      );

      expect(find.text('OPEN IN'), findsOneWidget);
      expect(find.text('UUID'), findsOneWidget);
    });

    testWidgets('unknown source ids fail closed', (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          OpenInFooter(
            output: '{"a":1}',
            excludeUtilityId: 'removed-tool',
            onSwitchTool: (_, _) {},
          ),
        ),
      );

      expect(find.text('OPEN IN'), findsNothing);
    });

    testWidgets('chip exposes an a11y button with an "Open in" label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          OpenInFooter(
            output: '1700000000',
            excludeUtilityId: 'timestamp',
            onSwitchTool: (_, _) {},
          ),
        ),
      );

      // The chip announces itself as a button labelled "Open in <tool>" so a
      // screen reader can find and operate the cross-tool route.
      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Semantics &&
              w.properties.button == true &&
              w.properties.label == 'Open in Number Base',
        ),
        findsOneWidget,
      );
    });

    testWidgets('current mobile session uses Add next step semantics', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          MobileSessionRouteScope(
            addNext: true,
            protectedSession: false,
            child: OpenInFooter(
              output: '1700000000',
              excludeUtilityId: 'timestamp',
              onSwitchTool: (_, _) {},
            ),
          ),
        ),
      );

      expect(find.text('ADD NEXT STEP'), findsOneWidget);
      expect(find.text('OPEN IN'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is Semantics &&
              widget.properties.label == 'Add next step Number Base',
        ),
        findsOneWidget,
      );
    });

    testWidgets('protected session routes safely without clipboard copy', (
      WidgetTester tester,
    ) async {
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
      int routes = 0;
      await tester.pumpWidget(
        _harness(
          MobileSessionRouteScope(
            addNext: true,
            protectedSession: true,
            child: OpenInFooter(
              output: '{"at":1700000000}',
              excludeUtilityId: 'jwt',
              protectedSource: true,
              onSwitchTool: (_, _) => routes++,
            ),
          ),
        ),
      );

      expect(find.text('ADD NEXT STEP'), findsOneWidget);
      await tester.longPress(find.text('JSON / YAML / TOML'));
      await tester.pump();
      expect(clipboardWrites, isEmpty);
      expect(routes, 1);
      await tester.tap(find.text('JSON / YAML / TOML'));
      await tester.pump();
      expect(routes, 2);
    });

    testWidgets('credential content stays hidden in a mobile session', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          MobileSessionRouteScope(
            addNext: true,
            protectedSession: true,
            child: OpenInFooter(
              output: '{"password":"raw-credential-fixture"}',
              excludeUtilityId: 'jwt',
              protectedSource: true,
              onSwitchTool: (_, _) {},
            ),
          ),
        ),
      );

      expect(find.text('ADD NEXT STEP'), findsNothing);
      expect(find.textContaining('raw-credential-fixture'), findsNothing);
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

    testWidgets('safe session long-press copies and adds next step', (
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
          MobileSessionRouteScope(
            addNext: true,
            protectedSession: false,
            child: OpenInFooter(
              output: '1700000000',
              excludeUtilityId: 'timestamp',
              onSwitchTool: (UtilityDescriptor u, _) => tapped = u,
            ),
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
