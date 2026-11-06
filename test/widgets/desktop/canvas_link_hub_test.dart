import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/link_group.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/desktop_menubar.dart';
import 'package:masquerade/widgets/desktop/link_identity.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';
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

int _open(CanvasController c, String id, double x, double y) {
  final int card = c.openTool(UtilityCatalog.byId(id));
  c.moveTo(card, x, y);
  return card;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('two same-type groups get distinct letters and colors', (
    WidgetTester tester,
  ) async {
    final CanvasController c = await _pump(tester);
    final int a1 = _open(c, 'json', 20, 40);
    final int a2 = _open(c, 'base64', 520, 40);
    final int b1 = _open(c, 'json', 20, 460);
    final int b2 = _open(c, 'base64', 520, 460);
    expect(c.linkCards(a1, a2, type: ContentType.text), isNotNull);
    expect(c.linkCards(b1, b2, type: ContentType.text), isNotNull);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('A · TEXT'), findsNWidgets(2));
    expect(find.text('B · TEXT'), findsNWidgets(2));
    final Map<int, LinkIdentity> ids = linkIdentities(
      c.groups,
      MqTheme.of(tester.element(find.byType(DesktopMenubar))).colors,
    );
    expect(ids.values.map((LinkIdentity i) => i.letter).toSet().length, 2);
    expect(ids.values.map((LinkIdentity i) => i.color).toSet().length, 2);
  });

  testWidgets('tether layer paints above the windows and ignores hits', (
    WidgetTester tester,
  ) async {
    final CanvasController c = await _pump(tester);
    c.linkCards(
      _open(c, 'json', 20, 40),
      _open(c, 'base64', 520, 40),
      type: ContentType.text,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    final Finder stack = find.ancestor(
      of: find.byType(ToolCardFrame).first,
      matching: find.byType(Stack),
    );
    final Stack surface = tester
        .widgetList<Stack>(stack)
        .firstWhere(
          (Stack s) => s.children.any(
            (Widget w) => w is ListenableBuilder && w.key is ValueKey<int>,
          ),
        );
    int lastCard = -1;
    int painter = -1;
    for (int i = 0; i < surface.children.length; i++) {
      final Widget w = surface.children[i];
      if (w is ListenableBuilder && w.key is ValueKey<int>) lastCard = i;
      if (w is Positioned &&
          w.child is IgnorePointer &&
          (w.child as IgnorePointer).child is ListenableBuilder) {
        painter = i;
      }
    }
    expect(painter, greaterThan(lastCard));
  });

  testWidgets('hub chip shows the canonical and updates live', (
    WidgetTester tester,
  ) async {
    final CanvasController c = await _pump(tester);
    c.linkCards(
      _open(c, 'json', 20, 40),
      _open(c, 'base64', 520, 40),
      type: ContentType.text,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    final LinkGroup g = c.groups.single;

    g.canonical.value = 'hello hub';
    await tester.pump();
    expect(find.textContaining('A · Text · hello hub'), findsOneWidget);
    g.canonical.value = 'second';
    await tester.pump();
    expect(find.textContaining('A · Text · second'), findsOneWidget);
  });

  testWidgets('a protected canonical is masked in the hub chip', (
    WidgetTester tester,
  ) async {
    final CanvasController c = await _pump(tester);
    c.linkCards(
      _open(c, 'json', 20, 40),
      _open(c, 'base64', 520, 40),
      type: ContentType.text,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    const String jwt =
        'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.c2lnbmF0dXJlc2lnbg';
    c.groups.single.canonical.value = jwt;
    await tester.pump();
    expect(find.textContaining('••••'), findsOneWidget);
    expect(find.textContaining('eyJhbGci'), findsNothing);
  });
}
