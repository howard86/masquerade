import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/tool_bodies/qr_code_body.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

QrImageView _qr(WidgetTester tester) =>
    tester.widget<QrImageView>(find.byType(QrImageView));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> enter(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(EditableText).last, text);
    await tester.pumpAndSettle(kDebouncePump);
  }

  testWidgets('QR — ECC/size controls hidden at phone width (mobile parity)', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const QrCodeBody(), 340);
    await enter(tester, 'https://example.com');

    expect(find.text('ERROR CORRECTION'), findsNothing);
    expect(find.text('SIZE'), findsNothing);
    // The fixed mobile preview is 240 logical px.
    expect(_qr(tester).size, 240);
  });

  testWidgets('QR — ECC/size controls visible at wide width', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const QrCodeBody(), 640);
    await enter(tester, 'https://example.com');

    expect(find.text('ERROR CORRECTION'), findsOneWidget);
    expect(find.text('SIZE'), findsOneWidget);
    // Default wide size is Medium = 240; bumping to Large grows the preview.
    expect(_qr(tester).size, 240);
    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();
    expect(_qr(tester).size, 320);
  });

  testWidgets('QR — error-correction control raises the rendered level', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(tester, const QrCodeBody(), 640);
    await enter(tester, 'https://example.com');

    // Default is L; selecting H re-renders the QR at the higher level.
    expect(_qr(tester).errorCorrectionLevel, QrErrorCorrectLevel.L);
    await tester.tap(find.text('H'));
    await tester.pumpAndSettle();
    expect(_qr(tester).errorCorrectionLevel, QrErrorCorrectLevel.H);
  });
}
