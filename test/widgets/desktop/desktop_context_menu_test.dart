import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/desktop/desktop_context_menu.dart';

void main() {
  testWidgets('dismiss barrier excludes itself from semantics; menu items stay '
      'individually reachable', (WidgetTester tester) async {
    late BuildContext capturedContext;
    bool actionFired = false;

    await tester.pumpWidget(
      CupertinoApp(
        // MqTheme must wrap the Navigator/Overlay (not just `home`), since
        // showDesktopContextMenu inserts its OverlayEntry as a sibling of
        // the route content rather than a descendant of it.
        builder: (BuildContext context, Widget? child) => MqTheme(
          tokens: MqTokens(
            colors: MqColors.light(),
            brightness: Brightness.light,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (BuildContext context) {
            capturedContext = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );

    showDesktopContextMenu(
      capturedContext,
      const Offset(20, 20),
      <ContextMenuItem>[
        ContextMenuItem(label: 'Do thing', action: () => actionFired = true),
      ],
    );
    await tester.pumpAndSettle();

    // The full-viewport dismiss barrier must not surface as an unlabelled
    // tappable semantics node; only the labelled menu item should.
    final GestureDetector barrier = tester
        .widgetList<GestureDetector>(find.byType(GestureDetector))
        .firstWhere((GestureDetector d) => d.child is SizedBox);
    expect(barrier.excludeFromSemantics, isTrue);

    await tester.tap(find.text('Do thing'));
    await tester.pumpAndSettle();
    expect(actionFired, isTrue);
  });
}
