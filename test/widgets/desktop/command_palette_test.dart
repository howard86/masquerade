import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';
import 'package:masquerade/widgets/mq/tool_grid_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UtilityCatalog.searchByName', () {
    test('empty query returns the whole catalog in catalog order', () {
      final List<UtilityDescriptor> r = UtilityCatalog.searchByName('');
      expect(r.length, UtilityCatalog.all.length);
      expect(r.first.id, UtilityCatalog.all.first.id);
    });

    test('exact name scores above a substring synonym', () {
      final List<UtilityDescriptor> r = UtilityCatalog.searchByName('diff');
      expect(r.first.id, 'diff');
    });

    test('synonym matches a tool by alias, not just name', () {
      final List<UtilityDescriptor> r = UtilityCatalog.searchByName('crontab');
      expect(r.first.id, 'cron');
    });

    test(
      'ignores input shape — a number query still name-matches nothing odd',
      () {
        // "json" is a name; shape detection is irrelevant here.
        final List<UtilityDescriptor> r = UtilityCatalog.searchByName('yaml');
        expect(r.first.id, 'json'); // yaml is a JSON-tool synonym
      },
    );
  });

  group('command palette (desktop)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('opens from the canvas top bar and opens a second card', (
      WidgetTester tester,
    ) async {
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

      // Open the first card so the canvas top bar (with the ⌘K pill) appears.
      await tester.tap(find.byType(ToolGridCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(ToolCardFrame), findsOneWidget);

      // Open the palette via its top-bar pill.
      await tester.tap(find.text('⌘K  Open tool'));
      await tester.pumpAndSettle();
      expect(find.text('Open a tool…'), findsOneWidget);

      // Filter to a specific tool and pick it.
      await tester.enterText(
        find.byKey(const ValueKey<String>('command-palette-field')),
        'diff',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Diff'));
      await tester.pumpAndSettle();

      // Two cards now live on the canvas.
      expect(find.byType(ToolCardFrame), findsNWidgets(2));
    });
  });
}
