import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masquerade/utility_catalog.dart';
import 'package:masquerade/widgets/mq/inline_tool_card.dart';

import '_helpers.dart';

InlineToolCard _cardFor(WidgetTester tester, String utilityId) {
  final UtilityDescriptor u = UtilityCatalog.byId(utilityId);
  return tester
      .widgetList<InlineToolCard>(find.byType(InlineToolCard))
      .firstWhere((InlineToolCard c) => c.descriptor.id == u.id);
}

void _interceptClipboard(WidgetTester tester, List<String> writes) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        final Map<dynamic, dynamic> args = call.arguments as Map;
        writes.add(args['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

void main() {
  testWidgets('grid chip shows last input preview, truncated to 24 chars', (
    WidgetTester tester,
  ) async {
    const String long = 'abcdefghijklmnopqrstuvwxyz0123456789';
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mb.history.entries': encodeHistoryEntries(<Map<String, Object>>[
        historyEntry(utilityId: 'base64', input: long, output: 'base64-out'),
      ]),
    });
    await pumpHomeWithLoadedHistory(tester);

    final InlineToolCard card = _cardFor(tester, 'base64');
    expect(card.previewText, '${long.substring(0, 24)}…');
    expect(card.previewSensitive, isFalse);
  });

  testWidgets('grid chip masks sensitive entry with bullets', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mb.history.entries': encodeHistoryEntries(<Map<String, Object>>[
        historyEntry(
          utilityId: 'base64',
          input: 'super-secret-token',
          output: 'masked',
          sensitive: true,
        ),
      ]),
    });
    await pumpHomeWithLoadedHistory(tester);

    final InlineToolCard card = _cardFor(tester, 'base64');
    expect(card.previewSensitive, isTrue);
    expect(find.text('super-secret-token'), findsNothing);
    expect(find.text('••••'), findsOneWidget);
  });

  testWidgets('long-press on a grid chip with history shows copy toast', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mb.history.entries': encodeHistoryEntries(<Map<String, Object>>[
        historyEntry(utilityId: 'base64', input: 'plain', output: 'aGVsbG8='),
      ]),
    });

    final List<String> clipboardWrites = <String>[];
    _interceptClipboard(tester, clipboardWrites);

    await pumpHomeWithLoadedHistory(tester);

    // The grid chip is rendered after the Recents row; the Recents chip has
    // no long-press handler, so `.last` is required to hit the grid target.
    await tester.longPress(find.text('Base64').last);
    await tester.pumpAndSettle();

    expect(clipboardWrites, contains('aGVsbG8='));
    expect(find.text('Copied to clipboard'), findsOneWidget);

    // Drain toast auto-dismiss timer.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('long-press without history is a no-op', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final List<String> clipboardWrites = <String>[];
    _interceptClipboard(tester, clipboardWrites);

    await pumpHomeWithLoadedHistory(tester);

    await tester.longPress(find.text('Base64').last);
    await tester.pumpAndSettle();

    expect(clipboardWrites, isEmpty);
    expect(find.text('Copied to clipboard'), findsNothing);
  });

  testWidgets('long-press on sensitive entry is a no-op', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mb.history.entries': encodeHistoryEntries(<Map<String, Object>>[
        historyEntry(
          utilityId: 'base64',
          input: 'secret',
          output: 'sensitive-output',
          sensitive: true,
        ),
      ]),
    });

    final List<String> clipboardWrites = <String>[];
    _interceptClipboard(tester, clipboardWrites);

    await pumpHomeWithLoadedHistory(tester);

    await tester.longPress(find.text('Base64').last);
    await tester.pumpAndSettle();

    expect(clipboardWrites, isEmpty);
    expect(find.text('Copied to clipboard'), findsNothing);
  });
}
