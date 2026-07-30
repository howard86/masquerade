import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/utils/sensitive_data_policy.dart';
import 'package:masquerade/utils/x509_inspector.dart';
import 'package:masquerade/widgets/mq/mq_button.dart';
import 'package:masquerade/widgets/mq/tool_action_bar.dart';
import 'package:masquerade/widgets/tool_bodies/open_in_footer.dart';
import 'package:masquerade/widgets/tool_bodies/x509_inspector_body.dart';

import '_helpers.dart';

void main() {
  final String leaf = File(
    'test/fixtures/x509_leaf.pem',
  ).readAsStringSync().trim();
  const String key =
      '-----BEGIN PRIVATE KEY-----\nnot-a-key\n-----END PRIVATE KEY-----';

  testWidgets('shows local certificate fields and conversions on narrow UI', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, X509InspectorBody(initialInput: leaf), 340);

    expect(find.textContaining('LOCAL INSPECTION ONLY'), findsOneWidget);
    expect(find.textContaining('CN=api.example.test'), findsOneWidget);
    expect(find.textContaining('DNS:api.example.test'), findsOneWidget);
    expect(find.text('RSA · 2048 bits'), findsOneWidget);
    expect(find.widgetWithText(MqButton, 'Copy PEM'), findsOneWidget);
    expect(find.widgetWithText(MqButton, 'Copy DER base64'), findsOneWidget);
    expect(find.widgetWithText(MqButton, 'Copy DER hex'), findsOneWidget);
    expect(find.textContaining('verify online'), findsNothing);
    expect(find.widgetWithText(MqButton, 'Fetch'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('date, hash, and DER routes use compatible tools', (
    WidgetTester tester,
  ) async {
    String? toolId;
    String? value;
    await pumpBodyAtWidth(
      tester,
      X509InspectorBody(
        initialInput: leaf,
        onSwitchTool: (UtilityDescriptor tool, String routed) {
          toolId = tool.id;
          value = routed;
        },
      ),
      340,
    );

    expect(
      find.widgetWithText(MqButton, 'Not before → Timestamp'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(MqButton, 'Not after → Timestamp'),
      findsOneWidget,
    );
    expect(find.widgetWithText(MqButton, 'SHA-1 → Hash'), findsOneWidget);
    final Finder sha256 = find.widgetWithText(MqButton, 'SHA-256 → Hash');
    await tester.ensureVisible(sha256);
    await tester.tap(sha256);
    expect(toolId, 'hash');
    expect(value, hasLength(64));

    final Finder der = find.widgetWithText(MqButton, 'DER → Bytes');
    await tester.ensureVisible(der);
    await tester.tap(der);
    expect(toolId, 'bytes');
    expect(value, startsWith('48 '));
  });

  testWidgets(
    'protected lineage only routes inside a protected add-next step',
    (WidgetTester tester) async {
      final Artifact<Object?> sensitive = Artifact<Object?>(
        kind: ArtifactKind.unknown,
        rawValue: leaf,
        provenance: ArtifactProvenance.generated,
        sensitivity: ArtifactSensitivity.sensitive,
      );
      await pumpBodyAtWidth(
        tester,
        MobileSessionRouteScope(
          addNext: false,
          protectedSession: true,
          child: X509InspectorBody(
            initialInput: leaf,
            initialArtifact: sensitive,
            onSwitchTool: (_, _) {},
          ),
        ),
        340,
      );
      expect(find.widgetWithText(MqButton, 'SHA-256 → Hash'), findsNothing);

      await pumpBodyAtWidth(
        tester,
        MobileSessionRouteScope(
          addNext: true,
          protectedSession: true,
          child: X509InspectorBody(
            initialInput: leaf,
            initialArtifact: sensitive,
            onSwitchTool: (_, _) {},
          ),
        ),
        340,
      );
      expect(find.widgetWithText(MqButton, 'SHA-256 → Hash'), findsOneWidget);
    },
  );

  testWidgets('private-key seed is never retained or rendered', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      X509InspectorBody(
        initialInput: key,
        initialArtifact: Artifact<Object?>(
          kind: ArtifactKind.unknown,
          rawValue: key,
          provenance: ArtifactProvenance.clipboard,
          sensitivity: ArtifactSensitivity.sensitive,
        ),
      ),
      340,
    );

    final EditableText input = tester.widget<EditableText>(
      find.byType(EditableText),
    );
    expect(input.controller.text, isEmpty);
    expect(find.text(privateKeyWarning.toUpperCase()), findsOneWidget);
    expect(find.textContaining('not-a-key'), findsNothing);
    _expectNoOutputActions();
  });

  testWidgets(
    'private-key paste clears prior output and never records history',
    (WidgetTester tester) async {
      final HistoryController history = HistoryController();
      await _pumpWithHistory(
        tester,
        history,
        X509InspectorBody(initialInput: leaf),
      );
      expect(find.textContaining('CN=api.example.test'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), key);
      await tester.pump(const Duration(milliseconds: 500));

      final EditableText input = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(input.controller.text, isEmpty);
      expect(find.text(privateKeyWarning.toUpperCase()), findsOneWidget);
      _expectNoOutputActions();
      expect(history.entries, isEmpty);
    },
  );

  testWidgets('action-bar paste preflights private keys and keeps warning', (
    WidgetTester tester,
  ) async {
    final ToolActionBarController actionBar = ToolActionBarController();
    addTearDown(actionBar.dispose);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async => call.method == 'Clipboard.getData'
          ? <String, Object?>{'text': key}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpBodyAtWidth(
      tester,
      X509InspectorBody(initialInput: leaf, actionBar: actionBar),
      340,
    );

    actionBar.onPaste!();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      isEmpty,
    );
    expect(find.text(privateKeyWarning.toUpperCase()), findsOneWidget);
    _expectNoOutputActions();
  });

  testWidgets('remains usable at 2x text scale', (WidgetTester tester) async {
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    await pumpBodyAtWidth(tester, X509InspectorBody(initialInput: leaf), 340);

    expect(find.widgetWithText(MqButton, 'Copy PEM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog marks tool sensitive, history-disabled, and reachable', (
    WidgetTester tester,
  ) async {
    final UtilityDescriptor tool = UtilityCatalog.byId('x509_inspector');
    expect(tool.sensitivity, UtilitySensitivity.sensitive);
    expect(tool.historyPolicy, HistoryPolicy.disabled);
    expect(tool.defaultCardWidth, CardWidthClass.wide);
    await pumpHomeAndOpen(tester, 'X.509 Inspector');
    expect(find.byType(X509InspectorBody), findsOneWidget);
  });

  testWidgets(
    'x509 — Copy all writes every certificate field to the clipboard',
    (WidgetTester tester) async {
      final List<String> clipboardWrites = <String>[];
      final TestDefaultBinaryMessenger messenger =
          tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (
        MethodCall call,
      ) async {
        if (call.method == 'Clipboard.setData') {
          final Map<dynamic, dynamic> args = call.arguments as Map;
          clipboardWrites.add(args['text'] as String);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await pumpHomeAndOpen(tester, 'X.509 Inspector');

      await tester.enterText(find.byType(EditableText).first, leaf);
      await tester.pumpAndSettle(kDebouncePump);

      final Finder copyAll = find.text('Copy all');
      await tester.ensureVisible(copyAll);
      await tester.tap(copyAll);
      await tester.pump();

      expect(clipboardWrites, hasLength(1));
      final String written = clipboardWrites.single;
      expect(written, contains('CN=api.example.test')); // Subject
      expect(written, contains('CN=Masquerade-Test-Root')); // Issuer
      expect(written, contains('DNS:api.example.test')); // SANs
      expect(written, contains('RSA · 2048 bits')); // Public key

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('x509 — Copy all toast masks output in a protected session', (
    WidgetTester tester,
  ) async {
    final ToolActionBarController actionBar = ToolActionBarController();
    addTearDown(actionBar.dispose);
    final List<String> clipboardWrites = <String>[];
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        final Map<dynamic, dynamic> args = call.arguments as Map;
        clipboardWrites.add(args['text'] as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final Artifact<Object?> sensitive = Artifact<Object?>(
      kind: ArtifactKind.unknown,
      rawValue: leaf,
      provenance: ArtifactProvenance.generated,
      sensitivity: ArtifactSensitivity.sensitive,
    );

    // The copy toast mounts on the app-level Overlay, above `home:` — wrap
    // MqTheme via `builder:` (as the real app does) instead of nesting it
    // inside `home:`, so the toast can find it too.
    await tester.pumpWidget(
      CupertinoApp(
        builder: (BuildContext context, Widget? child) => MqTheme(
          tokens: MqTokens(
            colors: MqColors.light(),
            brightness: Brightness.light,
          ),
          child: child!,
        ),
        home: HistoryScope(
          controller: HistoryController(),
          child: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: MobileSessionRouteScope(
                addNext: true,
                protectedSession: true,
                child: Column(
                  children: <Widget>[
                    X509InspectorBody(
                      initialInput: leaf,
                      initialArtifact: sensitive,
                      actionBar: actionBar,
                    ),
                    ToolActionBar(controller: actionBar),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder copyAll = find.text('Copy all');
    await tester.ensureVisible(copyAll);
    await tester.tap(copyAll);
    await tester.pump();

    // The clipboard still receives the real payload...
    expect(clipboardWrites, hasLength(1));
    expect(clipboardWrites.single, contains('CN=api.example.test'));
    // ...but the on-screen toast preview is masked, not the raw payload.
    expect(find.text(SensitiveDataPolicy.mask), findsOneWidget);
    expect(find.text('Copied to clipboard'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('x509 — Copy all is hidden when there is no valid output', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'X.509 Inspector');

    expect(find.text('Copy all'), findsNothing);

    await tester.enterText(find.byType(EditableText).first, 'not a cert');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Copy all'), findsNothing);

    await tester.enterText(find.byType(EditableText).first, leaf);
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Copy all'), findsOneWidget);
  });
}

void _expectNoOutputActions() {
  expect(find.text('Subject'), findsNothing);
  expect(find.widgetWithText(MqButton, 'Copy PEM'), findsNothing);
  expect(find.widgetWithText(MqButton, 'Copy DER base64'), findsNothing);
  expect(find.widgetWithText(MqButton, 'SHA-256 → Hash'), findsNothing);
}

Future<void> _pumpWithHistory(
  WidgetTester tester,
  HistoryController history,
  Widget body,
) async {
  await tester.binding.setSurfaceSize(const Size(400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    CupertinoApp(
      home: MqTheme(
        tokens: MqTokens(
          colors: MqColors.light(),
          brightness: Brightness.light,
        ),
        child: HistoryScope(
          controller: history,
          child: CupertinoPageScaffold(
            child: SingleChildScrollView(child: body),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
