import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

String _assetOf(WidgetTester tester) {
  final SvgPicture svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
  return (svg.bytesLoader as SvgAssetLoader).assetName;
}

void main() {
  group('MqMonogram', () {
    testWidgets('loads the light SVG under light brightness', (tester) async {
      await tester.pumpWidget(_host(Brightness.light, const MqMonogram()));
      expect(_assetOf(tester), 'assets/brand/monogram-light.svg');
    });

    testWidgets('loads the dark SVG under dark brightness', (tester) async {
      await tester.pumpWidget(_host(Brightness.dark, const MqMonogram()));
      expect(_assetOf(tester), 'assets/brand/monogram-dark.svg');
    });

    testWidgets('applies the requested size to the picture', (tester) async {
      await tester.pumpWidget(
        _host(Brightness.light, const MqMonogram(size: 64)),
      );
      final SvgPicture svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svg.width, 64);
      expect(svg.height, 64);
    });
  });
}
