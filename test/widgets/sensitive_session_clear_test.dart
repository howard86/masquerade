import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/state/canvas_controller.dart';
import 'package:masquerade/state/share_inbox_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  testWidgets('Clear sensitive session now resets live tool input', (
    WidgetTester tester,
  ) async {
    const MethodChannel inboxChannel = MethodChannel(
      ShareInboxController.channelName,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          inboxChannel,
          (MethodCall call) async => null,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(inboxChannel, null),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      CanvasController.currentKey: '{"raw":"persisted-fixture"}',
    });
    await tester.binding.setSurfaceSize(kHomeSurfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp(skipSplash: true));
    await tester.pumpAndSettle();

    final Finder hero = find.byWidgetPredicate(
      (Widget widget) =>
          widget is CupertinoTextField &&
          widget.placeholder == 'Paste timestamp, JSON, hex, base64, color…',
    );
    await tester.enterText(hero, '{"password":"live-credential-fixture"}');
    await tester.tap(find.bySemanticsLabel('Open Settings'));
    await tester.pumpAndSettle();
    final Finder clear = find.text('Clear sensitive session now');
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear now'));
    await tester.pumpAndSettle();

    final Finder resetHeroFinder = find.byWidgetPredicate(
      (Widget widget) =>
          widget is CupertinoTextField &&
          widget.placeholder == 'Paste timestamp, JSON, hex, base64, color…',
      skipOffstage: false,
    );
    final CupertinoTextField resetHero = tester.widget<CupertinoTextField>(
      resetHeroFinder,
    );
    expect(resetHero.controller!.text, isEmpty);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(CanvasController.currentKey), isNull);
  });
}
