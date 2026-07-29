import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/utils/timestamp_parser.dart';
import 'package:masquerade/widgets/tool_bodies/timestamp_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> openTimestamp(WidgetTester tester) async {
    await pumpHomeAndOpen(tester, 'Timestamp');
  }

  testWidgets(
    'Timestamp ambiguity banner shows for values in seconds/ms overlap range',
    (WidgetTester tester) async {
      await openTimestamp(tester);

      final Finder input = find.byType(EditableText).last;
      await tester.enterText(input, '1700000000');
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(
        find.textContaining('Ambiguous — reading as seconds'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Timestamp reuses a compatible detected parser result', (
    WidgetTester tester,
  ) async {
    const String raw = 'not a timestamp';
    await pumpBodyAtWidth(
      tester,
      TimestampBody(
        initialInput: raw,
        initialArtifact: Artifact<Object?>(
          kind: ArtifactKind.timestamp,
          rawValue: raw,
          provenance: ArtifactProvenance.camera,
          parserResult: TimestampParseResult(
            timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            format: TimestampFormat.unixSeconds,
          ),
        ),
      ),
      380,
    );

    expect(find.text('UNIX SECONDS'), findsOneWidget);
    expect(find.textContaining('Invalid input format'), findsNothing);
  });

  testWidgets('Timestamp ambiguity banner hidden for unambiguous ms value', (
    WidgetTester tester,
  ) async {
    await openTimestamp(tester);

    final Finder input = find.byType(EditableText).last;
    await tester.enterText(input, '1700000000000');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.textContaining('Ambiguous'), findsNothing);
  });

  testWidgets('Tapping ambiguity banner toggles seconds ↔ milliseconds', (
    WidgetTester tester,
  ) async {
    await openTimestamp(tester);

    final Finder input = find.byType(EditableText).last;
    await tester.enterText(input, '1700000000');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(
      find.textContaining('Ambiguous — reading as seconds'),
      findsOneWidget,
    );
    expect(find.text('UNIX SECONDS'), findsOneWidget);

    await tester.tap(find.textContaining('Ambiguous'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(
      find.textContaining('Ambiguous — reading as milliseconds'),
      findsOneWidget,
    );
    expect(find.text('UNIX MS'), findsOneWidget);
  });

  testWidgets('16-digit input renders Unix µs label', (
    WidgetTester tester,
  ) async {
    await openTimestamp(tester);

    final Finder input = find.byType(EditableText).last;
    await tester.enterText(input, '1700000000000000');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // 'µ' (U+00B5) uppercases to Greek capital Mu (U+039C) in Dart's default
    // locale, so the rendered badge text contains 'ΜS' not 'µS'.
    expect(find.text('UNIX ΜS'), findsOneWidget);
  });

  testWidgets('19-digit input renders Unix ns label', (
    WidgetTester tester,
  ) async {
    await openTimestamp(tester);

    final Finder input = find.byType(EditableText).last;
    await tester.enterText(input, '1700000000000000000');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('UNIX NS'), findsOneWidget);
  });

  testWidgets('naïve ISO renders local-TZ-assumed badge', (
    WidgetTester tester,
  ) async {
    await openTimestamp(tester);

    final Finder input = find.byType(EditableText).last;
    await tester.enterText(input, '2023-11-14T22:13:20');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('LOCAL TZ ASSUMED'), findsOneWidget);
  });

  testWidgets('ISO with Z does not show local-TZ-assumed badge', (
    WidgetTester tester,
  ) async {
    await openTimestamp(tester);

    final Finder input = find.byType(EditableText).last;
    await tester.enterText(input, '2023-11-14T22:13:20Z');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('LOCAL TZ ASSUMED'), findsNothing);
  });

  testWidgets('picking today from anchor sheet resolves as Keyword', (
    WidgetTester tester,
  ) async {
    await openTimestamp(tester);

    // Tap the trailing clock icon → opens the keyword picker modal.
    await tester.tap(find.bySemanticsLabel('Insert keyword'));
    await tester.pumpAndSettle();

    // Tap the Anchor select row inside the modal.
    await tester.tap(find.text('now / today / yesterday / tomorrow'));
    await tester.pumpAndSettle();

    // Pick `today` from the nested action sheet.
    await tester.tap(find.text('today'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Dismiss the modal.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('KEYWORD'), findsOneWidget);
  });

  testWidgets('picking last + hour from pair row resolves composite Keyword', (
    WidgetTester tester,
  ) async {
    await openTimestamp(tester);

    await tester.tap(find.bySemanticsLabel('Insert keyword'));
    await tester.pumpAndSettle();

    // Tap the Relative compact row — its visible value is the default 'this'.
    await tester.tap(find.text('this'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('last'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Modal refresh: 'this' gone, 'last' visible in the row.
    expect(find.text('this'), findsNothing);
    expect(find.text('last'), findsOneWidget);

    // Input auto-updates immediately (before Done).
    EditableText liveInput = tester.widget<EditableText>(
      find.byType(EditableText).last,
    );
    expect(liveInput.controller.text, 'last hour');

    // Tap the Unit compact row — its visible value is the default 'hour'.
    // Two 'hour' texts now exist: the row value and the action sheet item.
    // The first one is the row; tap it to open the picker.
    await tester.tap(find.text('hour').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('day').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Input updates again after second pick.
    liveInput = tester.widget<EditableText>(find.byType(EditableText).last);
    expect(liveInput.controller.text, 'last day');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('KEYWORD'), findsOneWidget);
  });

  testWidgets('typing now resolves as Keyword', (WidgetTester tester) async {
    await openTimestamp(tester);

    final Finder input = find.byType(EditableText).last;
    await tester.enterText(input, 'now');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('KEYWORD'), findsOneWidget);
  });

  testWidgets(
    'Timestamp — Copy all writes every derived form to the clipboard',
    (WidgetTester tester) async {
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

      await openTimestamp(tester);

      await tester.enterText(find.byType(EditableText).last, '1700000000000');
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      await tester.tap(find.text('Copy all'));
      await tester.pump();

      expect(clipboardWrites, hasLength(1));
      final String written = clipboardWrites.single;
      expect(written, contains('1700000000')); // Unix seconds
      expect(written, contains('1700000000000')); // Unix ms
      expect(written, contains('2023-11-14T22:13:20.000Z')); // ISO 8601
      expect(written, contains('2023-11-14 22:13:20')); // UTC date row

      // Drain the copy toast's 3s auto-dismiss timer so the test ends clean.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Timestamp — Copy all is hidden when there is no output', (
    WidgetTester tester,
  ) async {
    await openTimestamp(tester);

    // Empty input → nothing parsed → the center action stays hidden.
    expect(find.text('Copy all'), findsNothing);

    // It appears once something parses…
    await tester.enterText(find.byType(EditableText).last, '1700000000000');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('Copy all'), findsOneWidget);

    // …and disappears again when the input is cleared.
    await tester.enterText(find.byType(EditableText).last, '');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('Copy all'), findsNothing);
  });

  testWidgets(
    'keyword picker _SelectRows expose state-aware button semantics',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await openTimestamp(tester);

      // Open the keyword picker modal holding the three _SelectRow pickers.
      await tester.tap(find.bySemanticsLabel('Insert keyword'));
      await tester.pumpAndSettle();

      // Each picker row announces its purpose + current value as a button so a
      // screen reader can name and operate it (not a bare GestureDetector).
      // The explicit Semantics label leads the merged node label (descendant
      // Text merges after it), so match on the leading curated string.
      const List<String> expectedLabels = <String>[
        'Anchor, now / today / yesterday / tomorrow',
        'Relative, this',
        'Unit, hour',
      ];
      for (final String label in expectedLabels) {
        final Finder row = find.byWidgetPredicate(
          (Widget w) => w is Semantics && w.properties.label == label,
        );
        expect(row, findsOneWidget, reason: 'missing button label: $label');
        final SemanticsData data = tester.getSemantics(row).getSemanticsData();
        expect(
          data.flagsCollection.isButton,
          isTrue,
          reason: '"$label" should expose the button role',
        );
        expect(
          data.label,
          startsWith(label),
          reason: '"$label" should lead the announced label',
        );
      }

      handle.dispose();
    },
  );
}
