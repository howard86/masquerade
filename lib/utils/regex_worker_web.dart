import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

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
  final Completer<RegexResult> result = Completer<RegexResult>();
  JSString? url;
  _Worker? worker;
  Timer? timeout;
  bool cleaned = false;

  void cleanup() {
    if (cleaned) return;
    cleaned = true;
    timeout?.cancel();
    worker?.terminate();
    if (worker != null) {
      worker.onmessage = null;
      worker.onerror = null;
    }
    if (url != null) _revokeObjectUrl(url);
  }

  void finish(RegexResult value) {
    if (result.isCompleted) return;
    result.complete(value);
    cleanup();
  }

  try {
    final _Blob blob = _Blob(<JSAny?>[_workerSource.toJS].toJS);
    url = _createObjectUrl(blob);
    worker = _Worker(url);
    worker.onmessage = ((_MessageEvent event) {
      try {
        final Map<String, dynamic> response =
            jsonDecode((event.data as JSString).toDart) as Map<String, dynamic>;
        if (response['started'] == true) {
          onStarted?.call();
          timeout = Timer(
            timeLimit,
            () => finish(
              const RegexErr('Matching timed out. Try a simpler pattern.'),
            ),
          );
          return;
        }
        finish(_decodeResponse(response, pattern));
      } on Object {
        finish(const RegexErr('Regular expression matching failed.'));
      }
    }).toJS;
    worker.onerror = ((JSAny? _) {
      finish(const RegexErr('Regular expression matching failed.'));
    }).toJS;
    worker.postMessage(
      jsonEncode(<String, Object>{
        'pattern': pattern,
        'input': input,
        'caseSensitive': caseSensitive,
        'multiLine': multiLine,
        'dotAll': dotAll,
        'unicode': unicode,
        'maxCaptureGroups': RegexTester.maxCaptureGroups,
        'maxMatches': RegexTester.maxMatches,
      }).toJS,
    );
  } on Object {
    cleanup();
    return const RegexErr('Regular expression matching is unavailable.');
  }
  return result.future;
}

/// A long-lived regex Worker for one caller (e.g. one Regex tool body).
///
/// Runs reuse a single Worker instead of creating a Blob URL + Worker per
/// run. Starting a run while another is still matching terminates the busy
/// Worker — the superseded run completes with [RegexWorkerSession.superseded]
/// — so a stale catastrophic pattern never keeps burning CPU. A run that
/// outlives its `timeLimit` terminates the Worker too; the next run
/// recreates it.
class RegexWorkerSession {
  static const RegexErr superseded = RegexErr('Superseded by a newer run.');

  _Worker? _worker;
  JSString? _url;
  _PendingRun? _pending;
  int _nextId = 0;
  int _generation = 0;
  bool _disposed = false;

  /// Workers currently alive for this session (0 or 1).
  int get liveWorkers => _worker == null ? 0 : 1;

  Future<RegexResult> run({
    required String pattern,
    required String input,
    required bool caseSensitive,
    required bool multiLine,
    required bool dotAll,
    required bool unicode,
    required Duration timeLimit,
    void Function()? onStarted,
  }) {
    if (_disposed) return Future<RegexResult>.value(superseded);
    _supersede();
    final _PendingRun run = _PendingRun(
      ++_nextId,
      pattern,
      timeLimit,
      onStarted,
    );
    _pending = run;
    try {
      final _Worker worker = _worker ?? _spawn();
      run.sent = true;
      worker.postMessage(
        jsonEncode(<String, Object>{
          'id': run.id,
          'pattern': pattern,
          'input': input,
          'caseSensitive': caseSensitive,
          'multiLine': multiLine,
          'dotAll': dotAll,
          'unicode': unicode,
          'maxCaptureGroups': RegexTester.maxCaptureGroups,
          'maxMatches': RegexTester.maxMatches,
        }).toJS,
      );
    } on Object {
      _teardown();
      _finish(
        run,
        const RegexErr('Regular expression matching is unavailable.'),
      );
    }
    return run.result.future;
  }

  /// Terminates the Worker and completes any in-flight run as [superseded].
  void dispose() {
    _disposed = true;
    _supersede();
    _teardown();
  }

  void _supersede() {
    final _PendingRun? previous = _pending;
    if (previous == null) return;
    _pending = null;
    // Already posted: the Worker is busy with a result nobody wants.
    if (previous.sent) _teardown();
    _finish(previous, superseded);
  }

