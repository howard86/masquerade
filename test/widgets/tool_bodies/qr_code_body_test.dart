import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/link_group.dart';
import 'package:masquerade/widgets/tool_bodies/qr_code_body.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'QR Code — generate mode renders QrImageView for non-empty text',
    (WidgetTester tester) async {
      await pumpHomeAndOpen(tester, 'QR Code');

      expect(find.byType(QrImageView), findsNothing);

      await tester.enterText(
        find.byType(EditableText).last,
        'https://example.com',
      );
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsOneWidget);
    },
  );

  testWidgets('QR Code — empty input shows hint instead of QR', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'QR Code');

    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('Type text or a URL'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
  });

  testWidgets('QR Code — Clear appears with input and clears it', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'QR Code');
    final Finder input = find.byType(EditableText).last;

    await tester.enterText(input, 'https://example.com');
    await tester.pumpAndSettle();

    expect(find.text('Clear'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(tester.widget<EditableText>(input).controller.text, isEmpty);
    expect(find.text('Clear'), findsNothing);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('QR Code — switching to Scan mode reveals Scan QR action', (
    WidgetTester tester,
  ) async {
    await pumpHomeAndOpen(tester, 'QR Code');

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.textContaining('Tap Scan QR'), findsOneWidget);
  });

  testWidgets('linked text fills generate content, even from scan mode', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<String> inbound = ValueNotifier<String>('');
    final List<String> emitted = <String>[];
    final LinkChannel channel = LinkChannel(
      canonicalType: ContentType.text,
      inbound: inbound,
      seedOnAttach: false,
      role: () => LinkRole.receive,
      onEmit: emitted.add,
    );
    await pumpBodyAtWidth(tester, QrCodeBody(link: channel), 340);
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    expect(find.text('Scan QR'), findsOneWidget);

    inbound.value = 'https://linked.example';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Scan QR'), findsNothing);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).last)
          .controller
          .text,
      'https://linked.example',
    );
    await tester.enterText(find.byType(EditableText).last, 'local');
    await tester.pump(const Duration(milliseconds: 300));
    expect(emitted, isEmpty);
  });
}
