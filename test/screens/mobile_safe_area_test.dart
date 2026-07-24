import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/app.dart';
import 'package:masquerade/screens/detail/tool_detail_route.dart';
import 'package:masquerade/widgets/mq/tool_action_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _phone = Size(393, 852);

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MyApp(isWebOverride: false, skipSplash: true));
  await tester.pumpAndSettle();
}

double _tabBarTop(WidgetTester tester) =>
    tester.getTopLeft(find.byType(CupertinoTabBar)).dy;

void main() {
  testWidgets('Settings final action clears the persistent tab bar', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Open Settings'));
    await tester.pumpAndSettle();

    final Finder acknowledgements = find.text('Acknowledgements');
    await tester.scrollUntilVisible(
      acknowledgements,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(
      tester.getBottomRight(acknowledgements).dy,
      lessThanOrEqualTo(_tabBarTop(tester) - 16),
    );
  });

  testWidgets('detail action bar clears the persistent tab bar', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsLabel('Open Environment & Config Inspector'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ToolDetailRoute), findsOneWidget);
    expect(
      tester.getBottomRight(find.byType(ToolActionBar)).dy,
      lessThanOrEqualTo(_tabBarTop(tester)),
    );
  });
}
