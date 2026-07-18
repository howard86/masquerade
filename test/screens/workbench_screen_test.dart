import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/models/work_session.dart';
import 'package:masquerade/screens/detail/tool_detail_route.dart';
import 'package:masquerade/state/detection_preference_controller.dart';
import 'package:masquerade/state/work_session_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/mq/tool_grid_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _phone = Size(393, 852);

Future<void> _pumpWorkbench(
  WidgetTester tester, {
  TextScaler textScaler = TextScaler.noScaling,
  DetectionPreferenceController? detectionPreferenceController,
  WorkSessionController? workSessionController,
}) async {
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: _phone, textScaler: textScaler),
      child: MyApp(
        isWebOverride: false,
        skipSplash: true,
        detectionPreferenceController: detectionPreferenceController,
        workSessionController: workSessionController,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(CupertinoTextField).first, text);
  await tester.pump();
}

Finder _semantics(String label) => find.byWidgetPredicate(
  (Widget widget) => widget is Semantics && widget.properties.label == label,
);

Finder _semanticsStarts(String label) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is Semantics && widget.properties.label?.startsWith(label) == true,
);

Finder _stepSemantics(int index, String toolId, String status) =>
    _semanticsStarts(
      'Step $index, ${UtilityCatalog.byId(toolId).name}, $status. Input',
    );

