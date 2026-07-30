import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_segmented.dart';

Widget _host(Widget child) => CupertinoApp(
  home: MqTheme(
    tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
    child: CupertinoPageScaffold(child: Center(child: child)),
  ),
);

void main() {
  testWidgets('renders the selected segment as selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        MqSegmented<int>(
          options: const <int, String>{1: 'One', 2: 'Two'},
          selected: 1,
          onChanged: (_) {},
        ),
      ),
    );

    final CupertinoSlidingSegmentedControl<int> control = tester.widget(
      find.byType(CupertinoSlidingSegmentedControl<int>),
    );

    expect(control.groupValue, 1);

    final MqColors colors = MqColors.light();
    final Text selectedLabel = tester.widget(find.text('One'));
    expect(selectedLabel.style?.color, colors.accent);
    expect(selectedLabel.style?.fontWeight, FontWeight.w600);

    final Text unselectedLabel = tester.widget(find.text('Two'));
    expect(unselectedLabel.style?.color, colors.textSec);
    expect(unselectedLabel.style?.fontWeight, FontWeight.w500);
  });

  testWidgets('full sizes to the available width, non-full hugs its content', (
    WidgetTester tester,
  ) async {
    const Map<int, String> options = <int, String>{1: 'One', 2: 'Two'};

    await tester.pumpWidget(
      _host(MqSegmented<int>(options: options, selected: 1, onChanged: (_) {})),
    );
    final double fullWidth = tester
        .getSize(find.byType(MqSegmented<int>))
        .width;

    await tester.pumpWidget(
      _host(
        MqSegmented<int>(
          options: options,
          selected: 1,
          onChanged: (_) {},
          full: false,
        ),
      ),
    );
    final double hugWidth = tester.getSize(find.byType(MqSegmented<int>)).width;

    expect(
      fullWidth,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );
    expect(hugWidth, lessThan(fullWidth));
  });

  testWidgets('tapping an unselected segment calls onChanged with its value', (
    WidgetTester tester,
  ) async {
    int? changedTo;

    await tester.pumpWidget(
      _host(
        MqSegmented<int>(
          options: const <int, String>{1: 'One', 2: 'Two'},
          selected: 1,
          onChanged: (int value) => changedTo = value,
        ),
      ),
    );

    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();

    expect(changedTo, 2);
  });

  testWidgets(
    'exposes selected-state semantics for the selected segment only',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _host(
          MqSegmented<int>(
            options: const <int, String>{1: 'One', 2: 'Two'},
            selected: 1,
            onChanged: (_) {},
          ),
        ),
      );

      final SemanticsNode selected = tester.getSemantics(find.text('One'));
      final SemanticsNode unselected = tester.getSemantics(find.text('Two'));

      expect(selected.flagsCollection.isSelected, Tristate.isTrue);
      expect(unselected.flagsCollection.isSelected, Tristate.isFalse);

      handle.dispose();
    },
  );
}
