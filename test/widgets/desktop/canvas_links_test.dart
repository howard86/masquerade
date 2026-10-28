import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/link_group.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/desktop_menubar.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Past the longest body debounce (JSON 200 ms) so converts settle.
const Duration _settle = Duration(milliseconds: 300);

Future<void> _pumpDesktop(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MyApp(
      desktopShellOverride: true,
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

Future<void> _openTimestamp(WidgetTester tester) async {
  final Finder tile = find.text('Timestamp');
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> _openMath(WidgetTester tester) async {
  final Finder tile = find.text('Math');
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

CanvasController _canvasController(WidgetTester tester) =>
    tester.widget<DesktopMenubar>(find.byType(DesktopMenubar)).controller;

Future<void> _minimizeAndRestore(
  WidgetTester tester,
  CanvasController canvas,
  int cardId,
) async {
  canvas.minimize(cardId);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  canvas.restoreWindow(cardId);
  await tester.pumpAndSettle(_settle);
}

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
      expect(find.text('LIVE · TEXT'), findsNWidgets(2));
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
    'new link seeding authority is consumed before either body remounts',
    (WidgetTester tester) async {
      await _pumpDesktop(tester);
      await _openJson(tester);
      await tester.enterText(_jsonInput, '{"value":"A"}');
      await tester.pumpAndSettle(_settle);
      await tester.tap(find.bySemanticsLabel('Open linked Base64'));
      await tester.pumpAndSettle(_settle);

      final CanvasController canvas = _canvasController(tester);
      final int jsonCard = canvas.cards.first.id;
      final int base64Card = canvas.cards.last.id;
      const String updated = '{"value":"B"}';

      expect(canvas.groups.single.canonical.value, '{"value":"A"}');
      expect(canvas.groups.single.seedOwnerCardId, isNull);
      await tester.enterText(_jsonInput, updated);
      await tester.pumpAndSettle(_settle);
      expect(canvas.groups.single.canonical.value, updated);
      expect(_editableText(tester, _base64Input), updated);

      await _minimizeAndRestore(tester, canvas, jsonCard);
      expect(canvas.groups.single.canonical.value, updated);
      expect(_editableText(tester, _jsonInput), updated);
      expect(_editableText(tester, _base64Input), updated);

      await _minimizeAndRestore(tester, canvas, base64Card);
      expect(canvas.groups.single.canonical.value, updated);
      expect(_editableText(tester, _jsonInput), updated);
      expect(_editableText(tester, _base64Input), updated);
    },
  );

  testWidgets('an empty new-group source consumes authority before remount', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    await _openJson(tester);
    await tester.tap(find.bySemanticsLabel('Open linked Base64'));
    await tester.pumpAndSettle(_settle);

    final CanvasController canvas = _canvasController(tester);
    final int jsonCard = canvas.cards.first.id;
    final int base64Card = canvas.cards.last.id;
    const String targetValue = '{"target":true}';

    expect(canvas.groups.single.canonical.value, isEmpty);
    expect(canvas.groups.single.seedOwnerCardId, isNull);
    await tester.enterText(_base64Input, targetValue);
    await tester.pumpAndSettle(_settle);
    expect(canvas.groups.single.canonical.value, targetValue);
    expect(_editableText(tester, _jsonInput), targetValue);

    await _minimizeAndRestore(tester, canvas, jsonCard);
    expect(canvas.groups.single.canonical.value, targetValue);
    expect(_editableText(tester, _jsonInput), targetValue);

    await _minimizeAndRestore(tester, canvas, base64Card);
    expect(canvas.groups.single.canonical.value, targetValue);
    expect(_editableText(tester, _base64Input), targetValue);
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

  testWidgets('the link picker opens an unpaired tool and shows its status', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    await _openTimestamp(tester);
    await tester.enterText(_jsonInput, '1700000000');
    await tester.pumpAndSettle(_settle);

    final Finder linkButton = find.bySemanticsLabel('Choose live link target');
    expect(linkButton, findsOneWidget);
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(linkButton));
    await tester.pump(const Duration(milliseconds: 500));
    final Finder hoverHint = find.text('Choose live link target');
    expect(hoverHint, findsOneWidget);
    final Rect hintRect = tester.getRect(hoverHint);
    final Rect buttonRect = tester.getRect(linkButton);
    expect(hintRect.bottom, lessThan(buttonRect.top));
    expect(hintRect.width, lessThan(320));
    await tester.tap(linkButton);
    await mouse.removePointer();
    await tester.pumpAndSettle();

    expect(find.text('Link Timestamp'), findsOneWidget);
    expect(
      find.textContaining('Live links update both windows.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Open Math · Epoch'));
    await tester.pumpAndSettle(_settle);

    expect(find.byType(ToolCardFrame), findsNWidgets(2));
    expect(find.bySemanticsLabel('Unlink'), findsNWidgets(2));
    expect(find.text('LIVE · EPOCH'), findsNWidgets(2));
    expect(find.text('1700000000'), findsWidgets);
  });

  testWidgets('Escape cancels the link picker without closing its source', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    await _openTimestamp(tester);
    await tester.tap(find.bySemanticsLabel('Choose live link target'));
    await tester.pumpAndSettle();
    expect(find.text('Link Timestamp'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Link Timestamp'), findsNothing);
    expect(find.byType(ToolCardFrame), findsOneWidget);
    expect(find.bySemanticsLabel('Unlink'), findsNothing);
  });

  testWidgets('the link picker connects to a compatible open window', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    await _openTimestamp(tester);
    await _openMath(tester);

    await tester.tap(find.bySemanticsLabel('Choose live link target'));
    await tester.pumpAndSettle();
    expect(find.text('Link to Math · Epoch'), findsOneWidget);
    await tester.tap(find.text('Link to Math · Epoch'));
    await tester.pumpAndSettle(_settle);

    expect(find.byType(ToolCardFrame), findsNWidgets(2));
    expect(find.text('LIVE · EPOCH'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Unlink'), findsNWidgets(2));
  });

  testWidgets('linked member hints update after joins and a peer closes', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    await _openJson(tester);
    await tester.tap(find.bySemanticsLabel('Open linked Base64'));
    await tester.pumpAndSettle(_settle);

    final CanvasController canvas = tester
        .widget<DesktopMenubar>(find.byType(DesktopMenubar))
        .controller;
    final int jsonCard = canvas.cards.first.id;
    final int base64Card = canvas.cards.last.id;
    final Finder jsonUnlink = find.descendant(
      of: find.byType(ToolCardFrame).first,
      matching: find.bySemanticsLabel('Unlink'),
    );

    String linkHint() =>
        tester.getSemantics(jsonUnlink).getSemanticsData().hint;

    expect(linkHint(), contains('Connected to Base64 using Text'));

    final int listCard = canvas.openTool(UtilityCatalog.byId('list'));
    canvas.linkCards(jsonCard, listCard, type: ContentType.text);
    await tester.pumpAndSettle(_settle);
    expect(linkHint(), contains('Base64'));
    expect(linkHint(), contains('List'));

    canvas.close(base64Card);
    await tester.pumpAndSettle(_settle);
    expect(linkHint(), contains('Connected to List using Text'));
    expect(linkHint(), isNot(contains('Base64')));
  });
}
