import 'dart:async';
import 'dart:isolate';

import 'regex_parser.dart';

Future<RegexResult> runRegexWorker({
  required String pattern,
  required String input,
  required bool caseSensitive,
  required bool multiLine,
  required bool dotAll,
  required bool unicode,
  required Duration timeLimit,
  void Function()? onStarted,
}) async {
  final ReceivePort results = ReceivePort();
  final Completer<RegexResult> result = Completer<RegexResult>();
  Isolate? worker;
  Timer? timeout;
  late final StreamSubscription<Object?> messages;

  void finish(RegexResult value) {
    if (result.isCompleted) return;
    result.complete(value);
    timeout?.cancel();
    worker?.kill(priority: Isolate.immediate);
    messages.cancel();
    results.close();
  }

  messages = results.listen((Object? message) {
    if (message == _started) {
      onStarted?.call();
      timeout = Timer(
        timeLimit,
        () => finish(
          const RegexErr('Matching timed out. Try a simpler pattern.'),
        ),
      );
      return;
    }
    finish(message! as RegexResult);
  });
  try {
    worker = await Isolate.spawn<List<Object?>>(_runRegex, <Object?>[
      results.sendPort,
      pattern,
      input,
      caseSensitive,
      multiLine,
      dotAll,
      unicode,
    ]);
    return await result.future;
  } on Object {
    finish(
      const RegexErr('Isolated regular expression matching is unavailable.'),
    );
    return result.future;
  }
}

void _runRegex(List<Object?> values) {
  final SendPort output = values[0] as SendPort;
  output.send(_started);
  output.send(
    RegexTester.run(
      pattern: values[1] as String,
      input: values[2] as String,
      caseSensitive: values[3] as bool,
      multiLine: values[4] as bool,
      dotAll: values[5] as bool,
      unicode: values[6] as bool,
    ),
  );
}

const String _started = 'started';
