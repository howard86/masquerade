import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/app.dart';

void main() {
  testWidgets('app renders two-tab scaffold', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(CupertinoTabBar), findsOneWidget);
    // Labels appear in both the tab bar and the page title
    expect(find.text('Tools'), findsWidgets);
    expect(find.text('Converter'), findsWidgets);
  });
}
