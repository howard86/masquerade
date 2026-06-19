import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/desktop_icon_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _desktop = Size(1200, 900);

Future<void> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_desktop);
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

/// Minimal harness that hosts the grid alone in a single focus scope so Tab
/// traversal and keyboard activation are deterministic. [opened] captures the
/// tools launched via [DesktopIconGrid.onOpen].
Future<void> _pumpGrid(
  WidgetTester tester,
  List<UtilityDescriptor> opened,
) async {
  await tester.binding.setSurfaceSize(_desktop);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    CupertinoApp(
      home: MqTheme(
        tokens: MqTokens(
          colors: MqColors.light(),
          brightness: Brightness.light,
        ),
        child: DesktopIconGrid(onOpen: opened.add, onOpenSystem: (_) {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The tool name of the currently-focused launcher tile, read off the
/// [Semantics] wrapper enclosing the focused node, or null if no tile is
/// focused. Lets arrow-traversal assertions name the spatially-adjacent tile
/// without relying on anonymous tile [FocusNode]s.
String? _focusedTileLabel() {
  final BuildContext? ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return null;
  String? label;
  ctx.visitAncestorElements((Element e) {
    final Widget w = e.widget;
    if (w is Semantics && w.properties.label != null) {
      label = w.properties.label;
      return false;
    }
    return true;
  });
  return label;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('DesktopIconGrid', () {
    testWidgets('renders tiles for all catalog tools', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      expect(find.byType(DesktopIconGrid), findsOneWidget);
      // Each tool name should appear as a label.
      for (final UtilityDescriptor d in UtilityCatalog.all) {
        expect(find.text(d.name), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('tapping a tile opens a card with the correct tool', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final UtilityDescriptor first = UtilityCatalog.all.first;
      await tester.tap(find.text(first.name));
      await tester.pumpAndSettle();
      // The tool card frame should now be visible.
      expect(
        find.text(first.name),
        findsAtLeastNWidgets(2), // icon label + card title
      );
    });

    testWidgets('each tile is a Semantics button labelled with the tool name', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<UtilityDescriptor> opened = <UtilityDescriptor>[];
      await _pumpGrid(tester, opened);

      // Each launcher tile merges to one node: a button, labelled with the tool
      // name, carrying the tap action Enter/Space activate. (Tiles scrolled
      // below the right-edge fold are hidden, which is orthogonal to this.)
      for (final UtilityDescriptor d in UtilityCatalog.all) {
        final SemanticsData data = tester
            .getSemantics(find.bySemanticsLabel(d.name))
            .getSemanticsData();
        expect(data.label, d.name, reason: 'label for "${d.name}"');
        expect(
          data.flagsCollection.isButton,
          isTrue,
          reason: 'button flag for "${d.name}"',
        );
        expect(
          data.hasAction(SemanticsAction.tap),
          isTrue,
          reason: 'tap action for "${d.name}"',
        );
      }
      handle.dispose();
    });

    testWidgets('Tab + Enter focuses then launches the first tile', (
      WidgetTester tester,
    ) async {
      final List<UtilityDescriptor> opened = <UtilityDescriptor>[];
      await _pumpGrid(tester, opened);

      // Tab moves focus onto the first launcher tile (visual order), Enter
      // activates it through the same onOpen path as a click.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(opened, <UtilityDescriptor>[UtilityCatalog.all.first]);
    });

    testWidgets('Space activates the focused tile', (
      WidgetTester tester,
    ) async {
      final List<UtilityDescriptor> opened = <UtilityDescriptor>[];
      await _pumpGrid(tester, opened);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(opened, <UtilityDescriptor>[UtilityCatalog.all.first]);
    });

    testWidgets(
      'Arrow Down/Up move focus between spatially-adjacent tiles; Enter '
      'launches the focused tool',
      (WidgetTester tester) async {
        final List<UtilityDescriptor> opened = <UtilityDescriptor>[];
        await _pumpGrid(tester, opened);

        // Tab onto the first tile (visual order).
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(_focusedTileLabel(), UtilityCatalog.all[0].name);

        // ArrowDown steps to the tile directly below (the next column entry).
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(_focusedTileLabel(), UtilityCatalog.all[1].name);

        // A second ArrowDown continues spatially down the grid.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(_focusedTileLabel(), UtilityCatalog.all[2].name);

        // ArrowUp reverses, returning focus to the tile above.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(_focusedTileLabel(), UtilityCatalog.all[1].name);

        // Enter still activates the now-focused tile through the onOpen path.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(opened, <UtilityDescriptor>[UtilityCatalog.all[1]]);
      },
    );
  });
}
