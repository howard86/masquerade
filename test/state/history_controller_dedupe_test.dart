import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  HistoryEntry entry(String utilityId, String input, {String? output}) =>
      HistoryEntry(
        utilityId: utilityId,
        input: input,
        output: output ?? input.toUpperCase(),
        timestamp: DateTime.now(),
      );

  group('HistoryController.add dedupe', () {
    test('skips when most recent entry has same utilityId and input', () async {
      final HistoryController c = HistoryController();
      await c.add(entry('base64', 'hello'));
      await c.add(entry('base64', 'hello'));
      expect(c.entries.length, 1);
      expect(c.entries.first.input, 'hello');
    });

    test('only the most recent is checked — A, B, A keeps all three', () async {
      final HistoryController c = HistoryController();
      await c.add(entry('base64', 'a'));
      await c.add(entry('base64', 'b'));
      await c.add(entry('base64', 'a'));
      expect(c.entries.length, 3);
      expect(c.entries[0].input, 'a');
      expect(c.entries[1].input, 'b');
      expect(c.entries[2].input, 'a');
    });

    test('different utilityId with same input does not dedupe', () async {
      final HistoryController c = HistoryController();
      await c.add(entry('base64', 'hello'));
      await c.add(entry('json', 'hello'));
      expect(c.entries.length, 2);
      expect(c.entries.first.utilityId, 'json');
    });

    test('output is not part of the dedupe key', () async {
      final HistoryController c = HistoryController();
      await c.add(entry('base64', 'hello', output: 'aGVsbG8='));
      await c.add(entry('base64', 'hello', output: 'different'));
      expect(c.entries.length, 1);
    });
  });
}
