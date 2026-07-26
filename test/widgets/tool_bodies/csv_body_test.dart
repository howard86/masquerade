import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/mq/mq_button.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:masquerade/widgets/tool_bodies/csv_body.dart';
import 'package:masquerade/widgets/tool_bodies/open_in_footer.dart';
import 'package:masquerade/widgets/tool_bodies/seed_source.dart';

import '_helpers.dart';

void main() {
  String? clipboard;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            clipboard =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() {
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('converts CSV and routes the exact JSON output', (
    WidgetTester tester,
  ) async {
    String? toolId;
    String? routed;
    await pumpBodyAtWidth(
      tester,
      CsvBody(
        initialInput: 'a,b\n1,2',
        onSwitchTool: (UtilityDescriptor tool, String input) {
          toolId = tool.id;
          routed = input;
        },
      ),
      340,
    );

    expect(find.textContaining('"a": "1"'), findsOneWidget);
    final Finder open = find.widgetWithText(
      MqButton,
      'Open JSON output in JSON tool',
    );
    await tester.ensureVisible(open);
    await tester.tap(open);
    expect(toolId, 'json');
    expect(routed, '[\n  {\n    "a": "1",\n    "b": "2"\n  }\n]');
  });

  testWidgets('JSON mode preserves formula-like strings and warns visibly', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      const CsvBody(initialInput: '[{"name":"=SUM(1,2)"}]'),
      340,
    );
    await tester.tap(find.text('JSON → CSV'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text && (widget.data?.contains('"=SUM(1,2)"') ?? false),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('SPREADSHEET APPS MAY EXECUTE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('JSON mode warns that scalar types become CSV text', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      const CsvBody(initialInput: '[{"count":1,"active":true}]'),
      340,
    );
    await tester.tap(find.text('JSON → CSV'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('NUMBERS AND BOOLEANS BECOME TEXT'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('inspect shows only 200 rows in a horizontal table', (
    WidgetTester tester,
  ) async {
    final String input = <String>[
      'name,value',
      for (int row = 0; row < 250; row++) 'row$row,$row',
    ].join('\n');
    await pumpBodyAtWidth(tester, CsvBody(initialInput: input), 340);
    await tester.tap(find.text('Inspect'));
    await tester.pumpAndSettle();

    expect(find.textContaining('SHOWING 200 OF 250 ROWS'), findsOneWidget);
    expect(find.text('row199'), findsOneWidget);
    expect(find.text('row200'), findsNothing);
    expect(find.byType(CupertinoScrollbar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large cells use a surrogate-safe preview and copy in full', (
    WidgetTester tester,
  ) async {
    final String large = '${'a' * 255}😀${'b' * 1000}';
    await pumpBodyAtWidth(
      tester,
      CsvBody(initialInput: 'value,id\n"$large",1'),
      340,
    );
    await tester.tap(find.text('Inspect'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text &&
            (widget.data?.contains('😀… [preview truncated]') ?? false),
      ),
      findsOneWidget,
    );
    final Finder copy = find.byKey(const ValueKey<String>('csv-cell-1-0'));
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pump(const Duration(seconds: 1));
    expect(clipboard, large);
  });

  testWidgets('large headers use a bounded preview with an exact copy value', (
    WidgetTester tester,
  ) async {
    final String header = 'h' * 1256;
    await pumpBodyAtWidth(
      tester,
      CsvBody(initialInput: '"$header",id\n1,2'),
      340,
    );
    await tester.tap(find.text('Inspect'));
    await tester.pumpAndSettle();

    final MqMonoCell metadata = tester.widget<MqMonoCell>(
      find.byWidgetPredicate(
        (Widget widget) => widget is MqMonoCell && widget.label == 'Header',
      ),
    );
    expect(metadata.value, contains('… [preview truncated]'));
    expect(metadata.copyValue, '$header · id');
  });

  testWidgets('remains bounded at 340 px with 2x text', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpBodyAtWidth(
      tester,
      const CsvBody(initialInput: 'name,value\nAda,1'),
      340,
    );
    await tester.tap(find.text('Inspect'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('file/share seeds record, protected lineage does not', (
    WidgetTester tester,
  ) async {
    final HistoryController history = HistoryController();
    final Artifact<Object?> file = Artifact<Object?>(
      kind: ArtifactKind.unknown,
      rawValue: 'a,b\n1,2',
      provenance: ArtifactProvenance.fileImport,
    );
    await _pumpWithHistory(
      tester,
      history,
      CsvBody(
        key: const ValueKey<String>('file'),
        initialInput: file.rawValue,
        initialArtifact: file,
        seedSource: SeedSource.paste,
      ),
    );
    expect(history.entries.single.utilityId, 'csv');

    final Artifact<Object?> sensitiveShare = Artifact<Object?>(
      kind: ArtifactKind.unknown,
      rawValue: 'token,value\nsecret,1',
      provenance: ArtifactProvenance.shareExtension,
      sensitivity: ArtifactSensitivity.sensitive,
    );
    await _pumpWithHistory(
      tester,
      history,
      CsvBody(
        key: const ValueKey<String>('share'),
        initialInput: sensitiveShare.rawValue,
        initialArtifact: sensitiveShare,
        seedSource: SeedSource.paste,
      ),
    );
    expect(history.entries, hasLength(1));

    await _pumpWithHistory(
      tester,
      history,
      MobileSessionRouteScope(
        addNext: false,
        protectedSession: true,
        child: const CsvBody(
          key: ValueKey<String>('session'),
          initialInput: 'private,value\nsecret,2',
          seedSource: SeedSource.paste,
        ),
      ),
    );
    expect(history.entries, hasLength(1));
  });
}

Future<void> _pumpWithHistory(
  WidgetTester tester,
  HistoryController history,
  Widget body,
) async {
  await tester.pumpWidget(
    CupertinoApp(
      home: MqTheme(
        tokens: MqTokens(
          colors: MqColors.light(),
          brightness: Brightness.light,
        ),
        child: HistoryScope(
          controller: history,
          child: SingleChildScrollView(child: body),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
