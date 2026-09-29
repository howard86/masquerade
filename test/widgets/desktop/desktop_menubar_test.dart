import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/models/artifact.dart';
import 'package:masquerade/screens/desktop/desktop_shell.dart';
import 'package:masquerade/state/detection_preference_controller.dart';
import 'package:masquerade/state/view_mode_controller.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/desktop/desktop_icon_grid.dart';
import 'package:masquerade/widgets/desktop/desktop_menubar.dart';
import 'package:masquerade/widgets/desktop/tool_card_frame.dart';
import 'package:masquerade/widgets/iphone_frame.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _desktop = Size(1200, 900);

String _timeLabel(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

Future<void> _pump(
  WidgetTester tester, {
  DetectionPreferenceController? detectionPreferenceController,
}) async {
  await tester.binding.setSurfaceSize(_desktop);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MyApp(
      desktopShellOverride: true,
      viewModeController: ViewModeController(initial: MqViewMode.desktop),
      skipSplash: true,
      detectionPreferenceController: detectionPreferenceController,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('DesktopMenubar', () {
    testWidgets('Close All clears open cards', (WidgetTester tester) async {
      await _pump(tester);
      // Open a card first via icon tile.
      final String firstName = UtilityCatalog.all.first.name;
      await tester.tap(find.text(firstName));
      await tester.pumpAndSettle();
      expect(find.byType(ToolCardFrame), findsOneWidget);

      // File → Close All.
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();

      // Menu items are labelled Semantics buttons, not bare tap regions.
      final SemanticsHandle handle = tester.ensureSemantics();
      final SemanticsData closeAllData = tester
          .getSemantics(find.bySemanticsLabel('Close All').last)
          .getSemanticsData();
      expect(closeAllData.flagsCollection.isButton, isTrue);
      expect(closeAllData.hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();

      await tester.tap(find.text('Close All').last);
      await tester.pumpAndSettle();
      expect(find.byType(ToolCardFrame), findsNothing);
      expect(find.byType(DesktopIconGrid), findsOneWidget);
    });

    testWidgets('Paste & Detect honors a saved type preference', (
      WidgetTester tester,
    ) async {
      final TestDefaultBinaryMessenger messenger =
          tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async => call.method == 'Clipboard.getData'
            ? <String, Object>{'text': '1700000000'}
            : null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final DetectionPreferenceController preferences =
          DetectionPreferenceController();
      await preferences.prefer(
        UtilityCatalog.detectArtifacts('1700000000'),
        ArtifactKind.number,
      );
      await _pump(tester, detectionPreferenceController: preferences);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste & Detect  ⌘V'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<ToolCardFrame>(find.byType(ToolCardFrame)).title,
        'Number Base',
      );
    });

    testWidgets('Paste & Detect opens the highest-ranked interpretation', (
      WidgetTester tester,
    ) async {
      final TestDefaultBinaryMessenger messenger =
          tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (
        MethodCall call,
      ) async {
        if (call.method == 'Clipboard.getData') {
          return <String, Object>{'text': '1700000000'};
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await _pump(tester);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste & Detect  ⌘V'));
      await tester.pumpAndSettle();

      expect(find.byType(ToolCardFrame), findsOneWidget);
      expect(find.text('Timestamp'), findsWidgets);
      expect(find.text('Number Base'), findsOneWidget);
    });

    testWidgets('Mobile view fires the view-mode change', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      expect(find.byType(DesktopShell), findsOneWidget);

      await tester.tap(find.text('⏻ Masquerade'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobile view'));
      await tester.pumpAndSettle();
      expect(find.byType(IphoneFrame), findsOneWidget);
      expect(find.byType(DesktopShell), findsNothing);
    });

    testWidgets('⏻ → History… opens a History window', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.text('⏻ Masquerade'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History…'));
      await tester.pumpAndSettle();
      // History opens as a first-class window with traffic lights.
      expect(find.byType(ToolCardFrame), findsOneWidget);
      expect(find.text('History'), findsWidgets);
    });

    testWidgets('displays a live clock', (WidgetTester tester) async {
      final DateTime beforePump = DateTime.now();
      await _pump(tester);
      final Set<String> expected = <String>{
        _timeLabel(beforePump),
        _timeLabel(DateTime.now()),
      };
      expect(
        find.byWidgetPredicate(
          (Widget widget) => widget is Text && expected.contains(widget.data),
        ),
        findsOneWidget,
      );
    });

    testWidgets('dropdown dismiss barrier excludes itself from semantics', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();

      // The full-viewport tap-to-dismiss barrier behind the dropdown must
      // not surface as an unlabelled tappable node to assistive tech; the
      // menu items are individually labelled Semantics buttons instead.
      final GestureDetector barrier = tester
          .widgetList<GestureDetector>(find.byType(GestureDetector))
          .firstWhere(
            (GestureDetector d) =>
                d.child is SizedBox &&
                (d.child! as SizedBox).width == double.infinity,
          );
      expect(barrier.excludeFromSemantics, isTrue);

      // Dismiss still works: tap the barrier and the dropdown closes.
      await tester.tapAt(const Offset(10, 500));
      await tester.pumpAndSettle();
      expect(find.text('Close All'), findsNothing);
    });
  });

  group('MenubarClock', () {
    late DateTime now;

    Future<Map<String, int>> pumpClock(WidgetTester tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: MqTheme(
            tokens: MqTokens(
              colors: MqColors.light(),
              brightness: Brightness.light,
            ),
            child: Center(child: MenubarClock(now: () => now)),
          ),
        ),
      );
      final Map<String, int> builds = <String, int>{};
      debugOnRebuildDirtyWidget = (Element e, bool _) {
        final String name = e.widget.runtimeType.toString();
        builds[name] = (builds[name] ?? 0) + 1;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = null);
      return builds;
    }

    Future<void> advance(WidgetTester tester, Duration d) async {
      now = now.add(d);
      await tester.pump(d);
    }

    testWidgets('ticks once per minute boundary, only when the text changes', (
      WidgetTester tester,
    ) async {
      now = DateTime(2026, 9, 29, 9, 58, 30);
      final Map<String, int> builds = await pumpClock(tester);
      expect(find.text('09:58'), findsOneWidget);

      await advance(tester, const Duration(seconds: 29));
      expect(builds['MenubarClock'], isNull); // no poll inside the minute

      await advance(tester, const Duration(seconds: 1));
      expect(find.text('09:59'), findsOneWidget);
      expect(builds['MenubarClock'], 1);

      // A simulated hour: exactly one rebuild per minute.
      for (int i = 0; i < 60; i++) {
        await advance(tester, const Duration(seconds: 30));
        await advance(tester, const Duration(seconds: 30));
      }
      expect(builds['MenubarClock'], 61);
      expect(find.text('10:59'), findsOneWidget);
    });

    testWidgets('stops while hidden and catches up on resume', (
      WidgetTester tester,
    ) async {
      now = DateTime(2026, 9, 29, 12, 0, 0);
      final Map<String, int> builds = await pumpClock(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      for (int i = 0; i < 10; i++) {
        await advance(tester, const Duration(minutes: 1));
      }
      expect(builds['MenubarClock'], isNull);
      expect(find.text('12:00'), findsOneWidget);

      for (final AppLifecycleState state in <AppLifecycleState>[
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      expect(find.text('12:10'), findsOneWidget);
      expect(builds['MenubarClock'], 1);
    });
  });
}
