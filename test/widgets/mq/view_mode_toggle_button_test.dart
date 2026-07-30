import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/view_mode_toggle_button.dart';

Widget _host(Widget child, {required ViewModeController controller}) =>
    CupertinoApp(
      home: MqTheme(
        tokens: MqTokens(
          colors: MqColors.light(),
          brightness: Brightness.light,
        ),
        child: ViewModeScope(
          controller: controller,
          child: CupertinoPageScaffold(child: Center(child: child)),
        ),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('full-size button renders its label', (
    WidgetTester tester,
  ) async {
    final ViewModeController controller = ViewModeController();

    await tester.pumpWidget(
      _host(
        const ViewModeToggleButton(
          target: MqViewMode.desktop,
          label: 'Desktop',
        ),
        controller: controller,
      ),
    );

    expect(find.text('Desktop'), findsOneWidget);
  });

  testWidgets('tapping the full-size button sets the target mode', (
    WidgetTester tester,
  ) async {
    final ViewModeController controller = ViewModeController(
      initial: MqViewMode.mobile,
    );

    await tester.pumpWidget(
      _host(
        const ViewModeToggleButton(
          target: MqViewMode.desktop,
          label: 'Desktop',
        ),
        controller: controller,
      ),
    );

    await tester.tap(find.byType(ViewModeToggleButton));
    await tester.pumpAndSettle();

    expect(controller.mode, MqViewMode.desktop);
  });

  testWidgets('tapping the compact chip sets the target mode', (
    WidgetTester tester,
  ) async {
    final ViewModeController controller = ViewModeController(
      initial: MqViewMode.desktop,
    );

    await tester.pumpWidget(
      _host(
        const ViewModeToggleButton(
          target: MqViewMode.mobile,
          label: 'Mobile',
          compact: true,
        ),
        controller: controller,
      ),
    );

    expect(find.byKey(ViewModeToggleButton.compactKey), findsOneWidget);

    await tester.tap(find.byKey(ViewModeToggleButton.compactKey));
    await tester.pumpAndSettle();

    expect(controller.mode, MqViewMode.mobile);
  });

  testWidgets('compact and full are mutually exclusive', (
    WidgetTester tester,
  ) async {
    expect(
      () => ViewModeToggleButton(
        target: MqViewMode.desktop,
        label: 'Desktop',
        full: true,
        compact: true,
      ),
      throwsAssertionError,
    );
  });

  testWidgets('full-size button exposes a labelled, enabled button node', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final ViewModeController controller = ViewModeController();

    await tester.pumpWidget(
      _host(
        const ViewModeToggleButton(target: MqViewMode.mobile, label: 'Mobile'),
        controller: controller,
      ),
    );

    final SemanticsNode node = tester.getSemantics(
      find.bySemanticsLabel('Mobile'),
    );
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    handle.dispose();
  });

  testWidgets('compact chip exposes a labelled button semantics node', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final ViewModeController controller = ViewModeController();

    await tester.pumpWidget(
      _host(
        const ViewModeToggleButton(
          target: MqViewMode.desktop,
          label: 'Switch to desktop',
          compact: true,
        ),
        controller: controller,
      ),
    );

    // The chip's tap action lives on the nested CupertinoButton node; this
    // outer node is what exposes the label a screen reader announces.
    final SemanticsNode node = tester.getSemantics(
      find.bySemanticsLabel('Switch to desktop'),
    );
    expect(node.flagsCollection.isButton, isTrue);

    handle.dispose();
  });
}
