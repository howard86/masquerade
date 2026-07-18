import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/screens/desktop/desktop_shell.dart';
import 'package:masquerade/screens/settings_screen.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/state/share_inbox_controller.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';
import 'package:masquerade/widgets/mq/compact_paste_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _phone = Size(393, 852);
const Size _desktop = Size(1200, 900);

Future<void> _pumpMobile(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MyApp(isWebOverride: false, skipSplash: true));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('mobile tabs are functional Workbench, Library, and Activity', (
    WidgetTester tester,
  ) async {
    await _pumpMobile(tester);

    for (final String label in <String>['Workbench', 'Library', 'Activity']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.byType(CompactPasteBar), findsOneWidget);

    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
    expect(find.byType(CompactPasteBar), findsNothing);
    expect(find.text('UUID'), findsOneWidget);

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    expect(find.text('Activity'), findsWidgets);
    expect(find.text('Nothing yet'), findsOneWidget);
  });

  testWidgets('Settings is one 44-point tap from every mobile tab', (
    WidgetTester tester,
  ) async {
    await _pumpMobile(tester);

    for (final String tab in <String>['Workbench', 'Library', 'Activity']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();

      final Finder settings = find.bySemanticsLabel('Open Settings');
      expect(settings, findsOneWidget);
      final Size target = tester.getSize(settings);
      expect(target.width, greaterThanOrEqualTo(44));
      expect(target.height, greaterThanOrEqualTo(44));

      await tester.tap(settings);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('late shortcuts focus Workbench from Settings and Library', (
    WidgetTester tester,
  ) async {
    const MethodChannel channel = MethodChannel(
      ShareInboxController.channelName,
    );
    List<Object?> items = <Object?>[];
    List<Object?> intents = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          return switch (call.method) {
            'list' => items,
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
            return <String, String>{'text': '{"late":true}'};
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final ShareInboxController inbox = ShareInboxController(channel: channel);
    addTearDown(inbox.dispose);
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MyApp(
        isWebOverride: false,
        shareInboxController: inbox,
        skipSplash: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Open Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    items = <Object?>[
      <String, Object?>{
        'id': '11111111-1111-1111-1111-111111111111',
        'kind': 'text',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'byteCount': 2,
        'sensitive': false,
        'payload': '42',
      },
    ];
    await inbox.refresh();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.text('SHARED INBOX'), findsOneWidget);

    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
    await inbox.refresh();
    await tester.pumpAndSettle();
    expect(find.byType(CompactPasteBar), findsNothing);
    expect(find.text('UUID'), findsOneWidget);

    intents = <Object?>[
      <String, Object?>{
        'id': '22222222-2222-2222-2222-222222222222',
        'action': 'inspectClipboard',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
    ];
    await inbox.refreshIntents();
    await tester.pumpAndSettle();
    expect(find.byType(CompactPasteBar), findsOneWidget);
    final CupertinoTextField field = tester.widget<CupertinoTextField>(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is CupertinoTextField &&
            widget.placeholder == 'Paste timestamp, JSON, hex, base64, color…',
      ),
    );
    expect(field.controller!.text, '{"late":true}');
  });

  testWidgets('wide web keeps desktop History and Settings system windows', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(_desktop);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MyApp(
        isWebOverride: true,
        viewModeController: ViewModeController(initial: MqViewMode.desktop),
        skipSplash: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DesktopShell), findsOneWidget);
    await tester.tap(find.text('⏻ Masquerade'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings…'));
    await tester.pumpAndSettle();
    expect(find.byType(ToolCardFrame), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);

    await tester.tap(find.bySemanticsLabel('Close (Esc)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('⏻ Masquerade'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History…'));
    await tester.pumpAndSettle();
    expect(find.byType(ToolCardFrame), findsOneWidget);
    expect(find.text('History'), findsWidgets);
  });
}
