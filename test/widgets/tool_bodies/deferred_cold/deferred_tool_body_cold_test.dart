import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/tool_bodies/bps_body.dart';
import 'package:masquerade/widgets/tool_bodies/deferred_tool_body.dart';

Widget _host(Widget child) => CupertinoApp(
  home: MqTheme(
    tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
    child: HistoryScope(
      controller: HistoryController(),
      child: CupertinoPageScaffold(child: SingleChildScrollView(child: child)),
    ),
  ),
);

void main() {
  testWidgets('shows a placeholder until the bodies load, then swaps in', (
    WidgetTester tester,
  ) async {
    expect(toolBodiesLoaded, isFalse);
    final UtilityDescriptor bps = UtilityCatalog.all.firstWhere(
      (UtilityDescriptor u) => u.id == 'bps',
    );
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (BuildContext context) =>
              bps.builder(context, initialInput: '25'),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('deferred-tool-body-placeholder')),
      findsOneWidget,
    );
    expect(find.byType(BpsBody), findsNothing);

    // The load started inside the fake-async zone; let the real event loop
    // deliver it, then flush the zone's continuations with a pump.
    for (int i = 0; i < 100 && !toolBodiesLoaded; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pump();

    expect(toolBodiesLoaded, isTrue);
    expect(
      find.byKey(const ValueKey<String>('deferred-tool-body-placeholder')),
      findsNothing,
    );
    final BpsBody body = tester.widget<BpsBody>(find.byType(BpsBody));
    expect(body.initialInput, '25');
    await tester.pump(const Duration(seconds: 1));
  }, timeout: const Timeout(Duration(seconds: 60)));
}
