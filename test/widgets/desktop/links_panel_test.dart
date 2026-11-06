import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/link_group.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/desktop/links_panel.dart';

Future<void> _pump(WidgetTester tester, CanvasController c) async {
  await tester.pumpWidget(
    CupertinoApp(
      home: MqTheme(
        tokens: MqTokens(
          colors: MqColors.light(),
          brightness: Brightness.light,
        ),
        child: SizedBox(
          width: 380,
          height: 700,
          child: LinksPanel(controller: c),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final UtilityDescriptor base64 = UtilityCatalog.byId('base64');
  final UtilityDescriptor json = UtilityCatalog.byId('json');
  final UtilityDescriptor list = UtilityCatalog.byId('list');
  final UtilityDescriptor diff = UtilityCatalog.byId('diff');

  testWidgets('shows empty state without groups', (tester) async {
    await _pump(tester, CanvasController());
    expect(find.text('No live links yet'), findsOneWidget);
    expect(find.textContaining('title bar'), findsOneWidget);
  });

  testWidgets('renders a star per group with letters and members', (
    tester,
  ) async {
    final CanvasController c = CanvasController();
    final int a = c.openTool(base64);
    final int b = c.openTool(json);
    final int x = c.openTool(list);
    final int y = c.openTool(diff);
    c.linkCards(a, b, type: ContentType.text, seedCanonical: 'one');
    c.linkCards(x, y, type: ContentType.text, seedCanonical: 'two');
    await _pump(tester, c);

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text(base64.name), findsOneWidget);
    expect(find.text(json.name), findsOneWidget);
    expect(find.text(list.name), findsOneWidget);
    expect(find.text(diff.name), findsOneWidget);
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
  });

  testWidgets('canonical value updates live', (tester) async {
    final CanvasController c = CanvasController();
    final int a = c.openTool(base64);
    final int b = c.openTool(json);
    c.linkCards(a, b, type: ContentType.text, seedCanonical: 'before');
    await _pump(tester, c);
    expect(find.text('before'), findsOneWidget);

    c.groupForCard(a)!.canonical.value = 'after';
    await tester.pump();
    expect(find.text('before'), findsNothing);
    expect(find.text('after'), findsOneWidget);
  });

  testWidgets('secret-looking canonical value is masked', (tester) async {
    final CanvasController c = CanvasController();
    final int a = c.openTool(base64);
    final int b = c.openTool(json);
    const String secret =
        '-----BEGIN PRIVATE KEY-----abc-----END PRIVATE KEY-----';
    c.linkCards(a, b, type: ContentType.text, seedCanonical: 'plain');
    await _pump(tester, c);
    expect(find.text('plain'), findsOneWidget);

    c.groupForCard(a)!.canonical.value = secret;
    await tester.pump();
    expect(find.text('••••'), findsOneWidget);
    expect(find.textContaining('PRIVATE KEY'), findsNothing);
  });

  testWidgets('tapping a member focuses it, restoring if minimized', (
    tester,
  ) async {
    final CanvasController c = CanvasController();
    final int a = c.openTool(base64);
    final int b = c.openTool(json);
    c.linkCards(a, b, type: ContentType.text, seedCanonical: 'x');
    c.minimize(a);
    await _pump(tester, c);
    expect(find.text('minimized'), findsOneWidget);

    await tester.tap(find.text(base64.name));
    await tester.pump();
    expect(c.cards.firstWhere((CanvasCard k) => k.id == a).minimized, isFalse);
    expect(c.focusedId, a);
    expect(find.text('minimized'), findsNothing);
  });

  testWidgets('unlink removes the member and dissolves a pair', (tester) async {
    final CanvasController c = CanvasController();
    final int a = c.openTool(base64);
    final int b = c.openTool(json);
    final int d = c.openTool(list);
    c.linkCards(a, b, type: ContentType.text, seedCanonical: 'x');
    c.linkCards(a, d, type: ContentType.text);
    await _pump(tester, c);

    await tester.tap(find.bySemanticsLabel('Unlink ${list.name} from group A'));
    await tester.pump();
    expect(c.groupForCard(d), isNull);
    expect(find.text(list.name), findsNothing);

    await tester.tap(find.bySemanticsLabel('Unlink ${json.name} from group A'));
    await tester.pump();
    expect(c.groups, isEmpty);
    expect(find.text('No live links yet'), findsOneWidget);
  });

  testWidgets('follow toggle sets follower via the controller', (tester) async {
    final CanvasController c = CanvasController();
    final int a = c.openTool(base64);
    final int b = c.openTool(json);
    c.linkCards(a, b, type: ContentType.text, seedCanonical: 'x');
    await _pump(tester, c);

    await tester.tap(find.bySemanticsLabel('${base64.name} follow only'));
    await tester.pump();
    expect(c.isFollower(a), isTrue);
    await tester.tap(find.bySemanticsLabel('${base64.name} follow only'));
    await tester.pump();
    expect(c.isFollower(a), isFalse);
  });

  testWidgets('toggle is disabled for the last non-follower', (tester) async {
    final CanvasController c = CanvasController();
    final int a = c.openTool(base64);
    final int b = c.openTool(json);
    c.linkCards(a, b, type: ContentType.text, seedCanonical: 'x');
    c.setFollower(a, true);
    await _pump(tester, c);

    await tester.tap(find.bySemanticsLabel('${json.name} follow only'));
    await tester.pump();
    expect(c.isFollower(b), isFalse);
    expect(
      tester.getSemantics(find.bySemanticsLabel('${json.name} follow only')),
      matchesSemantics(
        label: '${json.name} follow only',
        hint: 'At least one window must send',
        isButton: true,
        hasToggledState: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    // The existing follower can still be switched off.
    await tester.tap(find.bySemanticsLabel('${base64.name} follow only'));
    await tester.pump();
    expect(c.isFollower(a), isFalse);
  });

  testWidgets('spokes reflect followers and hub summary counts them', (
    tester,
  ) async {
    final CanvasController c = CanvasController();
    final int a = c.openTool(base64);
    final int b = c.openTool(json);
    c.linkCards(a, b, type: ContentType.text, seedCanonical: 'x');
    await _pump(tester, c);
    expect(find.bySemanticsLabel(RegExp(r'2 windows')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'following')), findsNothing);

    c.setFollower(b, true);
    await tester.pump();
    final CustomPaint paint = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .firstWhere((CustomPaint p) => p.painter.toString().contains('Spoke'));
    expect((paint.painter! as dynamic).followers, <bool>[false, true]);
    expect(
      find.bySemanticsLabel(RegExp(r'2 windows, 1 following')),
      findsOneWidget,
    );
  });

  testWidgets('shows no sender warning', (tester) async {
    final CanvasController c = CanvasController();
    final int a = c.openTool(base64);
    final int b = c.openTool(json);
    c.linkCards(a, b, type: ContentType.text, seedCanonical: 'x');
    c.setFollower(a, true);
    await _pump(tester, c);
    expect(find.textContaining('No window sends'), findsNothing);
  });

  testWidgets('follow toggle is disabled with a hint for fixed roles', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final CanvasController c = CanvasController();
    final int a = c.openTool(base64);
    final int h = c.openTool(UtilityCatalog.byId('hash'));
    final int g = c.openTool(UtilityCatalog.byId('generator'));
    c.linkCards(a, h, type: ContentType.text);
    c.linkCards(g, a, type: ContentType.text);
    await _pump(tester, c);

    SemanticsData data(String label) =>
        tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData();
    expect(
      data('${UtilityCatalog.byId('hash').name} follow only').hint,
      'Always follows',
    );
    expect(
      data('${UtilityCatalog.byId('generator').name} follow only').hint,
      'Only sends',
    );
    handle.dispose();
  });
}
