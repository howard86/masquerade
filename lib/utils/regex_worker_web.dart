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
        if (response['error'] case final String message) {
          finish(
            RegexErr(
              response['bounded'] == true
                  ? message
                  : RegexTester.formatCompileError(message, pattern),
            ),
          );
          return;
        }
        final List<dynamic> encodedMatches =
            response['matches']! as List<dynamic>;
        finish(
          RegexOk(
            matches: List<RegexMatchInfo>.unmodifiable(
              encodedMatches.map((dynamic encoded) {
                final Map<String, dynamic> match =
                    encoded as Map<String, dynamic>;
                return RegexMatchInfo(
                  start: match['start']! as int,
                  end: match['end']! as int,
                  text: match['text']! as String,
                  groups: List<String?>.unmodifiable(
                    (match['groups']! as List<dynamic>).cast<String?>(),
                  ),
                  named: Map<String, String?>.unmodifiable(
                    (match['named']! as Map<String, dynamic>)
                        .cast<String, String?>(),
                  ),
                );
              }),
            ),
            truncated: response['truncated']! as bool,
          ),
        );
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
  self.postMessage(JSON.stringify({started: true}));
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
    self.postMessage(JSON.stringify({matches, truncated}));
  } catch (error) {
    self.postMessage(JSON.stringify({error: String(error?.message ?? '')}));
  }
};
''';
