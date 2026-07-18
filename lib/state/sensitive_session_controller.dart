import 'package:flutter/widgets.dart';

import 'canvas_controller.dart';
import 'history_controller.dart';
import 'work_session_controller.dart';

/// Clears every current input by resetting the shell after persisted state is
/// safe, so disposed tool controllers cannot repopulate a restored session.
class SensitiveSessionController extends ChangeNotifier {
  SensitiveSessionController(
    this._history, {
    WorkSessionController? workSession,
  }) : _workSession = workSession;

  final HistoryController _history;
  final WorkSessionController? _workSession;
  int _revision = 0;

  int get revision => _revision;

  Future<void> clear() async {
    _workSession?.clear();
    await _history.clear();
    await CanvasController.clearPersistedSensitiveSession();
    _revision++;
    notifyListeners();
  }
}

class SensitiveSessionScope
    extends InheritedNotifier<SensitiveSessionController> {
  const SensitiveSessionScope({
    super.key,
    required SensitiveSessionController controller,
    required super.child,
  }) : super(notifier: controller);

  static SensitiveSessionController of(BuildContext context) {
    final SensitiveSessionScope? scope = context
        .dependOnInheritedWidgetOfExactType<SensitiveSessionScope>();
    assert(scope != null, 'SensitiveSessionScope not found.');
    return scope!.notifier!;
  }
}
