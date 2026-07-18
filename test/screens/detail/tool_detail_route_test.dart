import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/screens/detail/tool_detail_route.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/state/work_session_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _hostHome({
  required Widget Function(BuildContext) onPress,
  WorkSessionController? workSession,
  HistoryController? history,
}) {
  return CupertinoApp(
    key: UniqueKey(),
    builder: (BuildContext context, Widget? child) => MqTheme(
      tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
      child: WorkSessionScope(
        controller: workSession ?? WorkSessionController(),
        child: HistoryScope(
          controller: history ?? HistoryController(),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
    home: Builder(
      builder: (BuildContext context) => CupertinoPageScaffold(
        child: Center(
          child: CupertinoButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push<void>(CupertinoPageRoute<void>(builder: onPress));
            },
            child: const Text('GO'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('renders nav bar middle with descriptor name', (
    WidgetTester tester,
  ) async {
    final UtilityDescriptor d = UtilityCatalog.byId('json');
    await tester.pumpWidget(
      _hostHome(
        onPress: (_) => ToolDetailRoute(descriptor: d, seed: '{"a":1}'),
      ),
    );
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CupertinoNavigationBar),
        matching: find.text('JSON / YAML / TOML'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('seeds the body with the supplied input', (
    WidgetTester tester,
  ) async {
    final UtilityDescriptor d = UtilityCatalog.byId('json');
    await tester.pumpWidget(
      _hostHome(
        onPress: (_) => ToolDetailRoute(descriptor: d, seed: '{"a":1}'),
      ),
    );
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();

    final Iterable<CupertinoTextField> fields = tester
        .widgetList<CupertinoTextField>(find.byType(CupertinoTextField));
    expect(
      fields.any((CupertinoTextField f) => f.controller?.text == '{"a":1}'),
      isTrue,
    );
  });

  testWidgets('back navigation pops the route', (WidgetTester tester) async {
    final UtilityDescriptor d = UtilityCatalog.byId('base64');
    await tester.pumpWidget(
      _hostHome(onPress: (_) => ToolDetailRoute(descriptor: d)),
    );
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();
    expect(find.byType(ToolDetailRoute), findsOneWidget);

    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    nav.pop();
    await tester.pumpAndSettle();
    expect(find.byType(ToolDetailRoute), findsNothing);
  });

  testWidgets('keeps legacy, current, and stale route actions distinct', (
    WidgetTester tester,
  ) async {
    final UtilityDescriptor number = UtilityCatalog.byId('number_base');

    await tester.pumpWidget(
      _hostHome(
        onPress: (_) => ToolDetailRoute(descriptor: number, seed: '1700000000'),
      ),
    );
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();
    expect(find.text('OPEN IN'), findsOneWidget);
    expect(find.text('ADD NEXT STEP'), findsNothing);

    final WorkSessionController current = WorkSessionController();
    current.start(
      number,
      Artifact<Object?>(
        kind: ArtifactKind.number,
        rawValue: '1700000000',
        provenance: ArtifactProvenance.typed,
      ),
    );
    await tester.pumpWidget(
      _hostHome(
        workSession: current,
        onPress: (_) => ToolDetailRoute(
          descriptor: number,
          seed: '1700000000',
          sessionStepIndex: 0,
        ),
      ),
    );
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();
    expect(find.text('ADD NEXT STEP'), findsOneWidget);
    expect(find.text('OPEN IN'), findsNothing);

    current.addNext(0, UtilityCatalog.byId('timestamp'), '1700000000');
    await tester.pump();
    expect(find.text('ADD NEXT STEP'), findsNothing);
    expect(find.text('OPEN IN'), findsNothing);

    Navigator.of(tester.element(find.byType(ToolDetailRoute))).pop();
    await tester.pumpAndSettle();
    expect(current.session!.steps, hasLength(2));
    expect(current.session!.steps.last.input.rawValue, '1700000000');
  });

  testWidgets('clearing a session while its route is open is safe', (
    WidgetTester tester,
  ) async {
    final WorkSessionController sessions = WorkSessionController();
    final UtilityDescriptor bps = UtilityCatalog.byId('bps');
    sessions.start(
      bps,
      Artifact<Object?>(
        kind: ArtifactKind.bps,
        rawValue: '25',
        provenance: ArtifactProvenance.typed,
      ),
    );
    await tester.pumpWidget(
      _hostHome(
        workSession: sessions,
        onPress: (_) =>
            ToolDetailRoute(descriptor: bps, seed: '25', sessionStepIndex: 0),
      ),
    );
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();

    sessions.clear();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ToolDetailRoute), findsOneWidget);
    expect(find.text('ADD NEXT STEP'), findsNothing);
  });

  testWidgets('protected routed edits never enter history or prefs', (
    WidgetTester tester,
  ) async {
    const String derived = '{"at":1700000000}';
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final HistoryController protectedHistory = HistoryController(prefs: prefs);
    final WorkSessionController sessions = WorkSessionController();
    sessions.start(
      UtilityCatalog.byId('jwt'),
      Artifact<Object?>(
        kind: ArtifactKind.jwt,
        rawValue: 'eyJhbGciOiJub25lIn0.eyJhdCI6MTcwMDAwMDAwMH0.',
        provenance: ArtifactProvenance.typed,
      ),
    );
    sessions.addNext(0, UtilityCatalog.byId('json'), derived);

    await tester.pumpWidget(
      _hostHome(
        workSession: sessions,
        history: protectedHistory,
        onPress: (_) => ToolDetailRoute(
          descriptor: UtilityCatalog.byId('json'),
          seed: derived,
          initialArtifact: sessions.session!.steps[1].input,
          sessionStepIndex: 1,
        ),
      ),
    );
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(CupertinoTextField).last,
      '{"at":1800000000}',
    );
    await tester.pump(const Duration(seconds: 6));

    expect(protectedHistory.entries, isEmpty);
    expect(prefs.getKeys().map(prefs.get).join(), isNot(contains(derived)));
    expect(
      prefs.getKeys().map(prefs.get).join(),
      isNot(contains('1800000000')),
    );

    final HistoryController safeHistory = HistoryController(prefs: prefs);
    await tester.pumpWidget(
      _hostHome(
        history: safeHistory,
        onPress: (_) => ToolDetailRoute(
          descriptor: UtilityCatalog.byId('json'),
          seed: '{"safe":true}',
        ),
      ),
    );
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();

    expect(safeHistory.entries.single.input, '{"safe":true}');
  });
}
