import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/link_group.dart';
import 'package:masquerade/widgets/tool_bodies/base64_body.dart';
import 'package:masquerade/widgets/tool_bodies/bytes_body.dart';
import 'package:masquerade/widgets/tool_bodies/csv_body.dart';
import 'package:masquerade/widgets/tool_bodies/json_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

/// Pumps [build] linked as a non-seeding member of a [type] group whose
/// canonical starts at [initial]; returns the group notifier and the emits.
Future<(ValueNotifier<String>, List<String>)> _pump(
  WidgetTester tester,
  ContentType type,
  String initial,
  Widget Function(LinkChannel) build,
) async {
  final ValueNotifier<String> inbound = ValueNotifier<String>(initial);
  final List<String> emitted = <String>[];
  await pumpBodyAtWidth(
    tester,
    build(
      LinkChannel(
        canonicalType: type,
        inbound: inbound,
        seedOnAttach: false,
        onEmit: (String v) {
          emitted.add(v);
          inbound.value = v;
        },
      ),
    ),
    480,
  );
  await tester.pumpAndSettle(kDebouncePump);
  return (inbound, emitted);
}

String _input(WidgetTester tester) => tester
    .widget<EditableText>(find.byType(EditableText).first)
    .controller
    .text;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Base64 bytes link: base64 <-> hex', (WidgetTester tester) async {
    final (ValueNotifier<String> group, List<String> emitted) = await _pump(
      tester,
      ContentType.bytes,
      '4869',
      (LinkChannel l) => Base64Body(link: l),
    );
    expect(_input(tester), 'SGk=');

    await tester.enterText(find.byType(EditableText).first, 'SGVsbG8=');
    await tester.pumpAndSettle(kDebouncePump);
    expect(emitted.last, '48656c6c6f');
    expect(group.value, '48656c6c6f');
  });

  testWidgets('Bytes bytes link: decimal array <-> hex', (
    WidgetTester tester,
  ) async {
    final (ValueNotifier<String> group, List<String> emitted) = await _pump(
      tester,
      ContentType.bytes,
      '4869',
      (LinkChannel l) => BytesBody(link: l),
    );
    expect(_input(tester), '72 105');

    await tester.enterText(find.byType(EditableText).first, '1 255');
    await tester.pumpAndSettle(kDebouncePump);
    expect(emitted.last, '01ff');
    expect(group.value, '01ff');
  });

  testWidgets('Bytes text link: decimal array <-> text', (
    WidgetTester tester,
  ) async {
    final (_, List<String> emitted) = await _pump(
      tester,
      ContentType.text,
      'Hi',
      (LinkChannel l) => BytesBody(link: l),
    );
    expect(_input(tester), '72 105');

    await tester.enterText(find.byType(EditableText).first, '79 75');
    await tester.pumpAndSettle(kDebouncePump);
    expect(emitted.last, 'OK');
  });

  testWidgets('JSON json link: pretty input <-> compact canonical', (
    WidgetTester tester,
  ) async {
    final (_, List<String> emitted) = await _pump(
      tester,
      ContentType.json,
      '{"a":[1,2]}',
      (LinkChannel l) => JSONBody(link: l),
    );
    expect(_input(tester), contains('\n'));

    await tester.enterText(find.byType(EditableText).first, '{\n  "b": 1\n}');
    await tester.pumpAndSettle(kDebouncePump);
    expect(emitted.last, '{"b":1}');
  });

  testWidgets('CSV json link: JSON array <-> CSV', (WidgetTester tester) async {
    final (_, List<String> emitted) = await _pump(
      tester,
      ContentType.json,
      '[{"name":"Ada","lang":"Dart"}]',
      (LinkChannel l) => CsvBody(link: l),
    );
    expect(_input(tester).trim(), 'name,lang\r\nAda,Dart');

    await tester.enterText(find.byType(EditableText).first, 'x,y\n1,2');
    await tester.pumpAndSettle(kDebouncePump);
    expect(emitted.last, '[{"x":"1","y":"2"}]');
  });
}
