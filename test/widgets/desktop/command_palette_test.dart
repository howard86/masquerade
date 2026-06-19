import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/desktop_icon_grid.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';
import 'package:masquerade/widgets/mq/mq_empty_hint.dart';
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

    testWidgets('opens from the menubar and opens a card', (
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

      // Icon grid is visible.
      expect(find.byType(DesktopIconGrid), findsOneWidget);

      // Open the palette via File → New tool…
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New tool…  ⌘K'));
      await tester.pumpAndSettle();
      expect(find.text('Open a tool…'), findsOneWidget);

      // Filter to a specific tool and pick it.
      await tester.enterText(
        find.byKey(const ValueKey<String>('command-palette-field')),
        'diff',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Diff').last);
      await tester.pumpAndSettle();

      expect(find.byType(ToolCardFrame), findsOneWidget);
    });

    testWidgets('a query matching no tool shows the empty-state hint', (
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

      // Open the palette via File → New tool…
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New tool…  ⌘K'));
      await tester.pumpAndSettle();

      // Type a nonsense query that matches no tool name/synonym/shape.
      await tester.enterText(
        find.byKey(const ValueKey<String>('command-palette-field')),
        'zzzzz',
      );
      await tester.pumpAndSettle();

      // The empty-state hint is shown…
      expect(find.byType(MqEmptyHint), findsOneWidget);
      expect(find.text('No tools found'), findsOneWidget);

      // …and zero result rows render (the ListView is replaced by the hint).
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(ToolCardFrame), findsNothing);
    });

    testWidgets('typing a detectable value shows "Open X with this value"', (
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

      // Open the palette via File → New tool…
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New tool…  ⌘K'));
      await tester.pumpAndSettle();

      // Type a UUID — should be detected.
      await tester.enterText(
        find.byKey(const ValueKey<String>('command-palette-field')),
        '550e8400-e29b-41d4-a716-446655440000',
      );
      await tester.pumpAndSettle();

      // The detect row should appear.
      expect(find.text('Open UUID with this value'), findsOneWidget);

      // Tapping it opens the tool seeded.
      await tester.tap(find.text('Open UUID with this value'));
      await tester.pumpAndSettle();
      expect(find.byType(ToolCardFrame), findsOneWidget);
    });
  });
}
