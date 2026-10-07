import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/models/work_session.dart';
import 'package:masquerade/screens/detail/tool_detail_route.dart';
import 'package:masquerade/screens/history_screen.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/state/work_session_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _phone = Size(393, 852);

Future<HistoryController> _pumpActivity(
  WidgetTester tester, {
  double textScale = 1,
  WorkSessionController? workSessions,
  bool addHistory = true,
  Duration retention = const Duration(days: 365),
}) async {
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final HistoryController history = HistoryController(
    prefs: prefs,
    retention: retention,
  );
  if (addHistory) await _addHistory(history);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MyApp(
        key: UniqueKey(),
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

Future<void> _addHistory(HistoryController history) async {
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
}

Future<WorkSessionController> _sessionsWithRecent(
  SharedPreferences prefs,
) async {
  final WorkSessionController sessions = WorkSessionController(prefs: prefs);
  sessions.start(
    UtilityCatalog.byId('bps'),
    Artifact<Object?>(
      kind: ArtifactKind.bps,
      rawValue: '25 bps',
      provenance: ArtifactProvenance.typed,
    ),
  );
  await sessions.flush();
  return sessions;
}

Future<HistoryController> _pumpHistory(
  WidgetTester tester, {
  required WorkSessionController sessions,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final HistoryController history = HistoryController(
    prefs: prefs,
    retention: const Duration(days: 365),
  );
  await _addHistory(history);
  await tester.pumpWidget(
    CupertinoApp(
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: MqTheme(
          tokens: MqTokens(
            colors: MqColors.light(),
            brightness: Brightness.light,
          ),
          child: WorkSessionScope(
            controller: sessions,
            child: HistoryScope(
              controller: history,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      home: const HistoryScreen(),
    ),
  );
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
      output: Artifact<Object?>(
        kind: ArtifactKind.bps,
        rawValue: '25 bps',
        provenance: ArtifactProvenance.generated,
      ),
      status: WorkflowStepStatus.completed,
    ),
    WorkflowStep(
      toolId: 'timestamp',
      input: Artifact<Object?>(
        kind: ArtifactKind.timestamp,
        rawValue: '1700000000',
        provenance: ArtifactProvenance.generated,
      ),
      settings: const <String, Object?>{},
      status: WorkflowStepStatus.running,
    ),
  ],
);

WorkSession _protectedRecentSession() => WorkSession(
  id: 'protected-session',
  name: 'Protected session',
  createdAt: DateTime.fromMillisecondsSinceEpoch(1),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
  steps: <WorkflowStep>[
    WorkflowStep(
      toolId: 'bps',
      input: Artifact<Object?>(
        kind: ArtifactKind.bps,
        rawValue: '25 bps',
        provenance: ArtifactProvenance.typed,
        sensitivity: ArtifactSensitivity.sensitive,
      ),
      settings: const <String, Object?>{},
      status: WorkflowStepStatus.running,
    ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('empty Activity distinguishes resumable sessions', (
    WidgetTester tester,
  ) async {
    final WorkSessionController sessions = WorkSessionController(
      recentSessions: <WorkSession>[_recentSession()],
    );
    await _pumpActivity(
      tester,
      workSessions: sessions,
      addHistory: false,
      retention: const Duration(days: 7),
    );

    expect(find.text('RESUMABLE SESSIONS'), findsOneWidget);
    expect(find.text('No utility history'), findsOneWidget);
    expect(find.text('Nothing yet'), findsNothing);
    expect(
      find.text(
        'The last 7 days of utility usage will appear here. On-device only.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('recent sessions stay scrollable above compact empty notice', (
    WidgetTester tester,
  ) async {
    final List<WorkSession> recents = <WorkSession>[
      for (int index = 0; index < 6; index++)
        WorkSession(
          id: 'recent-$index',
          name: 'Rates session $index',
          createdAt: DateTime.fromMillisecondsSinceEpoch(index + 1),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(index + 2),
          steps: _recentSession().steps,
        ),
    ];
    await _pumpActivity(
      tester,
      textScale: 2,
      workSessions: WorkSessionController(recentSessions: recents),
      addHistory: false,
      retention: const Duration(days: 7),
    );

    expect(find.text('No utility history'), findsOneWidget);
    expect(find.bySemanticsLabel('Resume Rates session 0'), findsOneWidget);
    expect(find.bySemanticsLabel('Resume Rates session 5'), findsNothing);
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('Resume Rates session 5'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.bySemanticsLabel('Resume Rates session 5'), findsOneWidget);
    expect(find.text('No utility history'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty history uses configured singular and plural windows', (
    WidgetTester tester,
  ) async {
    for (final (int days, String window, double textScale)
        in <(int, String, double)>[(1, 'day', 1), (30, '30 days', 2)]) {
      await _pumpActivity(
        tester,
        textScale: textScale,
        addHistory: false,
        retention: Duration(days: days),
      );

      expect(find.text('Nothing yet'), findsOneWidget);
      expect(
        find.text(
          'The last $window of utility usage will appear here. On-device only.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('zero retention copy describes only the Off setting', (
    WidgetTester tester,
  ) async {
    await _pumpActivity(tester, addHistory: false, retention: Duration.zero);

    expect(find.text('No utility history'), findsOneWidget);
    expect(find.text('Nothing yet'), findsNothing);
    expect(
      find.text(
        'History retention is set to Off. You can change it in Settings.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('last 7 days'), findsNothing);
  });

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
    final SemanticsHandle semantics = tester.ensureSemantics();
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

    const String reopenLabel = 'Reopen JSON / YAML / TOML with saved input';
    final Finder reopen = find.bySemanticsLabel(reopenLabel);
    expect(
      tester
          .getSemantics(reopen)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    tester.semantics.tap(find.semantics.byLabel(reopenLabel));
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
    semantics.dispose();
  });

  testWidgets('pin and delete persist', (WidgetTester tester) async {
    final HistoryController history = await _pumpActivity(tester);

    await tester.tap(find.bySemanticsLabel('Pin Base64 entry'));
    await tester.pumpAndSettle();
    expect(find.text('PINNED'), findsOneWidget);
    expect(history.entries.first.pinned, isTrue);
    Map<String, dynamic> persisted =
        ((jsonDecode(
                          (await SharedPreferences.getInstance()).getString(
                            'mb.history.entries.v2',
                          )!,
                        )
                        as Map<String, dynamic>)['entries']
                    as List<dynamic>)
                .first
            as Map<String, dynamic>;
    expect(persisted['pinned'], isTrue);

    await tester.tap(find.bySemanticsLabel('Delete Base64 entry'));
    await tester.pumpAndSettle();
    expect(history.entries, hasLength(1));
    persisted =
        ((jsonDecode(
                          (await SharedPreferences.getInstance()).getString(
                            'mb.history.entries.v2',
                          )!,
                        )
                        as Map<String, dynamic>)['entries']
                    as List<dynamic>)
                .single
            as Map<String, dynamic>;
    expect(persisted['utilityId'], 'json');
  });

  testWidgets('recent session opens its last tool at large text scale', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final WorkSession recent = _recentSession();
    final WorkSessionController sessions = WorkSessionController(
      recentSessions: <WorkSession>[recent],
    );
    await _pumpActivity(tester, textScale: 2, workSessions: sessions);

    expect(find.text('RESUMABLE SESSIONS'), findsOneWidget);
    final Finder resume = find.bySemanticsLabel('Resume Rates session');
    expect(resume, findsOneWidget);
    expect(
      tester
          .getSemantics(resume)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    tester.semantics.tap(find.semantics.byLabel('Resume Rates session'));
    await tester.pumpAndSettle();

    expect(sessions.session, same(recent));
    final ToolDetailRoute route = tester.widget(find.byType(ToolDetailRoute));
    expect(route.descriptor.id, 'timestamp');
    expect(route.seed, '1700000000');
    expect(route.initialArtifact, same(recent.steps.last.input));
    expect(route.sessionStepIndex, 1);

    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    expect(find.text('CURRENT SESSION'), findsOneWidget);
    expect(find.text('2. Timestamp'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Activity clear removes history-only activity from persistence', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final WorkSessionController sessions = WorkSessionController(prefs: prefs);
    final HistoryController history = await _pumpActivity(
      tester,
      workSessions: sessions,
    );

    await tester.tap(find.bySemanticsLabel('Clear activity'));
    await tester.pumpAndSettle();
    expect(find.text('Clear all activity?'), findsOneWidget);
    expect(
      find.text(
        'Permanently deletes on-device history entries and resumable sessions. Your current session and saved workflows are kept.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Clear activity'));
    await tester.pumpAndSettle();

    expect(history.entries, isEmpty);
    expect((await HistoryController.load()).entries, isEmpty);
    expect((await WorkSessionController.load()).recentSessions, isEmpty);
  });

  testWidgets('Activity clear removes recent-only activity from persistence', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final WorkSessionController sessions = await _sessionsWithRecent(prefs);
    final HistoryController history = await _pumpActivity(
      tester,
      workSessions: sessions,
      addHistory: false,
    );
    expect(history.entries, isEmpty);
    expect(sessions.recentSessions, hasLength(1));

    await tester.tap(find.bySemanticsLabel('Clear activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear activity'));
    await tester.pumpAndSettle();

    expect(sessions.recentSessions, isEmpty);
    expect((await WorkSessionController.load()).recentSessions, isEmpty);
  });

  testWidgets('Activity clear cancellation preserves both stores', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final WorkSessionController sessions = await _sessionsWithRecent(prefs);
    final HistoryController history = await _pumpActivity(
      tester,
      workSessions: sessions,
    );

    await tester.tap(find.bySemanticsLabel('Clear activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(history.entries, hasLength(2));
    expect(sessions.recentSessions, hasLength(1));
    expect(
      (jsonDecode(prefs.getString('mb.history.entries.v2')!)
          as Map<String, dynamic>)['entries'],
      hasLength(2),
    );
    expect((await WorkSessionController.load()).recentSessions, hasLength(1));
  });

  testWidgets('invalid protected recent session does not navigate', (
    WidgetTester tester,
  ) async {
    final WorkSessionController sessions = WorkSessionController(
      recentSessions: <WorkSession>[_protectedRecentSession()],
    );
    await _pumpActivity(tester, workSessions: sessions);

    await tester.tap(find.bySemanticsLabel('Resume Protected session'));
    await tester.pumpAndSettle();

    expect(sessions.session, isNull);
    expect(sessions.workflowError, 'This session can no longer be resumed.');
    expect(find.byType(ToolDetailRoute), findsNothing);
    expect(find.text('Activity'), findsWidgets);
  });

  testWidgets(
    'Activity clear removes both stores but keeps live, branch, and saved work',
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

      await tester.tap(find.bySemanticsLabel('Clear activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear activity'));
      await tester.pumpAndSettle();

      expect(history.entries, isEmpty);
      expect(sessions.recentSessions, isEmpty);
      expect(sessions.session, same(live));
      expect(sessions.branchOrigin, same(original));
      expect(sessions.savedWorkflows.single.name, 'Rates');
      final WorkSessionController restored = await WorkSessionController.load();
      expect(restored.recentSessions, isEmpty);
      expect(restored.savedWorkflows.single.name, 'Rates');
    },
  );

  testWidgets('History clear leaves resumable sessions intact', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final WorkSessionController sessions = await _sessionsWithRecent(prefs);
    final HistoryController history = await _pumpHistory(
      tester,
      sessions: sessions,
    );

    expect(find.text('RESUMABLE SESSIONS'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Clear history'));
    await tester.pumpAndSettle();
    expect(find.text('Clear all history?'), findsOneWidget);
    expect(
      find.text(
        'Permanently deletes on-device history entries. Resumable sessions, your current session, and saved workflows are kept.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();

    expect(history.entries, isEmpty);
    expect(sessions.recentSessions, hasLength(1));
    expect((await HistoryController.load()).entries, isEmpty);
    expect((await WorkSessionController.load()).recentSessions, hasLength(1));
  });

  testWidgets('Activity clear stays compact with a full semantics label', (
    WidgetTester tester,
  ) async {
    await _pumpActivity(tester, textScale: 2);

    final Finder clear = find.bySemanticsLabel('Clear activity');
    expect(clear, findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
    expect(tester.getSize(clear).height, greaterThanOrEqualTo(32));
    expect(tester.takeException(), isNull);
  });

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
