import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_monogram.dart';

Widget _host(Brightness brightness, Widget child) => CupertinoApp(
  home: MqTheme(
    tokens: MqTokens(
      colors: brightness == Brightness.dark
          ? MqColors.dark()
          : MqColors.light(),
      brightness: brightness,
    ),
    child: CupertinoPageScaffold(child: child),
  ),
);

CustomPainter _painterOf(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.descendant(
        of: find.byType(MqMonogram),
        matching: find.byType(CustomPaint),
      ),
    )
    .painter!;

void main() {
  group('MqMonogram', () {
    testWidgets('repaints when brightness flips', (tester) async {
      await tester.pumpWidget(_host(Brightness.light, const MqMonogram()));
      final CustomPainter light = _painterOf(tester);
      await tester.pumpWidget(_host(Brightness.dark, const MqMonogram()));
      final CustomPainter dark = _painterOf(tester);
      expect(dark.shouldRepaint(light), isTrue);
      expect(dark.shouldRepaint(_painterOf(tester)), isFalse);
    });

    testWidgets('applies the requested size', (tester) async {
      await tester.pumpWidget(
        _host(Brightness.light, const MqMonogram(size: 64)),
      );
      expect(tester.getSize(find.byType(MqMonogram)), const Size(64, 64));
    });

    testWidgets('paints without throwing in both themes', (tester) async {
      for (final Brightness b in Brightness.values) {
        await tester.pumpWidget(_host(b, const MqMonogram()));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
