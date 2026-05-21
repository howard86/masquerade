import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/theme/mq_colors.dart';
import 'package:masquerade/theme/mq_theme.dart';
import 'package:masquerade/widgets/mq/mq_dropdown.dart';

enum _F { a, b, c }

Widget _host(Widget child) => CupertinoApp(
  home: MqTheme(
    tokens: MqTokens(colors: MqColors.light(), brightness: Brightness.light),
    child: CupertinoPageScaffold(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  group('MqDropdown', () {
    testWidgets('renders label and selected option', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          MqDropdown<_F>(
            label: 'Format',
            selected: _F.b,
            options: const <_F, String>{
              _F.a: 'Alpha',
              _F.b: 'Beta',
              _F.c: 'Gamma',
            },
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('FORMAT'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('tapping opens action sheet with options', (
      WidgetTester tester,
    ) async {
      _F? picked;
      await tester.pumpWidget(
        _host(
          MqDropdown<_F>(
            label: 'Format',
            selected: _F.a,
            options: const <_F, String>{
              _F.a: 'Alpha',
              _F.b: 'Beta',
              _F.c: 'Gamma',
            },
            onChanged: (_F v) => picked = v,
          ),
        ),
      );

      await tester.tap(find.byType(CupertinoButton).first);
      await tester.pumpAndSettle();

      // All three options visible in the action sheet.
      expect(find.text('Alpha'), findsWidgets);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);

      await tester.tap(find.text('Gamma'));
      await tester.pumpAndSettle();

      expect(picked, _F.c);
    });

    testWidgets('disabled state suppresses picker', (
      WidgetTester tester,
    ) async {
      bool fired = false;
      await tester.pumpWidget(
        _host(
          MqDropdown<_F>(
            label: 'Format',
            selected: _F.a,
            options: const <_F, String>{_F.a: 'Alpha', _F.b: 'Beta'},
            onChanged: (_) => fired = true,
            enabled: false,
          ),
        ),
      );

      await tester.tap(find.byType(CupertinoButton).first);
      await tester.pumpAndSettle();

      // Action sheet did not open — no extra "Alpha" rendered.
      expect(find.text('Alpha'), findsOneWidget);
      expect(fired, isFalse);
    });

    testWidgets('selecting the same option does not fire onChanged', (
      WidgetTester tester,
    ) async {
      int firedCount = 0;
      await tester.pumpWidget(
        _host(
          MqDropdown<_F>(
            label: 'Format',
            selected: _F.a,
            options: const <_F, String>{_F.a: 'Alpha', _F.b: 'Beta'},
            onChanged: (_) => firedCount++,
          ),
        ),
      );

      await tester.tap(find.byType(CupertinoButton).first);
      await tester.pumpAndSettle();
      // Tap the already-selected option.
      await tester.tap(find.text('Alpha').last);
      await tester.pumpAndSettle();

      expect(firedCount, 0);
    });
  });
}
