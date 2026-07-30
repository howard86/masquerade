import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_metrics.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_surface.dart';

final MqColors _colors = MqColors.light();

Widget _host(Widget child) => CupertinoApp(
  home: MqTheme(
    tokens: MqTokens(colors: _colors, brightness: Brightness.light),
    child: CupertinoPageScaffold(child: Center(child: child)),
  ),
);

BoxDecoration _decorationOf(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(MqSurface),
      matching: find.byType(DecoratedBox),
    ),
  );
  return box.decoration as BoxDecoration;
}

EdgeInsetsGeometry? _paddingOf(WidgetTester tester) {
  final Padding padding = tester.widget<Padding>(
    find.descendant(of: find.byType(MqSurface), matching: find.byType(Padding)),
  );
  return padding.padding;
}

void main() {
  testWidgets(
    'defaults paint the surface token, hairline border and no shadow',
    (WidgetTester tester) async {
      await tester.pumpWidget(_host(const MqSurface(child: Text('body'))));

      final BoxDecoration decoration = _decorationOf(tester);
      expect(decoration.color, _colors.surface);
      expect(decoration.border, Border.all(color: _colors.border, width: 0.5));
      expect(decoration.borderRadius, BorderRadius.circular(MqRadius.md));
      expect(decoration.boxShadow, isNull);
    },
  );

  testWidgets('padded defaults to MqSpacing.lg on every side', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const MqSurface(child: Text('body'))));

    expect(_paddingOf(tester), const EdgeInsets.all(MqSpacing.lg));
  });

  testWidgets('padded: false collapses the padding to zero', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(const MqSurface(padded: false, child: Text('body'))),
    );

    expect(_paddingOf(tester), EdgeInsets.zero);
  });

  testWidgets('an explicit padding wins over padded: true', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const MqSurface(
          padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: Text('body'),
        ),
      ),
    );

    expect(
      _paddingOf(tester),
      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    );
  });

  testWidgets('an explicit padding wins over padded: false', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const MqSurface(
          padded: false,
          padding: EdgeInsets.all(11),
          child: Text('body'),
        ),
      ),
    );

    expect(_paddingOf(tester), const EdgeInsets.all(11));
  });

  testWidgets('floating: true attaches the large shadow token', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(const MqSurface(floating: true, child: Text('body'))),
    );

    expect(_decorationOf(tester).boxShadow, _colors.shadowLg);
    expect(_decorationOf(tester).boxShadow, isNotNull);
  });

  testWidgets('explicit background and borderColor override the theme tokens', (
    WidgetTester tester,
  ) async {
    const Color background = Color(0xFF102030);
    const Color borderColor = Color(0xFF405060);

    await tester.pumpWidget(
      _host(
        const MqSurface(
          background: background,
          borderColor: borderColor,
          child: Text('body'),
        ),
      ),
    );

    final BoxDecoration decoration = _decorationOf(tester);
    expect(decoration.color, background);
    expect(decoration.color, isNot(_colors.surface));
    expect(decoration.border, Border.all(color: borderColor, width: 0.5));
    expect(
      decoration.border,
      isNot(Border.all(color: _colors.border, width: 0.5)),
    );
  });

  testWidgets('an explicit radius replaces MqRadius.md', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(const MqSurface(radius: 24, child: Text('body'))),
    );

    expect(_decorationOf(tester).borderRadius, BorderRadius.circular(24));
  });
}