WorkSessionController _safeCompletedSession() {
  final WorkSessionController sessions = WorkSessionController();
  sessions.start(
    UtilityCatalog.byId('bps'),
    Artifact<Object?>(
      kind: ArtifactKind.bps,
      rawValue: '25 bps',
      provenance: ArtifactProvenance.typed,
    ),
  );
  sessions.addNext(0, UtilityCatalog.byId('timestamp'), '1700000000');
  return sessions;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('shows automatic empty, artifact, search, and unknown states', (
    WidgetTester tester,
  ) async {
    await _pumpWorkbench(tester);

    expect(_semantics('Empty Workbench'), findsOneWidget);
    expect(find.bySemanticsLabel('Paste'), findsOneWidget);
    expect(find.bySemanticsLabel('Scan QR'), findsOneWidget);
    expect(find.text('CURRENT SESSION'), findsOneWidget);
    expect(find.text('SAVED WORKFLOWS'), findsOneWidget);

    await _enter(tester, '{"ok":true}');
    expect(find.text('Artifact detected'), findsOneWidget);
    expect(find.text('TOOL SUGGESTIONS'), findsOneWidget);
    expect(
      _semanticsStarts('Open JSON / YAML / TOML. Primary'),
      findsOneWidget,
    );

    await _enter(tester, 'uuid');
    expect(find.text('Tool search'), findsOneWidget);
    expect(_semantics('Open UUID'), findsOneWidget);

    await _enter(tester, 'unrecognized prose value');
    expect(find.text('Unknown text'), findsOneWidget);
    expect(
      _semantics('Unknown text. Open as text or send to a tool.'),
      findsOneWidget,
    );
  });

  testWidgets('unknown text opens inline or routes to a chosen tool', (
    WidgetTester tester,
  ) async {
    await _pumpWorkbench(tester);
    const String input = '  unrecognized prose value  ';
    await _enter(tester, input);

    await tester.tap(find.text('Open as text'));
    await tester.pump();
    expect(find.text('TEXT'), findsOneWidget);
    expect(_semantics('Opened text: $input'), findsOneWidget);

    await tester.tap(find.text('Send to tool'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.text('UUID').last);
    await tester.pumpAndSettle();
    final ToolDetailRoute route = tester.widget(find.byType(ToolDetailRoute));
    expect(route.descriptor.id, 'uuid');
    expect(route.seed, input);
  });

  testWidgets('Workbench input never reorders the Library catalog', (
    WidgetTester tester,
  ) async {
    await _pumpWorkbench(tester);
    await _enter(tester, '{"ok":true}');

    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();

    final List<String> ids = tester
        .widgetList<ToolGridCard>(find.byType(ToolGridCard))
        .map((ToolGridCard card) => card.descriptor.id)
        .toList();
    expect(ids, UtilityCatalog.all.map((UtilityDescriptor tool) => tool.id));
  });

  testWidgets('suggestions open the detected tool with the captured input', (
    WidgetTester tester,
  ) async {
    final WorkSessionController sessions = WorkSessionController();
    await _pumpWorkbench(tester, workSessionController: sessions);
    await _enter(tester, '{"ok":true}');

    await tester.tap(find.text('JSON / YAML / TOML'));
    await tester.pumpAndSettle();
    expect(find.byType(ToolDetailRoute), findsOneWidget);
    final ToolDetailRoute route = tester.widget(find.byType(ToolDetailRoute));
    expect(route.sessionStepIndex, 0);
    expect(sessions.session!.steps.single.toolId, 'json');
    expect(
      tester
          .widgetList<CupertinoTextField>(find.byType(CupertinoTextField))
          .any(
            (CupertinoTextField field) =>
                field.controller?.text == '{"ok":true}',
          ),
      isTrue,
    );
  });

  testWidgets('shows ranked reasons and preserves the captured artifact', (
    WidgetTester tester,
  ) async {
    await _pumpWorkbench(tester);
    const String input = '  1700000000  ';
    await _enter(tester, input);

    expect(find.textContaining('Primary · 82%'), findsOneWidget);
    expect(find.textContaining('ordinary number'), findsOneWidget);
    expect(find.textContaining('Alternative · 62%'), findsOneWidget);

    await tester.tap(find.text('Timestamp'));
    await tester.pumpAndSettle();
    final ToolDetailRoute route = tester.widget(find.byType(ToolDetailRoute));
    expect(route.seed, input);
    expect(route.initialArtifact?.rawValue, input);
    expect(route.initialArtifact?.kind, ArtifactKind.timestamp);
    expect(route.initialArtifact?.provenance, ArtifactProvenance.typed);
    expect(route.initialArtifact?.parserResult, isNotNull);
  });

  testWidgets('explicit correction changes the selected destination', (
    WidgetTester tester,
  ) async {
    final DetectionPreferenceController preferences =
        DetectionPreferenceController();
    await _pumpWorkbench(tester, detectionPreferenceController: preferences);
    await _enter(tester, '1700000000');

    await tester.tap(
      find.bySemanticsLabel('Make Number Base the primary interpretation'),
    );
    await tester.pumpAndSettle();

    expect(_semanticsStarts('Open Number Base. Primary'), findsOneWidget);
    expect(_semanticsStarts('Open Timestamp. Alternative'), findsOneWidget);
    await tester.tap(_semanticsStarts('Open Number Base. Primary'));
    await tester.pumpAndSettle();
    final ToolDetailRoute route = tester.widget(find.byType(ToolDetailRoute));
    expect(route.descriptor.id, 'number_base');
    expect(route.initialArtifact?.kind, ArtifactKind.number);
  });

  testWidgets('opening an alternate does not save a preference', (
    WidgetTester tester,
  ) async {
    await _pumpWorkbench(tester);
    await _enter(tester, '1700000000');

    await tester.tap(_semanticsStarts('Open Number Base. Alternative'));
    await tester.pumpAndSettle();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(
      prefs.containsKey(DetectionPreferenceController.storageKey),
      isFalse,
    );
  });

  testWidgets('JWT offers Base64 as a lower-confidence interpretation', (
    WidgetTester tester,
  ) async {
    await _pumpWorkbench(tester);
    await _enter(tester, 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.signature');

    expect(find.text('JWT'), findsOneWidget);
    expect(find.text('Base64'), findsOneWidget);
    expect(find.textContaining('Primary · 100%'), findsOneWidget);
    expect(find.textContaining('Alternative · 74%'), findsOneWidget);
  });

  testWidgets('ranked rows render at large text scale without overflow', (
    WidgetTester tester,
  ) async {
    await _pumpWorkbench(tester, textScaler: const TextScaler.linear(2));
    await _enter(tester, '1700000000');

    expect(_semanticsStarts('Open Timestamp. Primary'), findsOneWidget);
    expect(_semanticsStarts('Open Number Base. Alternative'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paste preserves clipboard provenance and exact raw input', (
    WidgetTester tester,
  ) async {
    const String raw = '  {"ok":true}  ';
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall call,
    ) async {
      if (call.method == 'Clipboard.getData') {
        return <String, Object>{'text': raw};
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await _pumpWorkbench(tester);

    await tester.tap(find.bySemanticsLabel('Paste'));
    await tester.pump();
    await tester.tap(find.text('JSON / YAML / TOML'));
    await tester.pumpAndSettle();

    final ToolDetailRoute route = tester.widget(find.byType(ToolDetailRoute));
    expect(route.seed, raw);
    expect(route.initialArtifact?.rawValue, raw);
    expect(route.initialArtifact?.provenance, ArtifactProvenance.clipboard);
  });

  testWidgets('renders an ordered safe session at large text scale', (
    WidgetTester tester,
  ) async {
    const String jwt = 'eyJhbGciOiJub25lIn0.eyJhdCI6MTcwMDAwMDAwMH0.';
    final WorkSessionController sessions = WorkSessionController();
    sessions.start(
      UtilityCatalog.byId('jwt'),
      Artifact<Object?>(
        kind: ArtifactKind.jwt,
        rawValue: jwt,
        provenance: ArtifactProvenance.typed,
      ),
    );
    sessions.addNext(0, UtilityCatalog.byId('json'), '{"at":1700000000}');
    sessions.addNext(1, UtilityCatalog.byId('timestamp'), '1700000000');

    await _pumpWorkbench(
      tester,
      textScaler: const TextScaler.linear(2),
      workSessionController: sessions,
    );

    expect(find.text('1. JWT'), findsOneWidget);
    expect(find.text('2. JSON / YAML / TOML'), findsOneWidget);
    expect(find.text('3. Timestamp'), findsOneWidget);
    expect(find.text('COMPLETED'), findsNWidgets(2));
    expect(find.text('RUNNING'), findsOneWidget);
    expect(_semanticsStarts('Step 1, JWT, Completed. Input'), findsOneWidget);
    expect(
      _semanticsStarts('Step 3, Timestamp, Running. Input'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics &&
            (widget.properties.label?.contains(jwt) ?? false),
      ),
      findsNothing,
    );
    expect(find.textContaining(jwt), findsNothing);
    expect(find.textContaining('1700000000'), findsNothing);
    for (final WorkflowStep step in sessions.session!.steps) {
      expect(step.input.safePreview, isNot(step.input.rawValue));
    }
    final Finder first = _stepSemantics(1, 'jwt', 'Completed');
    await tester.ensureVisible(first);
    expect(tester.getSize(first).height, greaterThanOrEqualTo(44));
    expect(tester.widget<Semantics>(first).properties.onTap, isNotNull);
    expect(
      tester
          .getSemantics(first)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    tester.widget<Semantics>(first).properties.onTap!();
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.ensureVisible(find.text('Replace input'));
    await tester.tap(find.text('Replace input'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('safe step actions copy, share, and reopen exact data', (
    WidgetTester tester,
  ) async {
    final WorkSessionController sessions = _safeCompletedSession();
    MethodCall? clipboardCall;
    MethodCall? shareCall;
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall call,
    ) async {
      if (call.method == 'Clipboard.setData') clipboardCall = call;
      return null;
    });
    const MethodChannel shareChannel = MethodChannel(
      'dev.fluttercommunity.plus/share',
    );
    messenger.setMockMethodCallHandler(shareChannel, (MethodCall call) async {
      shareCall = call;
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(shareChannel, null);
    });
    await _pumpWorkbench(tester, workSessionController: sessions);
    final Finder first = _stepSemantics(1, 'bps', 'Completed');

    await tester.ensureVisible(first);
    await tester.tap(first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy output'));
    await tester.pump();
    expect(clipboardCall?.method, 'Clipboard.setData');
    expect(clipboardCall?.arguments, <String, String>{'text': '1700000000'});
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share output'));
    await tester.pumpAndSettle();
    expect(shareCall?.method, 'share');
    final Map<Object?, Object?> shared = Map<Object?, Object?>.from(
      shareCall!.arguments as Map<Object?, Object?>,
    );
    expect(shared['text'], '1700000000');
    expect(shared['originWidth'], greaterThan(0));
    expect(shared['originHeight'], greaterThan(0));

    await tester.tap(first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reopen'));
    await tester.pumpAndSettle();
    final ToolDetailRoute route = tester.widget(find.byType(ToolDetailRoute));
    expect(route.seed, '25 bps');
    expect(route.sessionStepIndex, 0);
  });

  testWidgets('protected step omits clipboard and share actions', (
    WidgetTester tester,
  ) async {
    const String jwt = 'eyJhbGciOiJub25lIn0.eyJhdCI6MTcwMDAwMDAwMH0.';
    final WorkSessionController sessions = WorkSessionController();
    sessions.start(
      UtilityCatalog.byId('jwt'),
      Artifact<Object?>(
        kind: ArtifactKind.jwt,
        rawValue: jwt,
        provenance: ArtifactProvenance.typed,
      ),
    );
    sessions.addNext(0, UtilityCatalog.byId('json'), '{"at":1700000000}');
    await _pumpWorkbench(tester, workSessionController: sessions);

    final Finder first = _stepSemantics(1, 'jwt', 'Completed');
    await tester.ensureVisible(first);
    await tester.tap(first);
    await tester.pumpAndSettle();

    expect(find.text('Copy output'), findsNothing);
    expect(find.text('Share output'), findsNothing);
    expect(find.textContaining(jwt), findsNothing);
  });

  testWidgets('replace warns before deterministically removing later steps', (
    WidgetTester tester,
  ) async {
    final WorkSessionController sessions = _safeCompletedSession();
    await _pumpWorkbench(tester, workSessionController: sessions);
    final Finder first = _stepSemantics(1, 'bps', 'Completed');

    await tester.ensureVisible(first);
    await tester.tap(first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace input'));
    await tester.pumpAndSettle();

    expect(find.text('Replace input and remove later steps?'), findsOneWidget);
    expect(
      find.text('All steps after this one will be removed.'),
      findsOneWidget,
    );
    expect(sessions.session!.steps, hasLength(2));
    await tester.enterText(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.byType(CupertinoTextField),
      ),
      '50 bps',
    );
    expect(sessions.session!.steps, hasLength(2));
    await tester.tap(find.text('Replace and remove'));
    await tester.pumpAndSettle();

    expect(sessions.session!.steps, hasLength(1));
    expect(sessions.session!.steps.single.input.rawValue, '50 bps');
    expect(sessions.session!.steps.single.output, isNull);
    expect(sessions.session!.steps.single.status, WorkflowStepStatus.running);
  });

  testWidgets('stale action sheet cannot mutate a replacement session', (
    WidgetTester tester,
  ) async {
    final WorkSessionController sessions = _safeCompletedSession();
    await _pumpWorkbench(tester, workSessionController: sessions);
    final Finder first = _stepSemantics(1, 'bps', 'Completed');

    await tester.ensureVisible(first);
    await tester.tap(first);
    await tester.pumpAndSettle();
    sessions.start(
      UtilityCatalog.byId('bps'),
      Artifact<Object?>(
        kind: ArtifactKind.bps,
        rawValue: '99 bps',
        provenance: ArtifactProvenance.typed,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Remove subsequent steps'));
    await tester.pumpAndSettle();

    expect(sessions.session!.steps, hasLength(1));
    expect(sessions.session!.steps.single.input.rawValue, '99 bps');
  });

  testWidgets('stale replace dialog cannot mutate a replacement session', (
    WidgetTester tester,
  ) async {
    final WorkSessionController sessions = _safeCompletedSession();
    await _pumpWorkbench(tester, workSessionController: sessions);
    final Finder first = _stepSemantics(1, 'bps', 'Completed');

    await tester.ensureVisible(first);
    await tester.tap(first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace input'));
    await tester.pumpAndSettle();
    sessions.start(
      UtilityCatalog.byId('bps'),
      Artifact<Object?>(
        kind: ArtifactKind.bps,
        rawValue: '99 bps',
        provenance: ArtifactProvenance.typed,
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.byType(CupertinoTextField),
      ),
      '50 bps',
    );
    await tester.tap(find.text('Replace and remove'));
    await tester.pumpAndSettle();

    expect(sessions.session!.steps, hasLength(1));
    expect(sessions.session!.steps.single.input.rawValue, '99 bps');
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplicate and remove actions produce deterministic stacks', (
    WidgetTester tester,
  ) async {
    final WorkSessionController sessions = _safeCompletedSession();
    await _pumpWorkbench(tester, workSessionController: sessions);
    Finder first = _stepSemantics(1, 'bps', 'Completed');

    await tester.ensureVisible(first);
    await tester.tap(first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate step'));
    await tester.pumpAndSettle();
    expect(sessions.session!.steps, hasLength(3));
    expect(sessions.session!.steps[1].toolId, 'bps');

    first = _stepSemantics(1, 'bps', 'Completed');
    await tester.tap(first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove subsequent steps'));
    await tester.pumpAndSettle();
    expect(sessions.session!.steps, hasLength(1));
    expect(sessions.session!.steps.single.toolId, 'bps');
  });

  testWidgets('branch exposes the origin and reopens the active continuation', (
    WidgetTester tester,
  ) async {
    final WorkSessionController sessions = WorkSessionController();
    sessions.start(
      UtilityCatalog.byId('json'),
      Artifact<Object?>(
        kind: ArtifactKind.json,
        rawValue: '[65,66]',
        provenance: ArtifactProvenance.typed,
      ),
    );
    expect(sessions.addNext(0, UtilityCatalog.byId('bytes'), '[65,66]'), 1);
    final WorkSession original = sessions.session!;
    await _pumpWorkbench(tester, workSessionController: sessions);
    Finder first = _stepSemantics(1, 'json', 'Completed');

    await tester.ensureVisible(first);
    await tester.tap(first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Branch from here'));
    await tester.pumpAndSettle();

    expect(sessions.branchOrigin, same(original));
    expect(sessions.session!.steps, hasLength(1));
    expect(find.text('Original path · 2 steps'), findsOneWidget);
    first = _stepSemantics(1, 'json', 'Completed');
    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(find.text('Branch from here'), findsNothing);
    await tester.tap(find.text('Reopen'));
    await tester.pumpAndSettle();
    expect(find.byType(ToolDetailRoute), findsOneWidget);
    expect(find.text('ADD NEXT STEP'), findsOneWidget);
  });
}
