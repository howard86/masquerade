import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/widgets/tool_bodies/base64_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

/// Base64 of a 1×1 transparent PNG (starts with the PNG magic 89 50 4E 47).
const String _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> decode(WidgetTester tester, double width) async {
    await pumpBodyAtWidth(tester, const Base64Body(), width);
    await tester.tap(find.text('Decode'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, _png1x1);
    await tester.pumpAndSettle(kDebouncePump);
  }

  testWidgets('Base64 — image preview + byte delta hidden at phone width', (
    WidgetTester tester,
  ) async {
    await decode(tester, 340);

    // Mobile parity: no image preview, no byte-delta readout.
    expect(find.byType(Image), findsNothing);
    expect(find.text('Byte delta'), findsNothing);
  });

  testWidgets('Base64 — image preview + byte delta visible at wide width', (
    WidgetTester tester,
  ) async {
    await decode(tester, 640);

    // PNG sniffed → preview renders, labelled, with a byte-delta readout.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('PNG image'), findsOneWidget);
    expect(find.text('Byte delta'), findsOneWidget);
  });
}
