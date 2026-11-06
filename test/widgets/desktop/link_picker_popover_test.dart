import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/models/content_type.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/desktop_menubar.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';
import 'package:masquerade/widgets/mq/mq_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<CanvasController> _pumpWithTimestampAndMath(WidgetTester tester) async {
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
  final CanvasController c = tester
      .widget<DesktopMenubar>(find.byType(DesktopMenubar))
      .controller;
  c.openTool(UtilityCatalog.byId('timestamp'));
  c.openTool(UtilityCatalog.byId('math'));
  await tester.pumpAndSettle();
  return c;
}

Finder get _popover => find.byWidgetPredicate(
  (Widget w) => w.runtimeType.toString().startsWith('LinkPickerPopover'),
);

/// The visible panel (the popover widget itself spans the whole screen).
Finder get _panel =>
    find.descendant(of: _popover, matching: find.byType(Container)).first;

Finder get _firstLinkButton => find
    .descendant(
      of: find.byType(ToolCardFrame).first,
      matching: find.byIcon(MqIcons.link),
    )
    .first;

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(_firstLinkButton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens just below the link button within the window span', (
    WidgetTester tester,
  ) async {
    await _pumpWithTimestampAndMath(tester);
    final Rect button = tester.getRect(_firstLinkButton);
    final Rect window = tester.getRect(find.byType(ToolCardFrame).first);
    await _openPicker(tester);

    final Rect pop = tester.getRect(_panel);
    expect(pop.top, greaterThanOrEqualTo(button.bottom));
    expect(pop.top, lessThan(button.bottom + 24));
    expect(pop.width, lessThanOrEqualTo(340));
    expect(pop.right, lessThanOrEqualTo(1200));
    expect(pop.left, greaterThanOrEqualTo(0));
    // Right-aligned under the link button so it opens over its own window.
    expect(pop.right, inInclusiveRange(button.right, button.right + 12));
    expect(pop.left, lessThanOrEqualTo(button.left));
    expect(pop.right, inInclusiveRange(window.left, window.right));
  });

  testWidgets('title, headers and rows are left-aligned', (
    WidgetTester tester,
  ) async {
    await _pumpWithTimestampAndMath(tester);
    await _openPicker(tester);
    final Rect pop = tester.getRect(_panel);

    for (final String label in <String>[
      'Link Timestamp',
      'Open windows',
      'New window',
    ]) {
      final Rect r = tester.getRect(find.text(label));
      expect(r.left - pop.left, lessThan(24), reason: label);
    }
    final Rect row = tester.getRect(
      find.descendant(of: _popover, matching: find.text('Math')).first,
    );
    // Icon + padding only; a centered label would sit far from the edge.
    expect(row.left - pop.left, lessThan(48));
    final Text title = tester.widget<Text>(find.text('Link Timestamp'));
    expect(title.textAlign, TextAlign.left);
  });

  testWidgets('filter narrows the rows by tool name', (
    WidgetTester tester,
  ) async {
    await _pumpWithTimestampAndMath(tester);
    await _openPicker(tester);
    final Finder rows = find.bySemanticsLabel(RegExp(r'^(Open|Link to) '));
    final int before = rows.evaluate().length;
    expect(before, greaterThan(2));

    await tester.enterText(
      find.descendant(of: _popover, matching: find.byType(EditableText)),
      'math',
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'^Link to Math')), findsOneWidget);
    expect(rows.evaluate().length, lessThan(before));

    await tester.enterText(
      find.descendant(of: _popover, matching: find.byType(EditableText)),
      'zzzz',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No tools match'), findsOneWidget);
  });

  testWidgets('Down then Enter chooses the next row', (
    WidgetTester tester,
  ) async {
    final CanvasController c = await _pumpWithTimestampAndMath(tester);
    await _openPicker(tester);

    // First row is highlighted; Down moves to the second.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(_popover, findsNothing);
    expect(c.groups, hasLength(1));
  });

  testWidgets('Down moves past the first row', (WidgetTester tester) async {
    final CanvasController c = await _pumpWithTimestampAndMath(tester);
    await _openPicker(tester);
    final int cardsBefore = c.cards.length;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Row 0 is the open Math window; row 1 is a new window, so a card opens.
    expect(c.cards.length, cardsBefore + 1);
    expect(c.groups, hasLength(1));
  });

  testWidgets('Escape dismisses without linking', (WidgetTester tester) async {
    final CanvasController c = await _pumpWithTimestampAndMath(tester);
    await _openPicker(tester);
    expect(_popover, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(_popover, findsNothing);
    expect(c.groups, isEmpty);
    expect(c.cards, hasLength(2));
  });

  testWidgets('tapping outside dismisses without linking', (
    WidgetTester tester,
  ) async {
    final CanvasController c = await _pumpWithTimestampAndMath(tester);
    await _openPicker(tester);
    expect(_popover, findsOneWidget);

    await tester.tapAt(const Offset(4, 880));
    await tester.pumpAndSettle();

    expect(_popover, findsNothing);
    expect(c.groups, isEmpty);
    expect(c.cards, hasLength(2));
  });

  testWidgets('a linked window still opens the picker to add downstreams', (
    WidgetTester tester,
  ) async {
    final CanvasController c = await _pumpWithTimestampAndMath(tester);
    c.linkCards(c.cards.first.id, c.cards.last.id, type: ContentType.epoch);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Link more windows').first);
    await tester.pumpAndSettle();
    expect(_popover, findsOneWidget);
    // Unlink lives on its own header button, not in the picker.
    expect(
      find.descendant(of: _popover, matching: find.bySemanticsLabel('Unlink')),
      findsNothing,
    );
    // New picks default to following the group.
    expect(
      tester.getSemantics(find.bySemanticsLabel('Target follows Timestamp')),
      isSemantics(isChecked: true),
    );

    final int cardsBefore = c.cards.length;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(c.cards.length, cardsBefore + 1);
    expect(c.groups.single.members, hasLength(3));
    expect(c.isFollower(c.cards.last.id), isTrue);
  });

  testWidgets('Unlink is a separate header button on linked windows', (
    WidgetTester tester,
  ) async {
    final CanvasController c = await _pumpWithTimestampAndMath(tester);
    expect(find.bySemanticsLabel('Unlink'), findsNothing);
    c.linkCards(c.cards.first.id, c.cards.last.id, type: ContentType.epoch);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Unlink'), findsNWidgets(2));

    await tester.tap(find.bySemanticsLabel('Unlink').first);
    await tester.pumpAndSettle();
    expect(_popover, findsNothing);
    expect(c.groups, isEmpty);
  });

  testWidgets('only lists targets the link can actually reach', (
    WidgetTester tester,
  ) async {
    final CanvasController c = await _pumpWithTimestampAndMath(tester);
    for (final int id in c.cards.map((CanvasCard k) => k.id).toList()) {
      c.close(id);
    }
    final int url = c.openTool(UtilityCatalog.byId('url'));
    final int json = c.openTool(UtilityCatalog.byId('json'));
    c.linkCards(url, json, type: ContentType.text);
    c.focus(url);
    await tester.pumpAndSettle();

    await tester.tap(
      find
          .descendant(
            of: find.widgetWithText(ToolCardFrame, 'URL'),
            matching: find.bySemanticsLabel('Link more windows'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(_popover, findsOneWidget);
    // The group carries JSON text, which Color can't read in either role.
    expect(find.bySemanticsLabel(RegExp(r'^Open Color')), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^Open List')), findsOneWidget);
  });

  testWidgets('rows keep their identity when the highlight moves', (
    WidgetTester tester,
  ) async {
    await _pumpWithTimestampAndMath(tester);
    await _openPicker(tester);
    Element rowElement() =>
        tester.element(find.bySemanticsLabel(RegExp(r'^Link to Math')));
    final Element before = rowElement();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    // A remounted row would drop a tap that is mid-gesture.
    expect(identical(rowElement(), before), isTrue);
  });

  testWidgets('a mouse click after resting on a new-window row links it', (
    WidgetTester tester,
  ) async {
    final CanvasController c = await _pumpWithTimestampAndMath(tester);
    await _openPicker(tester);
    final int cardsBefore = c.cards.length;
    final Finder row = find
        .bySemanticsLabel(RegExp(r'^Open (?!windows)'))
        .first;
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: tester.getCenter(row));
    addTearDown(mouse.removePointer);
    await tester.pump();
    await mouse.moveTo(tester.getCenter(row));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await mouse.down(tester.getCenter(row));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await mouse.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(_popover, findsNothing);
    expect(c.cards.length, cardsBefore + 1);
    expect(c.groups, hasLength(1));
  });
}
