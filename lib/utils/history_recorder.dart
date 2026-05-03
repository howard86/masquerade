import 'dart:async';

import '../state/history_controller.dart';

/// Records history entries with paste-vs-typing semantics.
///
/// Paste-source events fire immediately. Typing-source events are coalesced
/// behind an idle timer (default 5s) that resets on every keystroke; only the
/// most recent `(input, output)` pair survives and is recorded once the user
/// stops typing. A paste mid-typing replaces the pending draft — the typing
/// draft is dropped, not added separately. `dispose` cancels the pending
/// timer and drops the draft (collapse should not retroactively log).
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
  }
}
