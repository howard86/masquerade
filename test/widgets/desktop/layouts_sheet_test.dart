import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/desktop/layouts_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) {
  return CupertinoApp(
    builder: (BuildContext context, Widget? navigator) => MqTheme(
      tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
      child: navigator ?? const SizedBox.shrink(),
    ),
    home: child,
  );
}

void main() {
  group('LayoutsSheet semantics', () {
    testWidgets('saved-layout row and its delete icon are labelled buttons', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final CanvasController controller = CanvasController(prefs: prefs);
      controller.saveLayout('My Layout');

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (BuildContext context) {
              return CupertinoButton(
                child: const Text('Open'),
                onPressed: () => showLayoutsSheet(context, controller),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final SemanticsHandle handle = tester.ensureSemantics();

      final SemanticsData rowData = tester
          .getSemantics(find.bySemanticsLabel('My Layout'))
          .getSemanticsData();
      expect(rowData.flagsCollection.isButton, isTrue);
      expect(rowData.hasAction(SemanticsAction.tap), isTrue);

      final SemanticsData deleteData = tester
          .getSemantics(find.bySemanticsLabel('Delete My Layout'))
          .getSemanticsData();
      expect(deleteData.flagsCollection.isButton, isTrue);
      expect(deleteData.hasAction(SemanticsAction.tap), isTrue);

      handle.dispose();

      // Delete removes the row and its label from the tree.
      await tester.tap(find.bySemanticsLabel('Delete My Layout'));
      await tester.pumpAndSettle();
      expect(find.text('My Layout'), findsNothing);
    });

    testWidgets('disabled Save row is a non-enabled Semantics button', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final CanvasController controller = CanvasController(prefs: prefs);
      // No cards open → the save row is disabled (onTap == null).

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (BuildContext context) {
              return CupertinoButton(
                child: const Text('Open'),
                onPressed: () => showLayoutsSheet(context, controller),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final SemanticsHandle handle = tester.ensureSemantics();
      final SemanticsData data = tester
          .getSemantics(find.bySemanticsLabel('Save current canvas…'))
          .getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });
  });
}
