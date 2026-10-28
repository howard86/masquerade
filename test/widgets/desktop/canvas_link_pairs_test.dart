import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/widgets/desktop/desktop_menubar.dart';
import 'package:masquerade/widgets/desktop/pipe.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';
import 'package:masquerade/widgets/mq/mq_input.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 6 — the four remaining canonical-hub link pairs (docs/adr/0001):
/// Number Base ↔ Math, Timestamp ↔ Math, List ↔ Diff, Color ↔ text. Each test
/// forms the link (toggle or drop), edits one side, and asserts the other
/// re-projects — plus that linked cards expose an Unlink toggle.

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

/// Opens the first card from the desktop icon grid by its catalog name.
Future<void> _openFirst(WidgetTester tester, String name) async {
  final Finder tile = find.text(name).first;
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

/// Opens an additional card via the menubar File → New tool… palette.
/// [query] filters the list; [resultName] is the exact tool name to tap.
Future<void> _openViaPalette(
  WidgetTester tester,
  String query,
  String resultName,
) async {
  await tester.tap(find.text('File'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('New tool…  ⌘K'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey<String>('command-palette-field')),
    query,
  );
  await tester.pumpAndSettle();
  // Use .last because the icon grid label also matches the tool name.
  await tester.tap(find.text(resultName).last);
  await tester.pumpAndSettle();
}

/// EditableTexts come in tree order, which follows the canvas card order: the
/// first-opened card's field(s) precede the linked sibling's.
Finder get _firstInput => find.byType(EditableText).first;
Finder get _lastInput => find.byType(EditableText).last;

Finder _inputByLabel(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (Widget widget) => widget is MqInput && widget.label == label,
  ),
  matching: find.byType(EditableText),
);

String _editableText(WidgetTester tester, Finder f) =>
    tester.widget<EditableText>(f).controller.text;

/// Drives a [LongPressDraggable] grab→[to]: press at [from], wait past the
/// long-press timeout to arm the drag, move in steps (so the avatar hit-tests
/// each drop target en route), then release.
Future<void> _pipeDrag(WidgetTester tester, Offset from, Offset to) async {
  final TestGesture gesture = await _startPipeDrag(tester, from, to);
  await gesture.up();
  await tester.pumpAndSettle(_settle);
}

Future<TestGesture> _startPipeDrag(
  WidgetTester tester,
  Offset from,
  Offset to,
) async {
  final TestGesture gesture = await tester.startGesture(from);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  const int steps = 12;
  for (int i = 1; i <= steps; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / steps)!);
    await tester.pump();
  }
  return gesture;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Number Base ↔ Math links and re-projects both ways', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    await _openFirst(tester, 'Number Base');
    await tester.enterText(_firstInput, '0xFF');
    await tester.pumpAndSettle(_settle);

    // Header toggle opens a linked Math sibling, seeded with 255 (0xFF).
    await tester.tap(find.bySemanticsLabel('Open linked Math'));
    await tester.pumpAndSettle(_settle);
    expect(find.byType(ToolCardFrame), findsNWidgets(2));
    expect(find.bySemanticsLabel('Unlink'), findsNWidgets(2));

    // Math projects the canonical decimal as its result.
    expect(
      find.descendant(of: find.byType(MqMonoCell), matching: find.text('255')),
      findsWidgets,
    );

    // Edit Number Base → Math re-evaluates the new decimal.
    await tester.enterText(_firstInput, '0x10');
    await tester.pumpAndSettle(_settle);
    expect(
      find.descendant(of: find.byType(MqMonoCell), matching: find.text('16')),
      findsWidgets,
    );

    // Edit Math → Number Base re-parses the result's decimal.
    await tester.enterText(_lastInput, '2*5');
    await tester.pumpAndSettle(_settle);
    expect(
      find.descendant(of: find.byType(MqMonoCell), matching: find.text('10')),
      findsWidgets,
    );

    // A temporary parse error leaves the last good canonical value in peers.
    await tester.enterText(_lastInput, 'unknown(1)');
    await tester.pumpAndSettle(_settle);
    expect(_editableText(tester, _inputByLabel('Input')), '10');

    await tester.enterText(_lastInput, '');
    await tester.pumpAndSettle(_settle);
    expect(_editableText(tester, _inputByLabel('Input')), isEmpty);

    // Invalid Number Base edits retain the last good value; an intentional
    // clear still propagates to the linked Math card.
    await tester.enterText(_firstInput, '0x2A');
    await tester.pumpAndSettle(_settle);
    expect(_editableText(tester, _lastInput), '42');

    await tester.enterText(_firstInput, 'not a number');
    await tester.pumpAndSettle(_settle);
    expect(_editableText(tester, _lastInput), '42');

    await tester.enterText(_firstInput, '');
    await tester.pumpAndSettle(_settle);
    expect(_editableText(tester, _lastInput), isEmpty);
  });

  testWidgets('List ↔ Diff links and re-projects both ways', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    await _openFirst(tester, 'List');
    await tester.enterText(_firstInput, 'apple,banana');
    await tester.pumpAndSettle(_settle);

    // Header toggle opens a linked Diff sibling; List's raw text seeds side A.
    await tester.tap(find.bySemanticsLabel('Open linked Diff'));
    await tester.pumpAndSettle(_settle);
    expect(find.byType(ToolCardFrame), findsNWidgets(2));
    expect(find.bySemanticsLabel('Unlink'), findsNWidgets(2));

    // Diff side A is the first EditableText of the second card.
    final Finder diffA = find.byType(EditableText).at(1);
    expect(_editableText(tester, diffA), 'apple,banana');

    // Edit List → Diff side A updates.
    await tester.enterText(_firstInput, 'cherry,date');
    await tester.pumpAndSettle(_settle);
    expect(_editableText(tester, diffA), 'cherry,date');

    // Edit Diff side A → List input updates (List's canonical is its input).
    await tester.enterText(diffA, 'elderberry,fig');
    await tester.pumpAndSettle(_settle);
    expect(_editableText(tester, _firstInput), 'elderberry,fig');
  });

  testWidgets('Timestamp ↔ Math links via drop and re-projects both ways', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    // A 10-digit epoch parses as unix seconds; its "Unix seconds" output cell
    // is the epoch pipe source.
    await _openFirst(tester, 'Timestamp');
    await tester.enterText(_firstInput, '1700000000');
    await tester.pumpAndSettle(_settle);

    // Open a Math card to drop onto (it receives epoch).
    await _openViaPalette(tester, 'calc', 'Math');
    expect(find.byType(ToolCardFrame), findsNWidgets(2));
    expect(find.bySemanticsLabel('Unlink'), findsNothing);

    // Move the fresh Math card to the right so it fully clears the (tall)
    // Timestamp card and its low "Unix seconds" output cell.
    await tester.dragFrom(
      tester.getTopLeft(find.byType(ToolCardFrame).last) +
          const Offset(120, 14),
      const Offset(420, 40),
    );
    await tester.pumpAndSettle();

    // Drag the Timestamp "Unix seconds" cell onto the Math card → link. The
    // Timestamp card is first, so its only pipe cell is the first draggable.
    final Finder secondsPipe = find
        .byType(LongPressDraggable<PipePayload>)
        .first;
    final Rect pipe = tester.getRect(secondsPipe);
    final Offset from = Offset(pipe.right - 30, pipe.center.dy);
    final Offset to = tester.getCenter(find.byType(ToolCardFrame).last);
    await _pipeDrag(tester, from, to);

    expect(find.bySemanticsLabel('Unlink'), findsNWidgets(2));
    // Math evaluates the dropped epoch as a plain number.
    expect(
      find.descendant(
        of: find.byType(MqMonoCell),
        matching: find.text('1700000000'),
      ),
      findsWidgets,
    );

    // Edit Math → Timestamp re-parses the new epoch (round-trips to seconds).
    final Finder mathInput = _inputByLabel('Expression');
    await tester.enterText(mathInput, '1800000000');
    await tester.pumpAndSettle(_settle);
    expect(
      find.descendant(
        of: find.byType(MqMonoCell),
        matching: find.text('1800000000'),
      ),
      findsWidgets,
    );

    final Finder timestampInput = _inputByLabel('Input');
    await tester.enterText(timestampInput, 'not a timestamp');
    await tester.pumpAndSettle(_settle);
    expect(_editableText(tester, mathInput), '1800000000');

    await tester.enterText(timestampInput, '');
    await tester.pumpAndSettle(_settle);
    expect(_editableText(tester, mathInput), isEmpty);
  });

  testWidgets('choosing an existing target keeps the selected source value', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    await _openFirst(tester, 'Timestamp');
    await tester.enterText(_firstInput, '1700000000');
    await tester.pumpAndSettle(_settle);
    await _openViaPalette(tester, 'calc', 'Math');
    await tester.enterText(_lastInput, '2+3');
    await tester.pumpAndSettle(_settle);

    await tester.tap(find.bySemanticsLabel('Choose live link target'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link to Math · Epoch'));
    await tester.pumpAndSettle(_settle);

    expect(find.bySemanticsLabel('Unlink'), findsNWidgets(2));
    expect(_editableText(tester, _lastInput), '1700000000');
    expect(find.text('LIVE · EPOCH'), findsNWidgets(2));
  });

  testWidgets('source value wins when the populated target opened first', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    await _openFirst(tester, 'Math');
    await tester.enterText(_inputByLabel('Expression'), '2+3');
    await tester.pumpAndSettle(_settle);

    await _openViaPalette(tester, 'timestamp', 'Timestamp');
    await tester.enterText(_inputByLabel('Input'), '1700000000');
    await tester.pumpAndSettle(_settle);
    await tester.tap(find.bySemanticsLabel('Choose live link target'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link to Math · Epoch'));
    await tester.pumpAndSettle(_settle);

    expect(_editableText(tester, _inputByLabel('Expression')), '1700000000');
    expect(_editableText(tester, _inputByLabel('Input')), '1700000000');
    expect(find.text('LIVE · EPOCH'), findsNWidgets(2));
  });

  testWidgets(
    'restored canonical beats JSON and Base64 seeds on attach and remount',
    (WidgetTester tester) async {
      const String stale = '{"value":"A"}';
      const String saved = '{"value":"B"}';
      SharedPreferences.setMockInitialValues(<String, Object>{
        CanvasController.currentKey: jsonEncode(<String, dynamic>{
          'nextId': 3,
          'nextGroupId': 2,
          'nextZ': 3,
          'focused': 1,
          'cards': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'tool': 'json',
              'x': 60.0,
              'y': 80.0,
              'w': 380.0,
              'seed': stale,
            },
            <String, dynamic>{
              'id': 2,
              'tool': 'base64',
              'x': 480.0,
              'y': 80.0,
              'w': 380.0,
              'seed': base64Encode(utf8.encode(stale)),
            },
          ],
          'groups': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'type': 'text',
              'canonical': saved,
              'members': <int>[1, 2],
            },
          ],
        }),
      });

      await _pumpDesktop(tester);
      final CanvasController canvas = tester
          .widget<DesktopMenubar>(find.byType(DesktopMenubar))
          .controller;

      void expectRestoredValue() {
        expect(canvas.groups.single.canonical.value, saved);
        expect(_editableText(tester, _inputByLabel('Input').first), saved);
        expect(
          _editableText(tester, _inputByLabel('Input').last),
          base64Encode(utf8.encode(saved)),
        );
      }

      await tester.pumpAndSettle(_settle);
      expectRestoredValue();

      // Minimizing removes the body State; restoring remounts it from the
      // persisted stale seed while the group canonical remains authoritative.
      canvas.minimize(2);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(ToolCardFrame), findsOneWidget);
      expect(find.byType(MqInput), findsOneWidget);

      canvas.restoreWindow(2);
      await tester.pumpAndSettle(_settle);
      expect(find.byType(MqInput), findsNWidgets(2));
      expectRestoredValue();
    },
  );

  testWidgets('Color ↔ text links via drop and re-projects both ways', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    // A List card is the text pipe source (its Join output is a bare hex
    // string, no quotes); the Color card receives `text` and parses the hex.
    // Open both cards before seeding List — a hex in List would add an
    // "Open in Color" footer chip, colliding with the palette's Color result.
    await _openFirst(tester, 'List');
    // Open a Color card to drop onto. Its cold placeholder must NOT seed the
    // group — the dropped hex wins.
    await _openViaPalette(tester, 'rgb', 'Color');
    expect(find.byType(ToolCardFrame), findsNWidgets(2));
    expect(find.bySemanticsLabel('Unlink'), findsNothing);

    // Move the fresh Color card to the right so it's fully on-screen and its
    // body clears the List card's output column.
    await tester.dragFrom(
      tester.getTopLeft(find.byType(ToolCardFrame).last) +
          const Offset(120, 14),
      const Offset(520, 20),
    );
    await tester.pumpAndSettle();

    // Now seed the List card with a bare hex string.
    await tester.enterText(_firstInput, '#445566');
    await tester.pumpAndSettle(_settle);

    // Drag the List "Joined" output cell onto the Color card → link on text.
    // List is the first card, so its Joined cell is the first draggable.
    final Finder listPipe = find.byType(LongPressDraggable<PipePayload>).first;
    final Offset from = tester.getCenter(listPipe);
    final Offset to = tester.getCenter(find.byType(ToolCardFrame).last);
    await _pipeDrag(tester, from, to);

    expect(find.bySemanticsLabel('Unlink'), findsNWidgets(2));
    // Color parsed the dropped hex → its canonical HEX cell shows #445566.
    expect(
      find.descendant(
        of: find.byType(MqMonoCell),
        matching: find.text('#445566'),
      ),
      findsWidgets,
    );

    // Edit Color → List input re-projects (List's canonical is its raw text).
    final Finder colorInput = _inputByLabel('Color');
    final Finder listInput = _inputByLabel('Input');
    await tester.enterText(colorInput, '#778899');
    await tester.pumpAndSettle(_settle);
    expect(_editableText(tester, listInput), '#778899');

    await tester.enterText(colorInput, 'not a color');
    await tester.pumpAndSettle(_settle);
    expect(_editableText(tester, listInput), '#778899');

    await tester.enterText(colorInput, '');
    await tester.pumpAndSettle(_settle);
    expect(_editableText(tester, listInput), isEmpty);
  });

  testWidgets('a rejected drop explains the incompatible value type', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    await _openFirst(tester, 'Number Base');
    await tester.enterText(_firstInput, '255');
    await tester.pumpAndSettle(_settle);
    await _openFirst(tester, 'Color');
    await tester.dragFrom(
      tester.getTopLeft(find.byType(ToolCardFrame).last) +
          const Offset(120, 14),
      const Offset(520, 20),
    );
    await tester.pumpAndSettle();

    final Finder numberOutput = find
        .byType(LongPressDraggable<PipePayload>)
        .first;
    final TestGesture gesture = await _startPipeDrag(
      tester,
      tester.getCenter(numberOutput),
      tester.getCenter(find.byType(ToolCardFrame).last),
    );

    expect(
      find.text('This target cannot receive a live number value.'),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Unlink'), findsNothing);
    expect(
      find.text('This target cannot receive a live number value.'),
      findsNothing,
    );
  });
}
