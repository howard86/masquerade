import 'package:flutter/widgets.dart';

import '../../state/link_group.dart';

/// The payload of a pipe drag (cell → card / cell → empty canvas). Carries the
/// dragged value, its canonical [ContentType] hint (shared with the link
/// engine, see docs/adr/0001), and the id of the card it came from so a drop
/// target can refuse to link a card to itself.
@immutable
class PipePayload {
  const PipePayload({
    required this.type,
    required this.value,
    required this.sourceCardId,
  });

  final ContentType type;
  final String value;
  final int sourceCardId;
}

/// Marks the subtree of a single canvas card as "pipe mode": output cells query
/// this via [maybeOf] both to learn their source card id and to know that a
/// drag pipe is available at all. Absent on mobile/Home, so cells stay inert.
class PipeScope extends InheritedWidget {
  const PipeScope({super.key, required this.cardId, required super.child});

  /// The id of the card this scope wraps.
  final int cardId;

  static PipeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PipeScope>();

  @override
  bool updateShouldNotify(PipeScope old) => cardId != old.cardId;
}
