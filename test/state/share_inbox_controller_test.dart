import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/models/saved_workflow.dart';
import 'package:masquerade/state/share_inbox_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel(ShareInboxController.channelName);
  final List<MethodCall> calls = <MethodCall>[];
  List<Object?> nativeItems = <Object?>[];
  List<Object?> intentItems = <Object?>[];

  SavedWorkflow workflow(String id, String name) {
    final DateTime now = DateTime.fromMillisecondsSinceEpoch(1000);
    return SavedWorkflow(
      id: id,
      name: name,
      createdAt: now,
      updatedAt: now,
      steps: <SavedWorkflowStep>[
        SavedWorkflowStep(toolId: 'json', settings: <String, Object?>{}),
      ],
    );
  }

  Map<String, Object?> item({
    String id = '11111111-1111-1111-1111-111111111111',
    String kind = 'text',
    String payload = 'hello',
    bool sensitive = false,
    Uint8List? data,
    String? filename,
  }) {
    final Map<String, Object?> value = <String, Object?>{
      'id': id,
      'kind': kind,
      'createdAt': 1000,
      'byteCount': data?.length ?? utf8.encode(payload).length,
      'sensitive': sensitive,
      if (kind == 'file') 'data': data else 'payload': payload,
    };
    if (filename != null) value['filename'] = filename;
    return value;
  }

  setUp(() {
    calls.clear();
    nativeItems = <Object?>[];
    intentItems = <Object?>[];
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          return switch (call.method) {
            'list' => nativeItems,
            'consumeIntents' => intentItems,
            'syncWorkflows' => null,
            'remove' => true,
            'clear' => null,
            _ => throw MissingPluginException(),
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'loads ordinary text, URL, and UTF-8 file without persisting them',
    () async {
      nativeItems = <Object?>[
        item(),
        item(
          id: '22222222-2222-2222-2222-222222222222',
          kind: 'url',
          payload: 'https://example.com',
        ),
        item(
          id: '33333333-3333-3333-3333-333333333333',
          kind: 'file',
          data: Uint8List.fromList(utf8.encode('{"ok":true}')),
          filename: 'fixture.json',
        ),
      ];

      final ShareInboxController controller = await ShareInboxController.load(
        channel: channel,
      );

      expect(controller.items, hasLength(3));
      expect(controller.items[0].artifact.rawValue, 'hello');
      expect(controller.items[1].artifact.kind, ArtifactKind.url);
      expect(controller.items[2].artifact.rawValue, '{"ok":true}');
      expect(
        controller.items.map(
          (ShareInboxItem value) => value.artifact.provenance,
        ),
        everyElement(ArtifactProvenance.shareExtension),
      );
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    },
  );

  test(
    'fails closed for protected, binary, oversized, and malformed items',
    () async {
      const String secret = 'password=do-not-persist';
      nativeItems = <Object?>[
        item(payload: secret),
        item(
          id: '22222222-2222-2222-2222-222222222222',
          kind: 'file',
          data: Uint8List.fromList(<int>[0xff, 0xfe]),
          filename: 'binary.dat',
        ),
        <String, Object?>{
          ...item(id: '33333333-3333-3333-3333-333333333333'),
          'byteCount': ShareInboxController.maxPayloadBytes + 1,
        },
        item(id: 'not-an-id'),
        item(id: '44444444-4444-4444-4444-444444444444', sensitive: true),
      ];

      final ShareInboxController controller = await ShareInboxController.load(
        channel: channel,
      );

      expect(controller.items, isEmpty);
      expect(controller.error, 'Some shared items could not be loaded.');
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().map((String key) => '${prefs.get(key)}'),
        everyElement(isNot(contains(secret))),
      );
    },
  );

  test('matches the 64 KiB native persistence boundary', () async {
    final String boundary = ''.padRight(65536, 'a');
    nativeItems = <Object?>[item(payload: boundary)];
    final ShareInboxController controller = await ShareInboxController.load(
      channel: channel,
    );
    expect(controller.items.single.artifact.rawValue, hasLength(65536));

    nativeItems = <Object?>[item(payload: '${boundary}a')];
    await controller.refresh();
    expect(controller.items, isEmpty);
    expect(controller.error, 'Some shared items could not be loaded.');
  });

  test('remove and clear delete native handoffs before local state', () async {
    nativeItems = <Object?>[item()];
    final ShareInboxController controller = await ShareInboxController.load(
      channel: channel,
    );

    await controller.remove(controller.items.single.id);
    expect(controller.items, isEmpty);
    expect(calls.last.method, 'remove');
    expect(calls.last.arguments, '11111111-1111-1111-1111-111111111111');

    nativeItems = <Object?>[item()];
    await controller.refresh();
    await controller.clear();
    expect(controller.items, isEmpty);
    expect(calls.last.method, 'clear');
  });

  test(
    'consumes strict shortcut requests without persisting payloads',
    () async {
      intentItems = <Object?>[
        <String, Object?>{
          'id': '11111111-1111-1111-1111-111111111111',
          'action': 'inspectClipboard',
          'createdAt': 1000,
        },
        <String, Object?>{
          'id': '22222222-2222-2222-2222-222222222222',
          'action': 'runWorkflow',
          'createdAt': 2000,
          'workflowId': 'workflow-1',
          'input': '{"ok":true}',
        },
        <String, Object?>{
          'id': '33333333-3333-3333-3333-333333333333',
          'action': 'runWorkflow',
          'createdAt': 3000,
          'workflowId': 'workflow-1',
          'input': 'password=do-not-load',
        },
      ];

      final ShareInboxController controller = await ShareInboxController.load(
        channel: channel,
      );

      expect(
        controller.intentRequests.map((AppIntentRequest value) => value.action),
        <AppIntentAction>[
          AppIntentAction.inspectClipboard,
          AppIntentAction.runWorkflow,
        ],
      );
      expect(controller.error, 'Some shortcut actions could not be loaded.');
      expect(
        controller
            .takeIntentRequest(controller.intentRequests.first.id)
            ?.action,
        AppIntentAction.inspectClipboard,
      );
      expect(controller.intentRequests, hasLength(1));
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    },
  );

  test('overlapping intent refreshes are single-flight and additive', () async {
    final Completer<List<Object?>> pending = Completer<List<Object?>>();
    int consumes = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'consumeIntents') {
            consumes++;
            return pending.future;
          }
          if (call.method == 'list') return <Object?>[];
          return null;
        });
    final ShareInboxController controller = ShareInboxController(
      channel: channel,
    );

    final Future<void> first = controller.refreshIntents();
    final Future<void> second = controller.refreshIntents();
    expect(identical(first, second), isTrue);
    expect(consumes, 1);
    pending.complete(<Object?>[
      <String, Object?>{
        'id': '11111111-1111-1111-1111-111111111111',
        'action': 'resumeLastSession',
        'createdAt': 1000,
      },
    ]);
    await Future.wait(<Future<void>>[first, second]);
    expect(controller.intentRequests, hasLength(1));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (MethodCall call) async => <Object?>[],
        );
    await controller.refreshIntents();
    expect(controller.intentRequests, hasLength(1));
  });

  test('syncs only unique safe workflow metadata', () async {
    final ShareInboxController controller = ShareInboxController(
      channel: channel,
    );
    final SavedWorkflow safe = workflow('workflow-1', ' JSON cleanup ');

    await controller.syncWorkflows(<SavedWorkflow>[
      safe,
      workflow('workflow-2', 'Unsafe\nname'),
      workflow('workflow-3', List<String>.filled(81, 'x').join()),
      safe,
    ]);

    expect(calls.single.method, 'syncWorkflows');
    expect(calls.single.arguments, <Object?>[
      <String, String>{'id': 'workflow-1', 'name': 'JSON cleanup'},
    ]);
  });

  test(
    'unsafe rename drops old donated metadata while keeping siblings',
    () async {
      final ShareInboxController controller = ShareInboxController(
        channel: channel,
      );

      await controller.syncWorkflows(<SavedWorkflow>[
        workflow('workflow-1', 'Safe name'),
        workflow('workflow-2', 'Timestamp cleanup'),
      ]);
      await controller.syncWorkflows(<SavedWorkflow>[
        workflow('workflow-1', 'Unsafe\u0000name'),
        workflow('workflow-2', 'Timestamp cleanup'),
      ]);

      expect(calls.last.arguments, <Object?>[
        <String, String>{'id': 'workflow-2', 'name': 'Timestamp cleanup'},
      ]);
    },
  );

  test('successful workflow sync clears its prior native error', () async {
    bool fail = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'syncWorkflows' && fail) {
            throw PlatformException(code: 'spotlight_unavailable');
          }
          return null;
        });
    final ShareInboxController controller = ShareInboxController(
      channel: channel,
    );
    final SavedWorkflow safe = workflow('workflow-1', 'JSON cleanup');

    await controller.syncWorkflows(<SavedWorkflow>[safe]);
    expect(controller.error, 'Shortcuts could not be updated.');
    fail = false;
    await controller.syncWorkflows(<SavedWorkflow>[safe]);

    expect(controller.error, isNull);
  });
}
