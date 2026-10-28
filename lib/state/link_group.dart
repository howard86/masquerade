import 'package:flutter/foundation.dart';

import '../models/content_type.dart';

export '../models/content_type.dart';

/// A set of cards sharing one canonical value — the unit a live link operates
/// on (see docs/adr/0001). The group owns the single source of truth
/// ([canonical]); each member tool body projects it to its own display and
/// parses local edits back into it. Because there is exactly one source,
/// update cycles are impossible: an emit that doesn't change [canonical] is a
/// no-op, so re-projection always terminates.
class LinkGroup {
  LinkGroup({
    required this.id,
    required this.type,
    String canonical = '',
    this.seedOwnerCardId,
  }) : canonical = ValueNotifier<String>(canonical);

  final int id;
  final ContentType type;

  /// The canonical value. Members listen to this and re-project on change.
  final ValueNotifier<String> canonical;

  /// Card ids in this group.
  final Set<int> members = <int>{};

  /// The card whose current value should seed a newly-created group when its
  /// body attaches. Null means the canonical value is already authoritative.
  int? seedOwnerCardId;
}

/// The per-card view of its [LinkGroup], handed to a tool body via the builder.
/// The body listens to [inbound] (the current canonical value) to refresh its
/// display, and calls [emit] with the canonical value it derives from its own
/// state when the user edits it. Null when the card isn't linked.
class LinkChannel {
  const LinkChannel({
    required this.canonicalType,
    required this.inbound,
    bool seedOnAttach = true,
    bool Function()? isSeedOwner,
    void Function()? onSeedConsumed,
    required void Function(String canonical) onEmit,
  }) : _seedOnAttach = seedOnAttach,
       _isSeedOwner = isSeedOwner,
       _onSeedConsumed = onSeedConsumed,
       _onEmit = onEmit;

  final ContentType canonicalType;
  final ValueListenable<String> inbound;

  /// Whether this card is the selected source for a brand-new group's first
  /// attach handshake. Controllers may provide a live check so cached channel
  /// wrappers observe when the one-shot seed authority has been consumed.
  final bool _seedOnAttach;
  final bool Function()? _isSeedOwner;
  final void Function()? _onSeedConsumed;
  final void Function(String canonical) _onEmit;

  bool get seedOnAttach => _isSeedOwner?.call() ?? _seedOnAttach;

  /// Consumes the source-only initialization authority after the first attach
  /// handshake, including when the source's canonical is empty.
  void consumeSeedOwnership() => _onSeedConsumed?.call();

  /// Pushes a canonical value derived from this body's current state into the
  /// group. A value equal to the current canonical is ignored by the group.
  void emit(String canonical) => _onEmit(canonical);
}
