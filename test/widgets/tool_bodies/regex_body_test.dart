import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/utils/regex_parser.dart';
import 'package:masquerade/widgets/mq/mq_button.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:masquerade/widgets/tool_bodies/open_in_footer.dart';
import 'package:masquerade/widgets/tool_bodies/regex_body.dart';

import '_helpers.dart';

void main() {
  String? copied;

  setUp(() {
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('highlights matches and renders numbered and named captures', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const RegexBody(runner: _runRegex), 340);
    await tester.enterText(find.byType(EditableText).first, r'(?<n>\d+)');
    await tester.enterText(find.byType(EditableText).last, 'a12😀b34');
    await tester.pump(const Duration(milliseconds: 200));

    final RichText highlight = tester.widget<RichText>(
      find.byKey(const ValueKey<String>('regex-highlight')),
    );
    expect(highlight.text.toPlainText(), 'a12😀b34');
    expect(find.text('MATCH 1 · 1..3'), findsOneWidget);
    expect(find.text('MATCH 2 · 6..8'), findsOneWidget);
    expect(find.text(r'$1'), findsNWidgets(2));
    expect(find.text('n'), findsNWidgets(2));
    expect(find.text('12'), findsNWidgets(3));
  });

  testWidgets('compile errors and zero-width matches stay visible', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      const RegexBody(initialInput: 'ab', runner: _runRegex),
      340,
    );

    expect(find.text('MATCH 1 · 0..0'), findsOneWidget);
    expect(find.text('Empty match'), findsNWidgets(3));
    await tester.enterText(find.byType(EditableText).first, '(');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Invalid regular expression'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bounds highlight, matches, captures, and previews', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: RegexBody(initialInput: 'x' * 3000, runner: _runRegex),
      ),
      340,
    );
    await tester.enterText(find.byType(EditableText).first, 'x');
    await tester.pump(const Duration(milliseconds: 200));

    final RichText highlight = tester.widget<RichText>(
      find.byKey(const ValueKey<String>('regex-highlight')),
    );
    expect((highlight.text as TextSpan).children!.length, 2001);
    expect(
      find.text('HIGHLIGHTING IS LIMITED TO THE FIRST 2,000 MATCHES.'),
      findsOneWidget,
    );
    expect(find.byType(MqMonoCell), findsNWidgets(20));
    expect(find.widgetWithText(MqButton, 'Show 20 more'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final String groups = List<String>.filled(100, '(a)').join();
    await tester.enterText(find.byType(EditableText).first, groups);
    await tester.enterText(find.byType(EditableText).last, 'a' * 100);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(MqMonoCell), findsNWidgets(21));
    expect(
      find.widgetWithText(MqButton, 'Show 20 more captures'),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.widgetWithText(MqButton, 'Show 20 more captures'),
    );
    await tester.tap(find.widgetWithText(MqButton, 'Show 20 more captures'));
    await tester.pump();
    expect(find.byType(MqMonoCell), findsNWidgets(41));
    await tester.enterText(find.byType(EditableText).first, '(a)');
    await tester.enterText(find.byType(EditableText).last, 'a');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(MqMonoCell), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unicode-off emoji matches keep valid rendered UTF-16', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      const RegexBody(initialInput: '😀', runner: _runRegex),
      340,
    );
    await tester.enterText(find.byType(EditableText).first, '.');
    await tester.tap(find.text('Unicode'));
    await tester.pump(const Duration(milliseconds: 200));

    final RichText highlight = tester.widget<RichText>(
      find.byKey(const ValueKey<String>('regex-highlight')),
    );
    expect(highlight.text.toPlainText(), '😀');
    expect(find.text(r'\uD83D'), findsOneWidget);
    expect(find.text(r'\uDE00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('10,000 empty matches stay bounded at 340px and 2x text', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: RegexBody(initialInput: 'x' * 9999, runner: _runRegex),
      ),
      340,
    );

    expect(find.text('SHOWING 20 OF 10000 MATCHES'), findsOneWidget);
    expect(find.byType(MqMonoCell), findsNWidgets(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('large match preview copies the exact value', (
    WidgetTester tester,
  ) async {
    final String input = 'z' * 2000;
    await _pump(tester, RegexBody(initialInput: input, runner: _runRegex));
    await tester.enterText(find.byType(EditableText).first, r'.+');
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is Text && widget.data == input,
      ),
      findsNothing,
    );
    final Finder copy = find
        .byKey(const ValueKey<String>('mqMonoCellCopyTarget'))
        .first;
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pump();
    expect(copied, input);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('records safe history and drops protected input', (
    WidgetTester tester,
  ) async {
    final HistoryController history = HistoryController();
    await _pump(tester, const RegexBody(runner: _runRegex), history: history);
    await tester.enterText(find.byType(EditableText).first, r'\d+');
    await tester.enterText(find.byType(EditableText).last, 'year 2026');
    await tester.pump(const Duration(milliseconds: 200));
    expect(history.entries.single.input, 'year 2026');
    expect(history.entries.single.output, '2026');

    await tester.enterText(find.byType(EditableText).first, r'.+');
    await tester.enterText(
      find.byType(EditableText).last,
      'Authorization: Bearer raw-secret-token',
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(history.entries, hasLength(1));

    final HistoryController protectedHistory = HistoryController();
    await _pump(
      tester,
      MobileSessionRouteScope(
        addNext: true,
        protectedSession: true,
        child: const RegexBody(runner: _runRegex),
      ),
      history: protectedHistory,
    );
    await tester.enterText(find.byType(EditableText).first, r'\d+');
    await tester.enterText(find.byType(EditableText).last, 'year 2026');
    await tester.pump(const Duration(milliseconds: 200));
    expect(protectedHistory.entries, isEmpty);
  });

  testWidgets('restores and updates typed session settings', (
    WidgetTester tester,
  ) async {
    Map<String, Object?>? updated;
    await _pump(
      tester,
      MobileSessionRouteScope(
        addNext: true,
        protectedSession: false,
        settings: const <String, Object?>{
          'pattern': 'a',
          'caseSensitive': false,
          'multiLine': true,
          'dotAll': true,
          'unicode': true,
        },
        onSettingsChanged: (Map<String, Object?> value) => updated = value,
        child: const RegexBody(initialInput: 'A', runner: _runRegex),
      ),
    );

    expect(find.text('MATCH 1 · 0..1'), findsOneWidget);
    await tester.tap(find.text('Dot-all'));
    await tester.pump();
    expect(updated, containsPair('pattern', 'a'));
    expect(updated, containsPair('dotAll', false));
  });

  test('catalog metadata is exact and regex is never auto-detected', () {
    final UtilityDescriptor regex = UtilityCatalog.byId('regex');
    expect(regex.name, 'Regex');
    expect(regex.description, 'Test patterns · captures');
    expect(regex.tint, const Color(0xFFEC4899));
    expect(regex.synonyms, <String>[
      'regex',
      'regexp',
      'pattern',
      'match',
      'capture',
    ]);
    expect(
      UtilityCatalog.detectedTools(
        UtilityCatalog.detectArtifacts(r'(?<year>\d{4})'),
      ).map((UtilityDescriptor tool) => tool.id),
      isNot(contains('regex')),
    );
  });
}

Future<RegexResult> _runRegex({
  required String pattern,
  required String input,
  bool caseSensitive = true,
  bool multiLine = false,
  bool dotAll = false,
  bool unicode = true,
}) async => RegexTester.run(
  pattern: pattern,
  input: input,
  caseSensitive: caseSensitive,
  multiLine: multiLine,
  dotAll: dotAll,
  unicode: unicode,
);

Future<void> _pump(
  WidgetTester tester,
  Widget body, {
  HistoryController? history,
}) async {
  await tester.binding.setSurfaceSize(const Size(1024, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MqTheme(
      tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
      child: CupertinoApp(
        home: HistoryScope(
          controller: history ?? HistoryController(),
          child: CupertinoPageScaffold(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 340,
                child: SingleChildScrollView(child: body),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
