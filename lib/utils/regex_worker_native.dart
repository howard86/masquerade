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

/// A long-lived regex worker for one caller (e.g. one Regex tool body).
///
/// Runs reuse a single isolate instead of spawning one per run. Starting a
/// run while another is still matching kills the busy isolate — the
/// superseded run completes with [RegexWorkerSession.superseded] — so a stale
/// catastrophic pattern never keeps burning CPU. A run that outlives its
/// `timeLimit` kills the isolate too; the next run respawns it.
class RegexWorkerSession {
  static const RegexErr superseded = RegexErr('Superseded by a newer run.');

  Isolate? _isolate;
  ReceivePort? _port;
  Future<SendPort>? _ready;
  _PendingRun? _pending;
  int _nextId = 0;
  bool _disposed = false;

  /// Isolates currently alive for this session (0 or 1).
  int get liveWorkers => _port == null ? 0 : 1;

  Future<RegexResult> run({
    required String pattern,
    required String input,
    required bool caseSensitive,
    required bool multiLine,
    required bool dotAll,
    required bool unicode,
    required Duration timeLimit,
    void Function()? onStarted,
  }) async {
    if (_disposed) return superseded;
    _supersede();
    final _PendingRun run = _PendingRun(++_nextId, timeLimit, onStarted);
    _pending = run;
    try {
      final SendPort worker = await (_ready ??= _spawn());
      // Superseded while the isolate was spawning: nothing to send.
      if (identical(_pending, run)) {
        run.sent = true;
        worker.send(<Object?>[
          run.id,
          pattern,
          input,
          caseSensitive,
          multiLine,
          dotAll,
          unicode,
        ]);
      }
    } on Object {
      if (identical(_pending, run)) _teardown();
      _finish(
        run,
        const RegexErr('Isolated regular expression matching is unavailable.'),
      );
    }
    return run.result.future;
  }

  /// Kills the isolate and completes any in-flight run as [superseded].
  void dispose() {
    _disposed = true;
    _supersede();
    _teardown();
  }

  void _supersede() {
    final _PendingRun? previous = _pending;
    if (previous == null) return;
    _pending = null;
    // Already handed to the isolate: it's busy with a result nobody wants.
    if (previous.sent) _teardown();
    _finish(previous, superseded);
  }

  Future<SendPort> _spawn() async {
    final ReceivePort port = ReceivePort();
    final Completer<SendPort> ready = Completer<SendPort>();
    _port = port;
    port.listen((Object? message) {
      if (!identical(_port, port)) return;
      if (message is SendPort) {
        if (!ready.isCompleted) ready.complete(message);
        return;
      }
      if (message == null) {
        // onExit: the isolate died underneath us.
        final _PendingRun? run = _pending;
        _teardown();
        if (!ready.isCompleted) {
          ready.completeError(StateError('Regex isolate exited.'));
        }
        if (run != null && run.sent) {
          _finish(run, const RegexErr('Regular expression matching failed.'));
        }
        return;
      }
      final List<Object?> reply = message as List<Object?>;
      final _PendingRun? run = _pending;
      if (run == null || reply[0] != run.id) return;
      if (reply[1] == _started) {
        run.onStarted?.call();
        run.timeout = Timer(run.timeLimit, () {
          if (!identical(_pending, run)) return;
          _teardown();
          _finish(
            run,
            const RegexErr('Matching timed out. Try a simpler pattern.'),
          );
        });
        return;
      }
      _finish(run, reply[1]! as RegexResult);
    });
    try {
      final Isolate isolate = await Isolate.spawn<SendPort>(
        _serveRegex,
        port.sendPort,
        onExit: port.sendPort,
      );
      if (!identical(_port, port)) {
        isolate.kill(priority: Isolate.immediate);
        throw StateError('Regex session was torn down.');
      }
      _isolate = isolate;
    } on Object {
      if (identical(_port, port)) _teardown();
      rethrow;
    }
    return ready.future;
  }

  void _teardown() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _port?.close();
    _port = null;
    _ready = null;
  }

  void _finish(_PendingRun run, RegexResult value) {
    if (identical(_pending, run)) _pending = null;
    run.timeout?.cancel();
    if (!run.result.isCompleted) run.result.complete(value);
  }
}

class _PendingRun {
  _PendingRun(this.id, this.timeLimit, this.onStarted);

  final int id;
  final Duration timeLimit;
  final void Function()? onStarted;
  final Completer<RegexResult> result = Completer<RegexResult>();
  bool sent = false;
  Timer? timeout;
}

void _serveRegex(SendPort output) {
  final ReceivePort requests = ReceivePort();
  output.send(requests.sendPort);
  requests.listen((Object? message) {
    final List<Object?> values = message! as List<Object?>;
    final Object? id = values[0];
    output.send(<Object?>[id, _started]);
    output.send(<Object?>[
      id,
      RegexTester.run(
        pattern: values[1] as String,
        input: values[2] as String,
        caseSensitive: values[3] as bool,
        multiLine: values[4] as bool,
        dotAll: values[5] as bool,
        unicode: values[6] as bool,
      ),
    ]);
  });
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
