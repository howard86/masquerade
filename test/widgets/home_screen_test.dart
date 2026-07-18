import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/screens/detail/tool_detail_route.dart';
import 'package:masquerade/state/share_inbox_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<Finder> pumpHero(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(kHomeSurfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp(skipSplash: true));
    await tester.pumpAndSettle();
    final Finder input = find.byWidgetPredicate(
      (Widget widget) =>
          widget is CupertinoTextField &&
          widget.placeholder == 'Paste timestamp, JSON, hex, base64, color…',
    );
    expect(input, findsOneWidget);
    return input;
  }

  Finder semantics(String label) => find.byWidgetPredicate(
    (Widget widget) => widget is Semantics && widget.properties.label == label,
  );

  Finder semanticsStarts(String label) => find.byWidgetPredicate(
    (Widget widget) =>
        widget is Semantics &&
        widget.properties.label?.startsWith(label) == true,
  );

  testWidgets('empty capture offers explicit paste and QR scan controls', (
    WidgetTester tester,
  ) async {
    await pumpHero(tester);

    expect(semantics('Empty Workbench'), findsOneWidget);
    expect(find.bySemanticsLabel('Paste'), findsOneWidget);
    expect(find.bySemanticsLabel('Scan QR'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
  });

  testWidgets('captured content reveals Paste and Clear then clears state', (
    WidgetTester tester,
  ) async {
    final Finder hero = await pumpHero(tester);
    await tester.enterText(hero, '#ff5733');
    await tester.pumpAndSettle();

    expect(find.text('Paste'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('Artifact detected'), findsOneWidget);
    expect(semanticsStarts('Open Color. Primary'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(semantics('Empty Workbench'), findsOneWidget);
    expect(find.text('TOOL SUGGESTIONS'), findsNothing);
  });

  testWidgets('artifact detection ranks timestamp above number base', (
    WidgetTester tester,
  ) async {
    final Finder hero = await pumpHero(tester);
    await tester.enterText(hero, '1700000000');
    await tester.pump();

    expect(semanticsStarts('Open Timestamp. Primary'), findsOneWidget);
    expect(semanticsStarts('Open Number Base. Alternative'), findsOneWidget);
  });

  testWidgets('tapping a suggestion pushes a route seeded with capture', (
    WidgetTester tester,
  ) async {
    final Finder hero = await pumpHero(tester);
    await tester.enterText(hero, '{"hello":"world"}');
    await tester.pump();

    await tester.tap(find.text('JSON / YAML / TOML'));
    await tester.pumpAndSettle();

    final ToolDetailRoute route = tester.widget(find.byType(ToolDetailRoute));
    expect(route.descriptor.id, 'json');
    expect(route.seed, '{"hello":"world"}');
  });

  testWidgets('late foreground shortcut explicitly inspects clipboard', (
    WidgetTester tester,
  ) async {
    const MethodChannel inboxChannel = MethodChannel(
      ShareInboxController.channelName,
    );
    List<Object?> intents = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(inboxChannel, (MethodCall call) async {
          return switch (call.method) {
            'list' => <Object?>[],
            'consumeIntents' => intents,
            'syncWorkflows' => null,
            _ => null,
          };
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'Clipboard.getData') {
            return <String, String>{'text': '{"from":"shortcut"}'};
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(inboxChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final ShareInboxController inbox = ShareInboxController(
      channel: inboxChannel,
    );
    addTearDown(inbox.dispose);
    await tester.binding.setSurfaceSize(kHomeSurfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MyApp(shareInboxController: inbox, skipSplash: true),
    );
    await tester.pumpAndSettle();

    intents = <Object?>[
      <String, Object?>{
        'id': '11111111-1111-1111-1111-111111111111',
        'action': 'inspectClipboard',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
    ];
    await inbox.refreshIntents();
    await tester.pumpAndSettle();

    final CupertinoTextField field = tester.widget<CupertinoTextField>(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is CupertinoTextField &&
            widget.placeholder == 'Paste timestamp, JSON, hex, base64, color…',
      ),
    );
    expect(field.controller!.text, '{"from":"shortcut"}');
    expect(inbox.intentRequests, isEmpty);
  });
}