  _Worker _spawn() {
    final int generation = ++_generation;
    final JSString url = _createObjectUrl(
      _Blob(<JSAny?>[_workerSource.toJS].toJS),
    );
    _url = url;
    final _Worker worker = _Worker(url);
    _worker = worker;
    worker.onmessage = ((_MessageEvent event) {
      if (generation != _generation) return;
      final _PendingRun? run = _pending;
      if (run == null) return;
      final Map<String, dynamic> response;
      try {
        response =
            jsonDecode((event.data as JSString).toDart) as Map<String, dynamic>;
      } on Object {
        _finish(run, const RegexErr('Regular expression matching failed.'));
        return;
      }
      if (response['id'] != run.id) return;
      if (response['started'] == true) {
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
      RegexResult result;
      try {
        result = _decodeResponse(response, run.pattern);
      } on Object {
        result = const RegexErr('Regular expression matching failed.');
      }
      _finish(run, result);
    }).toJS;
    worker.onerror = ((JSAny? _) {
      if (generation != _generation) return;
      final _PendingRun? run = _pending;
      _teardown();
      if (run != null) {
        _finish(run, const RegexErr('Regular expression matching failed.'));
      }
    }).toJS;
    return worker;
  }

  void _teardown() {
    _generation++;
    final _Worker? worker = _worker;
    if (worker != null) {
      worker.terminate();
      worker.onmessage = null;
      worker.onerror = null;
    }
    _worker = null;
    final JSString? url = _url;
    if (url != null) _revokeObjectUrl(url);
    _url = null;
  }

  void _finish(_PendingRun run, RegexResult value) {
    if (identical(_pending, run)) _pending = null;
    run.timeout?.cancel();
    if (!run.result.isCompleted) run.result.complete(value);
  }
}

class _PendingRun {
  _PendingRun(this.id, this.pattern, this.timeLimit, this.onStarted);

  final int id;
  final String pattern;
  final Duration timeLimit;
  final void Function()? onStarted;
  final Completer<RegexResult> result = Completer<RegexResult>();
  bool sent = false;
  Timer? timeout;
}

/// Decodes a Worker's final (non-`started`) response for [pattern].
RegexResult _decodeResponse(Map<String, dynamic> response, String pattern) {
  if (response['error'] case final String message) {
    return RegexErr(
      response['bounded'] == true
          ? message
          : RegexTester.formatCompileError(message, pattern),
    );
  }
  final List<dynamic> encodedMatches = response['matches']! as List<dynamic>;
  return RegexOk(
    matches: List<RegexMatchInfo>.unmodifiable(
      encodedMatches.map((dynamic encoded) {
        final Map<String, dynamic> match = encoded as Map<String, dynamic>;
        return RegexMatchInfo(
          start: match['start']! as int,
          end: match['end']! as int,
          text: match['text']! as String,
          groups: List<String?>.unmodifiable(
            (match['groups']! as List<dynamic>).cast<String?>(),
          ),
          named: Map<String, String?>.unmodifiable(
            (match['named']! as Map<String, dynamic>).cast<String, String?>(),
          ),
        );
      }),
    ),
    truncated: response['truncated']! as bool,
  );
}

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny?> parts);
}

@JS('Worker')
extension type _Worker._(JSObject _) implements JSObject {
  external factory _Worker(JSString url);

  external JSFunction? onmessage;
  external JSFunction? onerror;
  external void postMessage(JSAny? message);
  external void terminate();
}

extension type _MessageEvent._(JSObject _) implements JSObject {
  external JSAny? get data;
}

@JS('URL.createObjectURL')
external JSString _createObjectUrl(_Blob blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(JSString url);

const String _workerSource = r'''
self.onmessage = (event) => {
  const request = JSON.parse(event.data);
  self.postMessage(JSON.stringify({id: request.id, started: true}));
  try {
    let flags = 'g';
    if (!request.caseSensitive) flags += 'i';
    if (request.multiLine) flags += 'm';
    if (request.dotAll) flags += 's';
    if (request.unicode) flags += 'u';
    const expression = new RegExp(request.pattern, flags);
    const probe = new RegExp('(?:)|(?:' + request.pattern + ')', flags.replace('g', ''));
    const captureGroups = probe.exec('').length - 1;
    if (captureGroups > request.maxCaptureGroups) {
      self.postMessage(JSON.stringify({
        id: request.id,
        error: 'Pattern is limited to 100 capture groups.',
        bounded: true,
      }));
      return;
    }
    const matches = [];
    let truncated = false;
    for (const match of request.input.matchAll(expression)) {
      if (matches.length === request.maxMatches) {
        truncated = true;
        break;
      }
      const named = {};
      if (match.groups) {
        for (const name of Object.keys(match.groups)) {
          named[name] = match.groups[name] ?? null;
        }
      }
      matches.push({
        start: match.index,
        end: match.index + match[0].length,
        text: match[0],
        groups: Array.from(match).slice(1).map((value) => value ?? null),
        named,
      });
    }
    self.postMessage(JSON.stringify({id: request.id, matches, truncated}));
  } catch (error) {
    self.postMessage(JSON.stringify({id: request.id, error: String(error?.message ?? '')}));
  }
};
''';
