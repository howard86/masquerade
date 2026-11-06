import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/utils/math_parser.dart';
import 'package:masquerade/widgets/desktop/desktop_menubar.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';
import 'package:masquerade/widgets/mq/mq_segmented.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<CanvasController> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MyApp(
      desktopShellOverride: true,
      viewModeController: ViewModeController(initial: MqViewMode.desktop),
      skipSplash: true,
    ),
  );
  await tester.pumpAndSettle();
  return tester.widget<DesktopMenubar>(find.byType(DesktopMenubar)).controller;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  // Math sits behind; base64 overlaps its lower-right corner, leaving Math's
  // input and angle toggle exposed.
  Future<(CanvasController, int, int)> openPair(WidgetTester tester) async {
    final CanvasController c = await _pump(tester);
    final int math = c.openTool(UtilityCatalog.byId('math'));
    c.moveTo(math, 20, 40);
    final int other = c.openTool(UtilityCatalog.byId('base64'));
    c.moveTo(other, 560, 200);
    await tester.pumpAndSettle();
    expect(c.cardsByZ.last.id, other);
    return (c, math, other);
  }

  testWidgets('tapping a back window text field raises it and focuses', (
    WidgetTester tester,
  ) async {
    final (CanvasController c, int math, _) = await openPair(tester);
    final Finder field = find.descendant(
      of: find.byType(ToolCardFrame).first,
      matching: find.byType(EditableText),
    );
    final FocusNode node = tester.widget<EditableText>(field.first).focusNode;
    await tester.tap(field.first);
    await tester.pumpAndSettle();

    expect(c.cardsByZ.last.id, math);
    expect(node.hasFocus, isTrue);
  });

  testWidgets('tapping a segmented control in a back window raises it', (
    WidgetTester tester,
  ) async {
    final (CanvasController c, int math, _) = await openPair(tester);
    await tester.tap(find.text('Degrees'));
    await tester.pumpAndSettle();

    expect(c.cardsByZ.last.id, math);
    expect(
      tester
          .widget<MqSegmented<AngleUnit>>(find.byType(MqSegmented<AngleUnit>))
          .selected,
      AngleUnit.degrees,
    );
  });
}
