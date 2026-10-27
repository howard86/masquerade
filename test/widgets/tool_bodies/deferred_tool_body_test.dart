import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/tool_bodies/deferred_tool_body.dart';
import 'package:masquerade/widgets/tool_bodies/seed_source.dart';
import 'package:masquerade/widgets/tool_bodies/uuid_body.dart';

void main() {
  test('the shared test config preloads the deferred bodies', () {
    expect(toolBodiesLoaded, isTrue);
  });

  test('every ToolBodyKind backs exactly one catalog entry', () {
    expect(UtilityCatalog.all, hasLength(ToolBodyKind.values.length));
  });

  testWidgets('a loaded catalog builder renders its body on the first frame '
      'with the builder arguments', (WidgetTester tester) async {
    final UtilityDescriptor uuid = UtilityCatalog.all.firstWhere(
      (UtilityDescriptor u) => u.id == 'uuid',
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: MqTheme(
          tokens: MqTokens(
            colors: MqColors.light(),
            brightness: Brightness.light,
          ),
          child: HistoryScope(
            controller: HistoryController(),
            child: CupertinoPageScaffold(
              child: SingleChildScrollView(
                child: Builder(
                  builder: (BuildContext context) => uuid.builder(
                    context,
                    initialInput: 'abc',
                    seedSource: SeedSource.paste,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('deferred-tool-body-placeholder')),
      findsNothing,
    );
    final UuidBody body = tester.widget<UuidBody>(find.byType(UuidBody));
    expect(body.initialInput, 'abc');
    expect(body.seedSource, SeedSource.paste);
    await tester.pump(const Duration(seconds: 1));
  });
}
