import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/state/wallpaper_controller.dart';
import 'package:masquerade/state/window_content.dart';
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
      desktopShellOverride: true,
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
  List<UtilityDescriptor> opened, {
  MqWallpaperType wallpaper = MqWallpaperType.auroraEspresso,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(_desktop);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    CupertinoApp(
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: MqTheme(
            tokens: MqTokens(
              colors: brightness == Brightness.light
                  ? MqColors.light()
                  : MqColors.dark(),
              brightness: brightness,
            ),
            child: WallpaperScope(
              controller: WallpaperController(initial: wallpaper),
              child: DesktopIconGrid(onOpen: opened.add, onOpenSystem: (_) {}),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<UtilityDescriptor> _sortedTools() => UtilityCatalog.all.toList()
  ..sort(
    (UtilityDescriptor a, UtilityDescriptor b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );

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

    testWidgets('flows launchers into visible right-aligned columns', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<UtilityDescriptor> opened = <UtilityDescriptor>[];
      await _pumpGrid(tester, opened);
      await tester.binding.setSurfaceSize(const Size(900, 800));
      await tester.pumpAndSettle();
      final Rect viewport = tester.getRect(find.byType(DesktopIconGrid));
      final Set<double> columns = <double>{};
      final List<String> labels = <String>[
        for (final UtilityDescriptor d in _sortedTools()) d.name,
        for (final SystemApp app in SystemApp.values) SystemWindow(app).title,
      ];

      for (final String label in labels) {
        final Rect tile = tester.getRect(find.bySemanticsLabel(label));
        expect(
          tile.left >= viewport.left &&
              tile.top >= viewport.top &&
              tile.right <= viewport.right &&
              tile.bottom <= viewport.bottom,
          isTrue,
          reason: '$label should be fully visible without scrolling',
        );
        columns.add(tile.center.dx);
      }

      expect(columns.length, greaterThan(1));
      handle.dispose();
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text grows tiles and keeps grid rows separated', (
      WidgetTester tester,
    ) async {
      final List<UtilityDescriptor> opened = <UtilityDescriptor>[];
      await _pumpGrid(tester, opened, textScale: 2);

      final List<Rect> tileRects = <Rect>[];
      for (final UtilityDescriptor descriptor in _sortedTools()) {
        final Finder label = find.text(descriptor.name);
        final Finder tile = find
            .ancestor(of: label, matching: find.byType(AnimatedContainer))
            .first;
        final Rect rect = tester.getRect(tile);
        tileRects.add(rect);
        expect(rect.height, greaterThanOrEqualTo(88));
        expect(tester.getRect(label).bottom, lessThanOrEqualTo(rect.bottom));
      }

      final Map<double, List<Rect>> byColumn = <double, List<Rect>>{};
      for (final Rect rect in tileRects) {
        byColumn.putIfAbsent(rect.center.dx, () => <Rect>[]).add(rect);
      }
      for (final List<Rect> column in byColumn.values) {
        column.sort((Rect a, Rect b) => a.top.compareTo(b.top));
        for (int i = 1; i < column.length; i++) {
          expect(column[i].top - column[i - 1].bottom, greaterThanOrEqualTo(8));
        }
      }

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final String focusedLabel = _focusedTileLabel()!;
      final Finder focusedText = find.text(focusedLabel);
      final Finder focusedTile = find
          .ancestor(of: focusedText, matching: find.byType(AnimatedContainer))
          .first;
      final Rect focusedRect = tester.getRect(focusedTile);
      final Rect labelRect = tester.getRect(focusedText);
      expect(labelRect.height, greaterThan(28));
      expect(labelRect.bottom, lessThanOrEqualTo(focusedRect.bottom - 1.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a tile opens a card with the correct tool', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final UtilityDescriptor first = _sortedTools().first;
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
      // name, carrying the tap action Enter/Space activate.
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

      expect(opened, <UtilityDescriptor>[_sortedTools().first]);
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

      expect(opened, <UtilityDescriptor>[_sortedTools().first]);
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
        final List<UtilityDescriptor> tools = _sortedTools();
        expect(_focusedTileLabel(), tools[0].name);

        // ArrowLeft crosses to the next visual column; ArrowRight reverses.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(_focusedTileLabel(), tools[9].name);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(_focusedTileLabel(), tools[0].name);

        // ArrowDown steps to the tile directly below (the next column entry).
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(_focusedTileLabel(), tools[1].name);

        // A second ArrowDown continues spatially down the grid.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(_focusedTileLabel(), tools[2].name);

        // ArrowUp reverses, returning focus to the tile above.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(_focusedTileLabel(), tools[1].name);

        // Enter still activates the now-focused tile through the onOpen path.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(opened, <UtilityDescriptor>[tools[1]]);
      },
    );
  });

  testWidgets('label color follows wallpaper in either app theme', (
    WidgetTester tester,
  ) async {
    final List<UtilityDescriptor> opened = <UtilityDescriptor>[];
    await _pumpGrid(tester, opened);
    final Text darkWallpaperLabel = tester.widget<Text>(
      find.text(_sortedTools().first.name),
    );
    expect(darkWallpaperLabel.style?.color, const Color(0xFFF5F1ED));

    await _pumpGrid(
      tester,
      opened,
      wallpaper: MqWallpaperType.parchmentMinimalist,
      brightness: Brightness.dark,
    );
    final Text lightWallpaperLabel = tester.widget<Text>(
      find.text(_sortedTools().first.name),
    );
    expect(lightWallpaperLabel.style?.color, const Color(0xFF211D19));
  });

  testWidgets('tools sort alphabetically before system apps', (
    WidgetTester tester,
  ) async {
    final List<UtilityDescriptor> opened = <UtilityDescriptor>[];
    await _pumpGrid(tester, opened);
    final List<String> visibleLabels = <String>[
      for (final Element e in tester.allElements)
        if (e.widget is Semantics &&
            (e.widget as Semantics).properties.label != null)
          (e.widget as Semantics).properties.label!,
    ];
    expect(visibleLabels.take(_sortedTools().length).toList(), <String>[
      for (final UtilityDescriptor d in _sortedTools()) d.name,
    ]);
    expect(visibleLabels.skip(_sortedTools().length), <String>[
      for (final SystemApp app in SystemApp.values) SystemWindow(app).title,
    ]);

    final String longestLabel = _sortedTools()
        .map((UtilityDescriptor d) => d.name)
        .reduce((String a, String b) => a.length >= b.length ? a : b);
    final Text label = tester.widget<Text>(find.text(longestLabel));
    expect(label.maxLines, 2);
    expect(label.textAlign, TextAlign.center);
    expect(label.overflow, TextOverflow.ellipsis);
  });
}
