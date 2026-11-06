import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/link_group.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/desktop_menubar.dart';
import 'package:masquerade/widgets/desktop/pipe.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Duration _settle = Duration(milliseconds: 300);

Future<void> _pumpDesktop(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.binding.setSurfaceSize(const Size(1200, 900));
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

Future<void> _open(WidgetTester tester, String name) async {
  final Finder tile = find.text(name);
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

CanvasController _canvas(WidgetTester tester) =>
    tester.widget<DesktopMenubar>(find.byType(DesktopMenubar)).controller;

Future<void> _openPicker(WidgetTester tester, {String? hint}) async {
  final Finder button = find.byWidgetPredicate(
    (Widget w) =>
        w is Semantics &&
        w.properties.label == 'Choose live link target' &&
        (hint == null
            ? !(w.properties.hint ?? '').contains('suggested')
            : (w.properties.hint ?? '').contains(hint)),
  );
  await tester.tap(button.first);
  await tester.pumpAndSettle();
}

/// Right-clicks the title of the first card frame titled [title].
Future<void> _rightClickTitle(WidgetTester tester, String title) async {
  final Finder t = find.descendant(
    of: find.byType(ToolCardFrame),
    matching: find.text(title),
  );
  final TestGesture g = await tester.startGesture(
    tester.getCenter(t.first),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await g.up();
  await tester.pumpAndSettle();
}

dynamic _hub(WidgetTester tester) {
  final CustomPaint paint = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .firstWhere(
        (CustomPaint p) =>
            p.painter.runtimeType.toString() == '_LinkLinePainter',
      );
  return (paint.painter as dynamic).hubs.single;
}

void main() {
  testWidgets('picker has sections, one row per target and no type tags', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    await _open(tester, 'Timestamp');
    final CanvasController c = _canvas(tester);
    c.openTool(UtilityCatalog.byId('math'));
    await tester.pumpAndSettle();
    await _openPicker(tester);

    expect(find.text('Open windows'), findsOneWidget);
    expect(find.text('New window'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Link to Math')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Open Math')), findsOneWidget);
    expect(find.text('EPOCH'), findsNothing);
    expect(find.text('NUMBER'), findsNothing);
    expect(find.text('Target follows Timestamp'), findsOneWidget);
    expect(find.textContaining('Two-way'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(r'^Link to Math, Open · ⌥2')),
      findsOneWidget,
    );
  });

  testWidgets('picker shows the target group letter once linked', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    final CanvasController c = _canvas(tester);
    final int ts = c.openTool(UtilityCatalog.byId('timestamp'));
    final int math = c.openTool(UtilityCatalog.byId('math'));
    expect(c.linkCards(ts, math, type: ContentType.epoch), isNotNull);
    c.openTool(UtilityCatalog.byId('timestamp'));
    await tester.pumpAndSettle();
    await _openPicker(tester);
    expect(find.text('A'), findsWidgets);
    expect(find.bySemanticsLabel(RegExp(r'in link group A')), findsWidgets);
  });

  testWidgets('paired tool opens the picker with its partner suggested first', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    await _open(tester, 'JSON / YAML / TOML');
    await _openPicker(tester, hint: 'suggested');

    expect(find.text('Suggested'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Open Base64, Suggested')),
      findsOneWidget,
    );
    final Finder rows = find.bySemanticsLabel(RegExp(r'^Open '));
    expect(
      tester.getTopLeft(find.text('Open Base64')).dy,
      lessThanOrEqualTo(tester.getTopLeft(rows.at(1)).dy),
    );
    expect(_canvas(tester).cards, hasLength(1));
  });

  testWidgets('follow toggle makes the target a follower', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    await _open(tester, 'Timestamp');
    await _openPicker(tester);
    await tester.tap(find.text('Target follows Timestamp'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Open Math')));
    await tester.pumpAndSettle(_settle);

    final CanvasController c = _canvas(tester);
    expect(c.isFollower(c.cards.first.id), isFalse);
    expect(c.isFollower(c.cards.last.id), isTrue);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('A · follows'), findsOneWidget);
    final dynamic hub = _hub(tester);
    expect((hub.followers as List).cast<bool>(), <bool>[false, true]);
  });

  testWidgets('default is two-way', (WidgetTester tester) async {
    await _pumpDesktop(tester);
    await _open(tester, 'Timestamp');
    await _openPicker(tester);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Open Math')));
    await tester.pumpAndSettle(_settle);

    expect(find.text('A'), findsNWidgets(2));
    expect(find.textContaining('follows'), findsNothing);
    final dynamic hub = _hub(tester);
    expect((hub.followers as List).cast<bool>(), <bool>[false, false]);
  });

  testWidgets('dropping an output makes the target a follower', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    await _open(tester, 'Timestamp');
    await tester.enterText(find.byType(EditableText).first, '1700000000');
    await tester.pumpAndSettle(_settle);
    final CanvasController c = _canvas(tester);
    final int math = c.openTool(UtilityCatalog.byId('math'));
    c.moveTo(math, 600, 40);
    await tester.pumpAndSettle();

    final Rect pipe = tester.getRect(
      find.byType(LongPressDraggable<PipePayload>).first,
    );
    final Offset from = Offset(pipe.right - 30, pipe.center.dy);
    final Offset to = tester.getCenter(find.byType(ToolCardFrame).last);
    final TestGesture g = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    for (int i = 1; i <= 12; i++) {
      await g.moveTo(Offset.lerp(from, to, i / 12)!);
      await tester.pump();
    }
    expect(find.textContaining('Release to follow'), findsOneWidget);
    await g.up();
    await tester.pumpAndSettle(_settle);

    expect(c.isFollower(math), isTrue);
    expect(find.text('A · follows'), findsOneWidget);
    expect((_hub(tester).followers as List).cast<bool>(), <bool>[false, true]);
  });

  testWidgets('context menu toggles Follow Only and refuses the last sender', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    final CanvasController c = _canvas(tester);
    final int ts = c.openTool(UtilityCatalog.byId('timestamp'));
    final int math = c.openTool(UtilityCatalog.byId('math'));
    expect(c.linkCards(ts, math, type: ContentType.epoch), isNotNull);
    await tester.pumpAndSettle(_settle);

    await _rightClickTitle(tester, 'Timestamp');
    expect(find.text('Follow Only'), findsOneWidget);
    await tester.tap(find.text('Follow Only'));
    await tester.pumpAndSettle(_settle);
    expect(c.isFollower(ts), isTrue);
    expect(find.text('A · follows'), findsOneWidget);

    // Math is now the only sender and cannot follow.
    await _rightClickTitle(tester, 'Math');
    expect(find.text('Follow Only'), findsNothing);
    expect(find.text('✓ Follow Only'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await _rightClickTitle(tester, 'Timestamp');
    expect(find.text('✓ Follow Only'), findsOneWidget);
    await tester.tap(find.text('✓ Follow Only'));
    await tester.pumpAndSettle(_settle);
    expect(c.isFollower(ts), isFalse);
  });

  testWidgets('a new link target opens beside its source', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(tester);
    await _open(tester, 'Timestamp');
    final CanvasController c = _canvas(tester);
    final CanvasCard source = c.cards.first;
    await _openPicker(tester);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Open Math')));
    await tester.pumpAndSettle(_settle);

    final CanvasCard fresh = c.cards.last;
    expect(fresh.id, isNot(source.id));
    expect(fresh.x, source.x + source.width + 24);
    expect(fresh.y, source.y);
  });
}
