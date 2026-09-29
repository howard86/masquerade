import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/link_group.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/desktop_menubar.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';
import 'package:masquerade/widgets/tool_bodies/base64_body.dart';
import 'package:masquerade/widgets/tool_bodies/json_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rebuild counts by widget type name while [body] runs.
Future<Map<String, int>> _countBuilds(Future<void> Function() body) async {
  final Map<String, int> counts = <String, int>{};
  debugOnRebuildDirtyWidget = (Element e, bool _) {
    final String name = e.widget.runtimeType.toString();
    counts[name] = (counts[name] ?? 0) + 1;
  };
  try {
    await body();
  } finally {
    debugOnRebuildDirtyWidget = null;
  }
  return counts;
}

Future<CanvasController> _pumpWithWindows(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MyApp(
      desktopShellOverride: true,
      viewModeController: ViewModeController(initial: MqViewMode.desktop),
      skipSplash: true,
    ),
  );
  await tester.pumpAndSettle();
  final CanvasController c = tester
      .widget<DesktopMenubar>(find.byType(DesktopMenubar))
      .controller;
  c.openTool(UtilityCatalog.byId('json'));
  c.openTool(UtilityCatalog.byId('base64'));
  c.openTool(UtilityCatalog.byId('uuid'));
  await tester.pumpAndSettle(const Duration(milliseconds: 300));
  return c;
}

const Set<String> _chrome = <String>{
  'JSONBody',
  'Base64Body',
  'UuidBody',
  'ToolCardFrame',
  'DesktopMenubar',
  'DesktopDock',
  'DesktopIconGrid',
  '_LauncherTile',
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('dragging a window rebuilds no bodies, frames or chrome', (
    WidgetTester tester,
  ) async {
    await _pumpWithWindows(tester);
    final Finder top = find.byType(ToolCardFrame).last;
    final Offset before = tester.getTopLeft(top);
    final TestGesture g = await tester.startGesture(
      before + const Offset(180, 18),
    );
    await g.moveBy(const Offset(30, 0));
    await tester.pump();

    final Map<String, int> counts = await _countBuilds(() async {
      for (int i = 0; i < 10; i++) {
        await g.moveBy(const Offset(4, 3));
        await tester.pump();
      }
    });
    await g.up();
    await tester.pumpAndSettle();

    expect(counts.keys.where(_chrome.contains), isEmpty, reason: '$counts');
    expect(tester.getTopLeft(top), before + const Offset(70, 30));
  });

  testWidgets('panning the canvas rebuilds no bodies and moves windows', (
    WidgetTester tester,
  ) async {
    await _pumpWithWindows(tester);
    final Finder first = find.byType(ToolCardFrame).first;
    final Offset before = tester.getTopLeft(first);
    final TestGesture g = await tester.startGesture(const Offset(900, 820));
    await g.moveBy(const Offset(30, 0));
    await tester.pump();

    final Map<String, int> counts = await _countBuilds(() async {
      for (int i = 0; i < 10; i++) {
        await g.moveBy(const Offset(-2, -1));
        await tester.pump();
      }
    });
    await g.up();
    await tester.pumpAndSettle();

    expect(counts.keys.where(_chrome.contains), isEmpty, reason: '$counts');
    expect(tester.getTopLeft(first), before + const Offset(10, -10));
  });

  testWidgets('a cached body is rebuilt when its card joins a link group', (
    WidgetTester tester,
  ) async {
    final CanvasController c = await _pumpWithWindows(tester);
    expect(tester.widget<JSONBody>(find.byType(JSONBody)).link, isNull);

    c.linkCards(1, 2, type: ContentType.text);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(tester.widget<JSONBody>(find.byType(JSONBody)).link, isNotNull);
    expect(tester.widget<Base64Body>(find.byType(Base64Body)).link, isNotNull);

    c.unlinkCard(1);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(tester.widget<JSONBody>(find.byType(JSONBody)).link, isNull);
  });

  testWidgets('focus changes still restyle the cached frames', (
    WidgetTester tester,
  ) async {
    final CanvasController c = await _pumpWithWindows(tester);
    bool focusedOf(int index) => tester
        .widget<ToolCardFrame>(find.byType(ToolCardFrame).at(index))
        .focused;
    // Paint order = z order; the last-opened (uuid) card is on top + focused.
    expect(focusedOf(2), isTrue);

    c.focus(1);
    await tester.pump();

    // JSON (id 1) is raised to the top and is the only focused frame.
    expect(focusedOf(2), isTrue);
    expect(focusedOf(0), isFalse);
    expect(focusedOf(1), isFalse);
    expect(
      tester.widget<ToolCardFrame>(find.byType(ToolCardFrame).at(2)).title,
      UtilityCatalog.byId('json').name,
    );
  });
}
