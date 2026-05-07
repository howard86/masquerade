import 'dart:async';

import '../state/history_controller.dart';

/// Records history entries with paste-vs-typing semantics.
///
/// Paste-source events fire immediately. Typing-source events coalesce
/// behind an idle timer (default 5s); only the most recent `(input, output)`
/// pair survives and is recorded once the user stops typing. A paste
/// mid-typing replaces the pending draft. `dispose` drops the draft —
/// collapse should not retroactively log.
class HistoryRecorder {
  HistoryRecorder({
    required this.controller,
    required this.utilityId,
    Duration typingDelay = const Duration(seconds: 5),
  }) : _typingDelay = typingDelay;

  final HistoryController controller;
  final String utilityId;
  final Duration _typingDelay;

  Timer? _timer;
  String? _pendingInput;
  String? _pendingOutput;
  bool _nextIsPaste = false;

  /// Marks the next [record] call as paste-source. Idempotent. The flag is
  /// consumed by the next `record`; subsequent `record` calls fall back to
  /// the typing-debounce.
  void markPaste() {
    _nextIsPaste = true;
  }

  /// Records an entry. Routes to [recordPaste] when [markPaste] was called
  /// since the last record, otherwise to [recordTyping].
  void record(String input, String output) {
    if (_nextIsPaste) {
      _nextIsPaste = false;
      recordPaste(input, output);
    } else {
      recordTyping(input, output);
    }
  }

  void recordPaste(String input, String output) {
    _timer?.cancel();
    _timer = null;
    _pendingInput = null;
    _pendingOutput = null;
    _add(input, output);
  }

  void recordTyping(String input, String output) {
    _pendingInput = input;
    _pendingOutput = output;
    _timer?.cancel();
    _timer = Timer(_typingDelay, _flush);
  }

  void _flush() {
    final String? i = _pendingInput;
    final String? o = _pendingOutput;
    _timer = null;
    _pendingInput = null;
    _pendingOutput = null;
    if (i == null || o == null) return;
    _add(i, o);
  }

  void _add(String input, String output) {
    controller.add(
      HistoryEntry(
        utilityId: utilityId,
        input: input,
        output: output,
        timestamp: DateTime.now(),
      ),
    );
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pendingInput = null;
    _pendingOutput = null;
    _nextIsPaste = false;
  }
}
