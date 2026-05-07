import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/history_controller.dart';
import 'package:masquerade/utils/history_recorder.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('HistoryRecorder', () {
    test('recordPaste adds immediately', () {
      fakeAsync((FakeAsync async) {
        final HistoryController controller = HistoryController();
        final HistoryRecorder recorder = HistoryRecorder(
          controller: controller,
          utilityId: 'base64',
        );
        recorder.recordPaste('a', 'A');
        async.flushMicrotasks();
        expect(controller.entries.length, 1);
        expect(controller.entries.first.input, 'a');
        expect(controller.entries.first.output, 'A');
        expect(controller.entries.first.utilityId, 'base64');
        recorder.dispose();
      });
    });

    test('recordTyping adds after 5s idle', () {
      fakeAsync((FakeAsync async) {
        final HistoryController controller = HistoryController();
        final HistoryRecorder recorder = HistoryRecorder(
          controller: controller,
          utilityId: 'base64',
        );
        recorder.recordTyping('a', 'A');
        async.elapse(const Duration(seconds: 4));
        async.flushMicrotasks();
        expect(controller.entries, isEmpty);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(controller.entries.length, 1);
        expect(controller.entries.first.input, 'a');
        recorder.dispose();
      });
    });

    test('recordTyping resets timer on each call; latest pair wins', () {
      fakeAsync((FakeAsync async) {
        final HistoryController controller = HistoryController();
        final HistoryRecorder recorder = HistoryRecorder(
          controller: controller,
          utilityId: 'base64',
        );
        recorder.recordTyping('a', 'A');
        async.elapse(const Duration(seconds: 4));
        recorder.recordTyping('ab', 'AB');
        async.elapse(const Duration(seconds: 4));
        async.flushMicrotasks();
        expect(controller.entries, isEmpty);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(controller.entries.length, 1);
        expect(controller.entries.first.input, 'ab');
        expect(controller.entries.first.output, 'AB');
        recorder.dispose();
      });
    });

    test('paste mid-typing flushes paste only; typing draft dropped', () {
      fakeAsync((FakeAsync async) {
        final HistoryController controller = HistoryController();
        final HistoryRecorder recorder = HistoryRecorder(
          controller: controller,
          utilityId: 'base64',
        );
        recorder.recordTyping('typed', 'T');
        async.elapse(const Duration(seconds: 2));
        recorder.recordPaste('pasted', 'P');
        async.flushMicrotasks();
        expect(controller.entries.length, 1);
        expect(controller.entries.first.input, 'pasted');
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(controller.entries.length, 1);
        recorder.dispose();
      });
    });

    test('dispose drops pending typing entry', () {
      fakeAsync((FakeAsync async) {
        final HistoryController controller = HistoryController();
        final HistoryRecorder recorder = HistoryRecorder(
          controller: controller,
          utilityId: 'base64',
        );
        recorder.recordTyping('a', 'A');
        async.elapse(const Duration(seconds: 2));
        recorder.dispose();
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(controller.entries, isEmpty);
      });
    });

    test('custom typingDelay is honored', () {
      fakeAsync((FakeAsync async) {
        final HistoryController controller = HistoryController();
        final HistoryRecorder recorder = HistoryRecorder(
          controller: controller,
          utilityId: 'base64',
          typingDelay: const Duration(milliseconds: 200),
        );
        recorder.recordTyping('a', 'A');
        async.elapse(const Duration(milliseconds: 199));
        async.flushMicrotasks();
        expect(controller.entries, isEmpty);
        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(controller.entries.length, 1);
        recorder.dispose();
      });
    });
  });
}
