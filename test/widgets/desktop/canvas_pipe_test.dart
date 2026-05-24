import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/widgets/desktop/pipe.dart';
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

/// Opens the first tool card from the desktop icon grid by its catalog name.
Future<void> _openFirst(WidgetTester tester, String name) async {
  final Finder tile = find.text(name);
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

Finder get _jsonInput => find.byType(EditableText).first;

/// The JSON card's draggable output cell (the only pipe source on the canvas
/// in these tests). Long-pressing it starts a [PipePayload] drag.
Finder get _outputPipe => find.byType(LongPressDraggable<PipePayload>);

/// Drives a [LongPressDraggable] grab→[to]: press at [from], wait past the
/// long-press timeout to arm the drag, move in steps (so the avatar hit-tests
/// each drop target en route), then release.
Future<void> _pipeDrag(WidgetTester tester, Offset from, Offset to) async {
  final TestGesture gesture = await tester.startGesture(from);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  const int steps = 12;
  for (int i = 1; i <= steps; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / steps)!);
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle(_settle);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets(
    'dragging a JSON output cell onto a Base64 card forms a live link',
    (WidgetTester tester) async {
      await _pumpDesktop(tester);
      await _openFirst(tester, 'JSON / YAML / TOML');
      await tester.enterText(_jsonInput, '{"a":1}');
      await tester.pumpAndSettle(_settle);

      // A second, compatible card to drop onto (Base64 receives `text`).
      await _openViaPalette(tester, 'base', 'Base64');
      expect(find.byType(ToolCardFrame), findsNWidgets(2));
      // Not linked yet.
      expect(find.bySemanticsLabel('Unlink'), findsNothing);

      // The fresh Base64 card cascades over the JSON output cell; drag it down
      // by its title bar so the two have a clear drop region.
      await tester.dragFrom(
        tester.getTopLeft(find.byType(ToolCardFrame).last) +
            const Offset(120, 14),
        const Offset(-200, 350),
      );
      await tester.pumpAndSettle();

      // Grab the JSON output cell near its right edge (clear of the Base64
      // card's footprint) and drop it on the Base64 card's center.
      final Rect pipe = tester.getRect(_outputPipe);
      final Offset from = Offset(pipe.right - 30, pipe.center.dy);
      final Offset to = tester.getCenter(find.byType(ToolCardFrame).last);
      await _pipeDrag(tester, from, to);

      // Both cards now expose an Unlink toggle → the group formed.
      expect(find.bySemanticsLabel('Unlink'), findsNWidgets(2));
    },
  );

  testWidgets(
    'dragging an output cell onto empty canvas opens a new seeded card',
    (WidgetTester tester) async {
      await _pumpDesktop(tester);
      await _openFirst(tester, 'JSON / YAML / TOML');
      await tester.enterText(_jsonInput, '{"a":1}');
      await tester.pumpAndSettle(_settle);
      expect(find.byType(ToolCardFrame), findsOneWidget);

      // Drop on empty space far from the single card (bottom-right of canvas).
      await _pipeDrag(
        tester,
        tester.getCenter(_outputPipe),
        const Offset(1050, 800),
      );

      // A second card opened, seeded by the dropped value.
      expect(find.byType(ToolCardFrame), findsNWidgets(2));
    },
  );
}
