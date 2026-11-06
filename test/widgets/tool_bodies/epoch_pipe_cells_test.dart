import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/models/content_type.dart';
import 'package:masquerade/widgets/mq/mq_mono_cell.dart';
import 'package:masquerade/widgets/tool_bodies/cron_body.dart';
import 'package:masquerade/widgets/tool_bodies/jwt_body.dart';
import 'package:masquerade/widgets/tool_bodies/uuid_body.dart';
import 'package:masquerade/widgets/tool_bodies/x509_inspector_body.dart';

import '_helpers.dart';

Map<String, String> _epochCells(WidgetTester tester) => <String, String>{
  for (final MqMonoCell c in tester.widgetList<MqMonoCell>(
    find.byType(MqMonoCell),
  ))
    if (c.pipeType == ContentType.epoch) c.label: c.pipeValue ?? c.value,
};

void main() {
  testWidgets('JWT exp/iat/nbf drag as epoch seconds, never the token', (
    WidgetTester tester,
  ) async {
    // {"exp":1767225600,"iat":1767139200,"nbf":1767139200}
    const String token =
        'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3NjcyMjU2MDAsImlhdCI6MTc2NzEzOTIwMCwibmJmIjoxNzY3MTM5MjAwfQ.sig';
    await pumpBodyAtWidth(tester, const JwtBody(initialInput: token), 380);

    expect(_epochCells(tester), <String, String>{
      'exp': '1767225600',
      'iat': '1767139200',
      'nbf': '1767139200',
    });
    final MqMonoCell exp = tester.widget<MqMonoCell>(
      find.widgetWithText(MqMonoCell, '2026-01-01T00:00:00.000Z'),
    );
    expect(exp.value, '2026-01-01T00:00:00.000Z');
  });

  testWidgets('X.509 validity cells drag notBefore/notAfter seconds', (
    WidgetTester tester,
  ) async {
    final String pem = File('test/fixtures/x509_leaf.pem').readAsStringSync();
    await pumpBodyAtWidth(tester, X509InspectorBody(initialInput: pem), 380);

    final List<MqMonoCell> cells = tester
        .widgetList<MqMonoCell>(find.byType(MqMonoCell))
        .where((MqMonoCell c) => c.pipeType == ContentType.epoch)
        .toList();
    expect(cells.map((MqMonoCell c) => c.label), <String>[
      'Valid from',
      'Valid until',
    ]);
    for (final MqMonoCell c in cells) {
      expect(
        c.pipeValue,
        (DateTime.parse(c.value).millisecondsSinceEpoch ~/ 1000).toString(),
      );
    }
  });

  testWidgets('UUID v7 timestamp drags epoch seconds', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      const UuidBody(initialInput: '017f22e2-79b0-7cc3-98c4-dc0c0c07398f'),
      380,
    );
    expect(_epochCells(tester), <String, String>{'Timestamp': '1645557742'});
  });

  testWidgets('ULID timestamp drags epoch seconds', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      const UuidBody(initialInput: '01ARZ3NDEKTSV4RRFFQ69G5FAV'),
      380,
    );
    expect(_epochCells(tester), <String, String>{'Timestamp': '1469922850'});
  });

  testWidgets('Cron lists each next run as a draggable epoch cell', (
    WidgetTester tester,
  ) async {
    await pumpBodyAtWidth(
      tester,
      const CronBody(initialInput: '0 9 * * *'),
      380,
    );
    final List<String> values = _epochCells(tester).values.toList();
    expect(values, hasLength(5));
    for (int i = 0; i < values.length; i++) {
      final int secs = int.parse(values[i]);
      expect(secs % 60, 0);
      if (i > 0) expect(secs - int.parse(values[i - 1]), 86400);
    }
  });
}
