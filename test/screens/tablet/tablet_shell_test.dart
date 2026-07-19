import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';
import 'package:masquerade/screens/tablet/tablet_shell.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/iphone_frame.dart';
import 'package:masquerade/widgets/mq/mq_search_bar.dart';
import 'package:masquerade/widgets/tool_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

// iPad Pro 12.9" portrait, logical px. Both dimensions clear the tablet
// breakpoint. The shell resolves via LayoutBuilder constraints, which
// `setSurfaceSize` drives (MediaQuery.size alone would not honor it).
const Size _ipad = Size(1024, 1366);

Future<void> _pumpTablet(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_ipad);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MyApp(isWebOverride: false, skipSplash: true));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('native iPad renders the split-view shell — sidebar + detail, '
      'no tab bar, no iPhone frame', (WidgetTester tester) async {
    await _pumpTablet(tester);

    expect(find.byType(TabletShell), findsOneWidget);
    expect(find.byType(MqSearchBar), findsOneWidget); // the sidebar search
    expect(find.byType(CupertinoTabBar), findsNothing);
    expect(find.byType(IphoneFrame), findsNothing);
  });

  testWidgets('selecting a sidebar tool renders its body in the detail pane', (
    WidgetTester tester,
  ) async {
    await _pumpTablet(tester);

    // First run: browse empty state, nothing hosted yet.
    expect(find.byType(ToolHost), findsNothing);

    // The tool name appears in both the sidebar (first in the Row) and the
    // browse grid; the first match is the sidebar row.
    final String toolName = UtilityCatalog.all.first.name;
    await tester.tap(find.text(toolName).first);
    await tester.pumpAndSettle();

    expect(find.byType(ToolHost), findsOneWidget);
  });
}
