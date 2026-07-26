import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/models/work_session.dart';
import 'package:masquerade/screens/detail/tool_detail_route.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/state/work_session_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _phone = Size(393, 852);

Future<HistoryController> _pumpActivity(
  WidgetTester tester, {
  double textScale = 1,
  WorkSessionController? workSessions,
}) async {
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final HistoryController history = HistoryController(
    prefs: prefs,
    retention: Duration.zero,
  );
  await history.add(
    HistoryEntry(
      utilityId: 'json',
      input: '{"hello":"world"}',
      output: 'pretty result',
      timestamp: DateTime(2026, 7, 18, 10, 30),
    ),
  );
  await history.add(
    HistoryEntry(
      utilityId: 'base64',
      input: 'ordinary',
      output: 'b3JkaW5hcnk=',
      timestamp: DateTime(2026, 7, 18, 11),
    ),
  );
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MyApp(
        isWebOverride: false,
        skipSplash: true,
        historyController: history,
        workSessionController: workSessions,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Activity').last);
  await tester.pumpAndSettle();
  return history;
}

WorkSession _recentSession() => WorkSession(
  id: 'recent-session',
  name: 'Rates session',
  createdAt: DateTime.fromMillisecondsSinceEpoch(1),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
  steps: <WorkflowStep>[
    WorkflowStep(
      toolId: 'bps',
      input: Artifact<Object?>(
        kind: ArtifactKind.bps,
        rawValue: '25 bps',
        provenance: ArtifactProvenance.typed,
      ),
      settings: const <String, Object?>{},
      status: WorkflowStepStatus.running,
    ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('search filters by value, tool, and date', (
    WidgetTester tester,
  ) async {
    await _pumpActivity(tester);
    final Finder search = find.byType(CupertinoSearchTextField);

    await tester.enterText(search, 'pretty result');
    await tester.pump();
    expect(find.text('JSON / YAML / TOML'), findsOneWidget);
    expect(find.text('Base64'), findsNothing);

    await tester.enterText(search, 'base64');
    await tester.pump();
    expect(find.text('Base64'), findsOneWidget);
    expect(find.text('JSON / YAML / TOML'), findsNothing);

    await tester.enterText(search, '2026-07-18');
    await tester.pump();
    expect(find.text('JSON / YAML / TOML'), findsOneWidget);
    expect(find.text('Base64'), findsOneWidget);
  });

  testWidgets('reopen restores exact input and copy writes exact output', (
    WidgetTester tester,
  ) async {
    String? clipboard;
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map<dynamic, dynamic>)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await _pumpActivity(tester);

    await tester.tap(
      find.bySemanticsLabel('Reopen JSON / YAML / TOML with saved input'),
    );
    await tester.pumpAndSettle();
    final ToolDetailRoute route = tester.widget(find.byType(ToolDetailRoute));
    expect(route.seed, '{"hello":"world"}');
    Navigator.of(tester.element(find.byType(ToolDetailRoute))).pop();
    await tester.pumpAndSettle();

    await tester.tap(
      find.bySemanticsLabel('Copy JSON / YAML / TOML output').last,
    );
    await tester.pump();
    expect(clipboard, 'pretty result');
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('pin and delete persist', (WidgetTester tester) async {
    final HistoryController history = await _pumpActivity(tester);

    await tester.tap(find.bySemanticsLabel('Pin Base64 entry'));
    await tester.pumpAndSettle();
    expect(find.text('PINNED'), findsOneWidget);
    expect(history.entries.first.pinned, isTrue);
    Map<String, dynamic> persisted =
        (jsonDecode(
                      (await SharedPreferences.getInstance()).getString(
                        'mb.history.entries',
                      )!,
                    )
                    as List<dynamic>)
                .first
            as Map<String, dynamic>;
    expect(persisted['pinned'], isTrue);

    await tester.tap(find.bySemanticsLabel('Delete Base64 entry'));
    await tester.pumpAndSettle();
    expect(history.entries, hasLength(1));
    persisted =
        (jsonDecode(
                      (await SharedPreferences.getInstance()).getString(
                        'mb.history.entries',
                      )!,
                    )
                    as List<dynamic>)
                .single
            as Map<String, dynamic>;
    expect(persisted['utilityId'], 'json');
  });

  testWidgets('recent session resumes on Workbench at large text scale', (
    WidgetTester tester,
  ) async {
    final WorkSession recent = _recentSession();
    final WorkSessionController sessions = WorkSessionController(
      recentSessions: <WorkSession>[recent],
    );
    await _pumpActivity(tester, textScale: 2, workSessions: sessions);

    expect(find.text('RESUMABLE SESSIONS'), findsOneWidget);
    expect(find.bySemanticsLabel('Resume Rates session'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Resume Rates session'));
    await tester.pumpAndSettle();

    expect(sessions.session, same(recent));
    expect(find.text('CURRENT SESSION'), findsOneWidget);
    expect(find.text('1. bps · % · decimal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Activity Clear removes history and recents but keeps live work',
    (WidgetTester tester) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final WorkSessionController sessions = WorkSessionController(
        prefs: prefs,
      );
      sessions.start(
        UtilityCatalog.byId('bps'),
        Artifact<Object?>(
          kind: ArtifactKind.bps,
          rawValue: '25 bps',
          provenance: ArtifactProvenance.typed,
        ),
      );
      sessions.addNext(0, UtilityCatalog.byId('timestamp'), '1700000000');
      await sessions.saveCurrent('Rates');
      expect(sessions.branchFrom(0), isTrue);
      final WorkSession live = sessions.session!;
      final WorkSession original = sessions.branchOrigin!;
      final HistoryController history = await _pumpActivity(
        tester,
        workSessions: sessions,
      );

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear').last);
      await tester.pumpAndSettle();

      expect(history.entries, isEmpty);
      expect(sessions.recentSessions, isEmpty);
      expect(sessions.session, same(live));
      expect(sessions.branchOrigin, same(original));
      expect(sessions.savedWorkflows.single.name, 'Rates');
    },
  );

  testWidgets('actions keep 44-point targets at large Dynamic Type', (
    WidgetTester tester,
  ) async {
    await _pumpActivity(tester, textScale: 2);

    for (final String label in <String>[
      'Reopen Base64 with saved input',
      'Copy Base64 output',
      'Pin Base64 entry',
      'Delete Base64 entry',
    ]) {
      final Finder control = find.bySemanticsLabel(label);
      expect(control, findsOneWidget);
      expect(tester.getSize(control).height, greaterThanOrEqualTo(44));
    }
    expect(tester.takeException(), isNull);
  });
}
