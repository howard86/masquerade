import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Past the longest body debounce (JSON 200 ms) so converts settle.
const Duration _settle = Duration(milliseconds: 300);

Future<void> _pumpDesktop(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MyApp(
      isWebOverride: true,
      viewModeController: ViewModeController(initial: MqViewMode.desktop),
      skipSplash: true,
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens a JSON card from the desktop icon grid.
Future<void> _openJson(WidgetTester tester) async {
  final Finder tile = find.text('JSON / YAML / TOML');
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

/// EditableTexts come in tree order, which follows the canvas card order:
/// the JSON card opens first, the linked Base64 sibling second.
Finder get _jsonInput => find.byType(EditableText).first;
Finder get _base64Input => find.byType(EditableText).last;

String _editableText(WidgetTester tester, Finder f) =>
    tester.widget<EditableText>(f).controller.text;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets(
    'linking a JSON card opens a Base64 sibling seeded with its text',
    (WidgetTester tester) async {
      await _pumpDesktop(tester);
      await _openJson(tester);
      expect(find.byType(ToolCardFrame), findsOneWidget);

      await tester.enterText(_jsonInput, '{"a":1}');
      await tester.pumpAndSettle(_settle);

      await tester.tap(find.bySemanticsLabel('Open linked Base64'));
      await tester.pumpAndSettle(_settle);

      // A second card appeared and shows the Base64 of the JSON text.
      expect(find.byType(ToolCardFrame), findsNWidgets(2));
      expect(
        find.text(base64Encode(utf8.encode('{"a":1}'))), // eyJhIjoxfQ==
        findsOneWidget,
      );
    },
  );

  testWidgets('editing the JSON re-encodes the linked Base64 live', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    await _openJson(tester);
    await tester.enterText(_jsonInput, '{"a":1}');
    await tester.pumpAndSettle(_settle);
    await tester.tap(find.bySemanticsLabel('Open linked Base64'));
    await tester.pumpAndSettle(_settle);

    await tester.enterText(_jsonInput, '{"b":2}');
    await tester.pumpAndSettle(_settle);

    expect(find.text(base64Encode(utf8.encode('{"b":2}'))), findsOneWidget);
  });

  testWidgets('editing the Base64 input pushes the value back into the JSON', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    await _openJson(tester);
    await tester.enterText(_jsonInput, '{"a":1}');
    await tester.pumpAndSettle(_settle);
    await tester.tap(find.bySemanticsLabel('Open linked Base64'));
    await tester.pumpAndSettle(_settle);

    // The fresh Base64 sibling is in Encode mode, so its input holds the plain
    // text. Editing it re-emits the canonical, updating the JSON card's input.
    await tester.enterText(_base64Input, '{"c":3}');
    await tester.pumpAndSettle(_settle);

    expect(_editableText(tester, _jsonInput), '{"c":3}');
  });

  testWidgets(
    'unlinking dissolves the group and restores the open affordance',
    (WidgetTester tester) async {
      await _pumpDesktop(tester);
      await _openJson(tester);
      await tester.tap(find.bySemanticsLabel('Open linked Base64'));
      await tester.pumpAndSettle(_settle);

      // Both linked cards expose an Unlink toggle.
      expect(find.bySemanticsLabel('Unlink'), findsNWidgets(2));

      await tester.tap(find.bySemanticsLabel('Unlink').first);
      await tester.pumpAndSettle();

      // Group gone (it needs ≥2 members) → neither card is linked anymore.
      expect(find.bySemanticsLabel('Unlink'), findsNothing);
      expect(find.bySemanticsLabel('Open linked Base64'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Open linked JSON / YAML / TOML'),
        findsOneWidget,
      );
    },
  );
}
