import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/utils/jwt_parser.dart';
import 'package:masquerade/utils/sensitive_data_policy.dart';
import 'package:masquerade/widgets/mq/mq_status.dart';
import 'package:masquerade/widgets/tool_bodies/jwt_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // Hand-built fixture: header = {"alg":"HS256"}, payload = {"sub":"123","exp":1700000000}
  const String token =
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMiLCJleHAiOjE3MDAwMDAwMDB9.sig';

  testWidgets('JWT — decodes header and payload fields', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JWT');

    await tester.enterText(find.byType(EditableText).last, token);
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('HS256'), findsWidgets);
    expect(find.textContaining('sub'), findsWidgets);
    expect(find.textContaining('123'), findsWidgets);
  });

  testWidgets('JWT — shows decode-only disclaimer', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JWT');

    await tester.enterText(find.byType(EditableText).last, token);
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.textContaining('signature not verified'), findsOneWidget);
  });

  testWidgets('JWT — shows expired status for past exp', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JWT');

    await tester.enterText(find.byType(EditableText).last, token);
    await tester.pumpAndSettle(kDebouncePump);

    // exp is 2023-11-14, current time is 2026 → expired
    expect(find.textContaining('EXPIRED'), findsOneWidget);
  });

  testWidgets('JWT — invalid input announces via a live-region error pill', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await pumpHomeAndOpen(tester, 'JWT');

    await tester.enterText(find.byType(EditableText).last, 'not.a.jwt!');
    await tester.pumpAndSettle(kDebouncePump);

    final MqStatus status = tester.widget<MqStatus>(find.byType(MqStatus));
    expect(status.kind, MqStatusKind.danger);
    expect(status.label, contains('Invalid'));

    final SemanticsNode node = tester.getSemantics(find.byType(MqStatus));
    expect(node.label, status.label);
    expect(node.flagsCollection.isLiveRegion, isTrue);

    handle.dispose();
  });

  testWidgets('JWT — pumps body at narrow width without overflow', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const JwtBody(initialInput: token), 380);
    await tester.pumpAndSettle(kDebouncePump);
    expect(tester.takeException(), isNull);
  });

  testWidgets('JWT — decoded claims never route through Open in', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      JwtBody(initialInput: token, onSwitchTool: (_, _) {}),
      380,
    );
    await tester.pumpAndSettle(kDebouncePump);

    expect(find.text('OPEN IN'), findsNothing);
  });

  testWidgets('JWT — reuses a compatible detected parser result', (
    WidgetTester tester,
  ) async {
    const String raw = 'not.a.jwt';
    final JwtOk cached = JwtOk(
      header: <String, dynamic>{'alg': 'cached-alg'},
      payload: <String, dynamic>{'sub': 'cached-sub'},
      signature: 'cached-signature',
    );
    await pumpBodyAtWidth(
      tester,
      JwtBody(
        initialInput: raw,
        initialArtifact: Artifact<Object?>(
          kind: ArtifactKind.jwt,
          rawValue: raw,
          provenance: ArtifactProvenance.clipboard,
          parserResult: cached,
        ),
      ),
      380,
    );

    expect(find.textContaining('cached-sub'), findsWidgets);
    expect(find.textContaining('Invalid'), findsNothing);
  });

  testWidgets(
    'JWT — Copy all writes header, payload and signature to the clipboard',
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

      await pumpHomeAndOpen(tester, 'JWT');

      await tester.enterText(find.byType(EditableText).last, token);
      await tester.pumpAndSettle(kDebouncePump);

      await tester.tap(find.text('Copy all'));
      await tester.pump();

      expect(clipboardWrites, hasLength(1));
      final String written = clipboardWrites.single;
      expect(written, contains('HS256')); // Header
      expect(written, contains('"sub": "123"')); // Payload
      expect(written, contains('sig')); // Signature

      // Drain the copy toast's 3s auto-dismiss timer so the test ends clean.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('JWT — Copy all toast masks the decoded payload preview', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JWT');

    await tester.enterText(find.byType(EditableText).last, token);
    await tester.pumpAndSettle(kDebouncePump);

    await tester.tap(find.text('Copy all'));
    await tester.pump();

    // The toast shows the masked preview, never the raw header/payload/signature.
    expect(find.text(SensitiveDataPolicy.mask), findsOneWidget);
    expect(find.text('Copied to clipboard'), findsOneWidget);

    // Drain the copy toast's 3s auto-dismiss timer so the test ends clean.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('JWT — Copy all is hidden when there is no valid output', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'JWT');

    // Empty input → nothing parsed → the center action stays hidden.
    expect(find.text('Copy all'), findsNothing);

    // Invalid token keeps it hidden.
    await tester.enterText(find.byType(EditableText).last, 'not.a.jwt!');
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Copy all'), findsNothing);

    // A valid token surfaces it.
    await tester.enterText(find.byType(EditableText).last, token);
    await tester.pumpAndSettle(kDebouncePump);
    expect(find.text('Copy all'), findsOneWidget);
  });
}
