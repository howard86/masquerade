import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_icons.dart';
import 'package:masquerade/widgets/desktop/shortcuts_hud.dart';

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
  group('ShortcutsHUD', () {
    testWidgets('shows dialog with correct shortcuts list and handles close action', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (BuildContext context) {
              return CupertinoButton(
                child: const Text('Show HUD'),
                onPressed: () => showShortcutsHUD(context),
              );
            },
          ),
        ),
      );

      // Open HUD
      await tester.tap(find.text('Show HUD'));
      await tester.pumpAndSettle();

      // Check title and labels
      expect(find.text('Desktop Shortcuts'), findsOneWidget);
      expect(find.text('Open Spotlight Search'), findsOneWidget);
      expect(find.text('Focus Window Slot 1-9'), findsOneWidget);
      expect(find.text('Duplicate Window'), findsOneWidget);
      expect(find.text('Close Active Window'), findsOneWidget);
      expect(find.text('Toggle Shortcuts HUD'), findsOneWidget);

      // Verify keycaps
      expect(find.text('⌘'), findsOneWidget);
      expect(find.text('K'), findsOneWidget);
      expect(find.text('⌥'), findsAtLeast(1));
      expect(find.text('1..9'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      expect(find.text('Esc'), findsOneWidget);
      expect(find.text('/'), findsOneWidget);

      // Close the HUD via the close clear icon
      await tester.tap(find.byIcon(MqIcons.clear));
      await tester.pumpAndSettle();

      expect(find.text('Desktop Shortcuts'), findsNothing);
    });
  });
}
