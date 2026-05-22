import 'package:flutter/foundation.dart';

/// The closed set of value kinds a [LinkGroup] can be keyed on, shared with the
/// drag pipeline's content-type hints. A card can join a group only if its tool
/// body can project/parse the group's [ContentType].
enum ContentType { text, bytes, number, epoch, json, color, lines }

/// A set of cards sharing one canonical value — the unit a live link operates
/// on (see docs/adr/0001). The group owns the single source of truth
/// ([canonical]); each member tool body projects it to its own display and
/// parses local edits back into it. Because there is exactly one source,
/// update cycles are impossible: an emit that doesn't change [canonical] is a
/// no-op, so re-projection always terminates.
class LinkGroup {
  LinkGroup({required this.id, required this.type, String canonical = ''})
    : canonical = ValueNotifier<String>(canonical);

  final int id;
  final ContentType type;

  /// The canonical value. Members listen to this and re-project on change.
  final ValueNotifier<String> canonical;

  /// Card ids in this group.
  final Set<int> members = <int>{};
}

/// The per-card view of its [LinkGroup], handed to a tool body via the builder.
/// The body listens to [inbound] (the current canonical value) to refresh its
/// display, and calls [emit] with the canonical value it derives from its own
/// state when the user edits it. Null when the card isn't linked.
class LinkChannel {
  const LinkChannel({
    required this.canonicalType,
    required this.inbound,
    required void Function(String canonical) onEmit,
  }) : _onEmit = onEmit;

  final ContentType canonicalType;
  final ValueListenable<String> inbound;
  final void Function(String canonical) _onEmit;

  /// Pushes a canonical value derived from this body's current state into the
  /// group. A value equal to the current canonical is ignored by the group.
  void emit(String canonical) => _onEmit(canonical);
}
