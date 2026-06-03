import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../state/history_controller.dart';
import '../../utils/history_recorder.dart';
import '../mq/tool_action_bar.dart';
import 'seed_source.dart';

/// The widget half of a scaffolded tool body. A [StatefulWidget] whose [State]
/// mixes in [ToolBodyScaffold] declares `implements ToolBodyWidget` so the
/// scaffold can read the shared-seam inputs without each body re-forwarding
/// them. The fields are already present on every tool widget, so the
/// declaration is satisfied for free.
abstract interface class ToolBodyWidget {
  String? get initialInput;
  SeedSource get seedSource;
  ToolActionBarController? get actionBar;
}

/// Lifecycle plumbing shared by every single-input transform Tool body (see
/// CONTEXT.md "Body scaffold"). Owns the text controller + debounce, seed-on-
/// init, the [HistoryRecorder] and its paste/typing routing, the paste/clear
/// handlers, and the action-bar bind.
///
/// Composes with — but never references — `LinkableToolBody`: mix both in and
/// the [State] super-chain wires each, so a body never hand-calls a lifecycle
/// hook. The link surface stays out of non-linkable tools.
///
/// A body supplies [utilityId], [parse] (only ever called on non-blank input),
/// and [reset] (the output-clearing it does on blank input *and* Clear). It may
/// override [debounceDuration], [onSeed], [actionBarCenter], and [isBlank].
mixin ToolBodyScaffold<T extends StatefulWidget> on State<T> {
  // ─── Body contract ──────────────────────────────────────────────────────
  /// The catalog id this tool records history under.
  String get utilityId;

  /// Transforms [input] — guaranteed non-blank — into the body's output. The
  /// body calls [setState], [recordOutput], and (when linkable) `emitToLink`
  /// itself; the scaffold only guarantees when this runs.
  void parse(String input);

  /// Clears the body's tool-specific output state. Called on blank input and on
  /// Clear; a linkable body emits its now-empty canonical here too.
  void reset();

  /// Debounce between a keystroke and [parse]. Override per tool.
  Duration get debounceDuration => const Duration(milliseconds: 150);

  /// Extra per-tool setup when a seed arrives (e.g. Base64 enters Decode mode).
  void onSeed(String seed) {}

  /// Optional state-dependent center action for the detail-route action bar.
  /// Re-read after every [parse], so it can reflect current output.
  Widget? actionBarCenter() => null;

  /// Whether [input] is "nothing to do" → [reset] instead of [parse]. Defaults
  /// to whitespace-only; a body that meaningfully processes leading/trailing
  /// whitespace (e.g. Base64 encode) overrides this to `input.isEmpty`.
  bool isBlank(String input) => input.trim().isEmpty;

  // ─── Provided ───────────────────────────────────────────────────────────
  final TextEditingController controller = TextEditingController();
  Timer? _debounce;
  HistoryRecorder? _recorder;

  ToolBodyWidget get _w => widget as ToolBodyWidget;

  @override
  void initState() {
    super.initState();
    final String? seed = _w.initialInput;
    if (seed != null && seed.isNotEmpty) {
      controller.text = seed;
      onSeed(seed);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runParse();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) bindActionBar();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recorder == null) {
      _recorder = HistoryRecorder(
        controller: HistoryScope.of(context),
        utilityId: utilityId,
      );
      if (_w.seedSource == SeedSource.paste) _recorder!.markPaste();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recorder?.dispose();
    controller.dispose();
    super.dispose();
  }

  // ─── Body-facing helpers ────────────────────────────────────────────────
  /// Wire into `MqInput.onChanged`: debounces, then parses.
  void onInputChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(debounceDuration, _runParse);
  }

  /// Flags the next recorded entry as paste-sourced (immediate, no debounce).
  /// Wire into `MqInput.onPaste`.
  void markPaste() => _recorder?.markPaste();

  /// Records a parse result, honouring paste-vs-typing semantics.
  void recordOutput(String input, String output) =>
      _recorder?.record(input, output);

  /// Programmatically replaces the input and re-parses — the single path for
  /// swaps, keyword inserts, "now", etc. Records as paste by default.
  void setInput(String text, {bool asPaste = true}) {
    _debounce?.cancel();
    controller.text = text;
    if (asPaste) _recorder?.markPaste();
    _runParse();
  }

  /// Re-runs the parse path on the *current* input — for option toggles (mode
  /// switches, format chips) that change the transform without touching the
  /// input text.
  void reparse() => _runParse();

  /// Pastes the clipboard into the input. Bound to the action bar's Paste.
  Future<void> pasteFromClipboard() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (text == null) return;
    setInput(text, asPaste: true);
  }

  /// Clears the input and resets output. Bound to the action bar's Clear.
  void clearInput() {
    _debounce?.cancel();
    controller.clear();
    reset();
    bindActionBar();
  }

  /// (Re)binds the detail-route action bar. Called on init and after parse so a
  /// state-dependent [actionBarCenter] stays current.
  void bindActionBar() {
    _w.actionBar?.bind(
      onPaste: pasteFromClipboard,
      onClear: clearInput,
      center: actionBarCenter(),
    );
  }

  void _runParse() {
    if (!mounted) return;
    final String input = controller.text;
    if (isBlank(input)) {
      reset();
    } else {
      parse(input);
    }
    bindActionBar();
  }
}
