import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/tool_draft_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'round-trips the three explicit drafts without generator output',
    () async {
      final ToolDraftController drafts = await ToolDraftController.load();
      await drafts.saveJson(
        input: '{"safe":true}',
        source: 'json',
        target: 'minifiedJson',
      );
      await drafts.saveDiff(
        a: 'before',
        b: 'after',
        wordHighlight: false,
        ignoreWhitespace: true,
      );
      await drafts.saveGenerator(
        const GeneratorToolDraft(
          mode: 'token',
          length: 24,
          bytes: 32,
          lower: true,
          upper: false,
          digits: true,
          symbols: false,
          tokenFormat: 'base64url',
          uuidVersion: 'v7',
        ),
      );
      await drafts.flush();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String raw = prefs.getString(ToolDraftController.storageKey)!;
      expect(raw, contains('before'));
      expect(raw, isNot(contains('generated-secret')));

      final ToolDraftController restored = await ToolDraftController.load();
      expect(restored.json!.input, '{"safe":true}');
      expect(restored.json!.target, 'minifiedJson');
      expect(restored.diff!.b, 'after');
      expect(restored.diff!.ignoreWhitespace, isTrue);
      expect(restored.generator!.mode, 'token');
      expect(restored.generator!.bytes, 32);
    },
  );

  test('protected content removes an existing draft', () async {
    final ToolDraftController drafts = await ToolDraftController.load();
    await drafts.saveGenerator(
      const GeneratorToolDraft(
        mode: 'uuid',
        length: 20,
        bytes: 16,
        lower: true,
        upper: true,
        digits: true,
        symbols: true,
        tokenFormat: 'hex',
        uuidVersion: 'v7',
      ),
    );
    await drafts.saveJson(
      input: '{"safe":true}',
      source: 'auto',
      target: 'prettyJson',
    );
    await drafts.saveDiff(
      a: 'before',
      b: 'after',
      wordHighlight: true,
      ignoreWhitespace: false,
    );
    await drafts.saveDiff(
      a: 'before',
      b: 'authorization=do-not-save-either',
      wordHighlight: true,
      ignoreWhitespace: false,
    );
    expect(drafts.diff, isNull);
    expect(drafts.json!.input, '{"safe":true}');
    expect(drafts.generator!.uuidVersion, 'v7');
    await drafts.saveJson(
      input: '{"access_token":"do-not-save"}',
      source: 'json',
      target: 'prettyJson',
    );
    await drafts.flush();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(drafts.json, isNull);
    expect(drafts.diff, isNull);
    expect(drafts.generator!.uuidVersion, 'v7');
    expect(
      prefs.getString(ToolDraftController.storageKey) ?? '',
      isNot(contains('do-not-save')),
    );
  });

  test('clear is ordered after an already queued save', () async {
    final ToolDraftController drafts = await ToolDraftController.load();
    final int oldRevision = drafts.revision;
    final Future<void> saving = drafts.saveJson(
      input: '{"queued":true}',
      source: 'json',
      target: 'prettyJson',
    );
    drafts.suspendWrites();
    final Future<void> clearing = drafts.clear();
    await Future.wait<void>(<Future<void>>[saving, clearing]);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(ToolDraftController.storageKey), isFalse);
    drafts.resumeWrites();
    await drafts.saveJson(
      input: '{"stale-widget":true}',
      source: 'json',
      target: 'prettyJson',
      revision: oldRevision,
    );
    expect(prefs.containsKey(ToolDraftController.storageKey), isFalse);
  });

  test('malformed, old, and invalid entries fall back safely', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ToolDraftController.storageKey: '{bad',
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    ToolDraftController drafts = await ToolDraftController.load();
    expect(drafts.json, isNull);
    expect(prefs.containsKey(ToolDraftController.storageKey), isFalse);

    await prefs.setString(
      ToolDraftController.storageKey,
      jsonEncode(<String, Object>{'version': 0, 'json': <String, Object>{}}),
    );
    drafts = await ToolDraftController.load();
    expect(drafts.json, isNull);
    expect(prefs.containsKey(ToolDraftController.storageKey), isFalse);

    await prefs.setString(
      ToolDraftController.storageKey,
      jsonEncode(<String, Object>{
        'version': 1,
        'json': <String, Object>{
          'input': '{"kept":true}',
          'source': 'json',
          'target': 'prettyJson',
        },
        'generator': <String, Object>{
          'mode': 'password',
          'length': -1,
          'bytes': 16,
          'lower': true,
          'upper': true,
          'digits': true,
          'symbols': true,
          'tokenFormat': 'hex',
          'uuidVersion': 'v4',
        },
        'unknown': <String, Object>{'value': 'ignored'},
      }),
    );
    drafts = await ToolDraftController.load();
    expect(drafts.json!.input, '{"kept":true}');
    expect(drafts.generator, isNull);
    expect(
      prefs.getString(ToolDraftController.storageKey),
      isNot(contains('unknown')),
    );
  });

  group('debounced persistence', () {
    test('coalesces saves and writes once after the idle delay', () {
      fakeAsync((FakeAsync async) {
        late ToolDraftController drafts;
        ToolDraftController.load().then((ToolDraftController d) => drafts = d);
        async.flushMicrotasks();
        late SharedPreferences prefs;
        SharedPreferences.getInstance().then(
          (SharedPreferences p) => prefs = p,
        );
        async.flushMicrotasks();

        for (int i = 0; i < 20; i++) {
          drafts.saveJson(input: '{"n":$i}', source: 'json', target: 'tree');
          async.elapse(const Duration(milliseconds: 100));
        }
        expect(prefs.getString(ToolDraftController.storageKey), isNull);
        // The in-memory draft is current before the write lands.
        expect(drafts.json!.input, '{"n":19}');

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(
          prefs.getString(ToolDraftController.storageKey),
          contains('{\\"n\\":19}'),
        );
      });
    });

    test('a sensitive save never reaches prefs, even via the timer', () {
      fakeAsync((FakeAsync async) {
        late ToolDraftController drafts;
        ToolDraftController.load().then((ToolDraftController d) => drafts = d);
        async.flushMicrotasks();
        late SharedPreferences prefs;
        SharedPreferences.getInstance().then(
          (SharedPreferences p) => prefs = p,
        );
        async.flushMicrotasks();

        drafts.saveJson(input: '{"safe":1}', source: 'json', target: 'tree');
        async.elapse(const Duration(seconds: 1));
        drafts.saveJson(
          input: '{"access_token":"do-not-save"}',
          source: 'json',
          target: 'tree',
        );
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(drafts.json, isNull);
        expect(
          prefs.getString(ToolDraftController.storageKey) ?? '',
          allOf(isNot(contains('do-not-save')), isNot(contains('safe'))),
        );
      });
    });

    test('clear cancels a pending write', () {
      fakeAsync((FakeAsync async) {
        late ToolDraftController drafts;
        ToolDraftController.load().then((ToolDraftController d) => drafts = d);
        async.flushMicrotasks();
        late SharedPreferences prefs;
        SharedPreferences.getInstance().then(
          (SharedPreferences p) => prefs = p,
        );
        async.flushMicrotasks();

        drafts.saveDiff(
          a: 'before',
          b: 'after',
          wordHighlight: true,
          ignoreWhitespace: false,
        );
        drafts.clear();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(prefs.containsKey(ToolDraftController.storageKey), isFalse);
        expect(drafts.diff, isNull);
      });
    });

    testWidgets('scope flushes on app pause and on unmount', (
      WidgetTester tester,
    ) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final ToolDraftController drafts = ToolDraftController(prefs: prefs);
      await tester.runAsync(drafts.attach);
      await tester.pumpWidget(
        ToolDraftScope(controller: drafts, child: const SizedBox.shrink()),
      );

      await drafts.saveJson(input: '{"p":1}', source: 'json', target: 'tree');
      expect(prefs.getString(ToolDraftController.storageKey), isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(prefs.getString(ToolDraftController.storageKey), contains('p'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await drafts.saveDiff(
        a: 'left',
        b: 'right',
        wordHighlight: false,
        ignoreWhitespace: false,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(
        prefs.getString(ToolDraftController.storageKey),
        contains('right'),
      );
    });
  });
}
