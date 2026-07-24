import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_button.dart';
import 'package:masquerade/widgets/mq/tool_action_bar.dart';

void main() {
  setUpAll(() async {
    final FontLoader loader = FontLoader('IBMPlexSans')
      ..addFont(rootBundle.load('assets/fonts/IBMPlexSans-VF.ttf'));
    await loader.load();
  });

  testWidgets('phone action labels render without truncation', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ToolActionBarController controller = ToolActionBarController()
      ..bind(
        onPaste: () {},
        onClear: () {},
        center: MqButton(label: 'Copy all', onPressed: () {}, full: true),
      );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: MqTheme(
          tokens: MqTokens(
            colors: MqColors.light(),
            brightness: Brightness.light,
          ),
          child: CupertinoPageScaffold(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ToolActionBar(controller: controller),
            ),
          ),
        ),
      ),
    );

    for (final String label in <String>['Paste', 'Copy all', 'Clear']) {
      final RenderParagraph paragraph = tester.renderObject(find.text(label));
      expect(
        paragraph.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(paragraph.size.width),
        reason: '$label should fit at phone width',
      );
    }
    expect(tester.takeException(), isNull);
  });
}
