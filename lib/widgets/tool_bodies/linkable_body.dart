import 'package:flutter/widgets.dart';

import '../../state/link_group.dart';

/// Lifecycle glue for a tool body that participates in a desktop canvas Link
/// group (see docs/adr/0001). The body supplies its [LinkChannel] (null when
/// unlinked) plus two projection hooks; this mixin owns the inbound
/// subscription, the deterministic seeding when a link first attaches, and the
/// idempotent emit.
///
/// Two guards make update cycles impossible:
///  * a [LinkGroup] ignores an [LinkChannel.emit] equal to its current
///    canonical, and
///  * [_onInbound] skips when this body's [currentCanonical] already equals the
///    value in flight.
///
/// So a propagation re-projects each peer at most once, then terminates.
///
/// The mixin self-wires through the [State] lifecycle (`initState`,
/// `didUpdateWidget`, `dispose`) via the super-chain — compose it alongside
/// `ToolBodyScaffold` and neither needs a hand-call. The body only implements
/// the three projection hooks and calls [emitToLink] whenever it recomputes its
/// value.
mixin LinkableToolBody<T extends StatefulWidget> on State<T> {
  /// The body's current link channel, or null when its card isn't linked.
  /// Bodies implement this as `widget.link`.
  LinkChannel? get linkChannel;

  /// This body's value expressed as the group's canonical string (e.g. the
  /// plain-text payload). Empty string when the body has nothing yet.
  String currentCanonical();

  /// Re-projects an inbound [canonical] into the body's display. Called only
  /// when it differs from [currentCanonical]; the body must not re-emit here
  /// (the trailing [emitToLink] is a no-op once the projection matches).
  void applyInbound(String canonical);

  LinkChannel? _subscribed;

  @override
  void initState() {
    super.initState();
    _resubscribe();
    _scheduleAttach();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The canvas hands a fresh LinkChannel each rebuild, but its [inbound]
    // notifier is stable per group — compare that, not the wrapper, to avoid
    // re-subscribing on every unrelated canvas change.
    if (linkChannel?.inbound == _subscribed?.inbound) return;
    final bool wasLinked = _subscribed != null;
    _resubscribe();
    if (!wasLinked && linkChannel != null) _scheduleAttach();
  }

  @override
  void dispose() {
    _subscribed?.inbound.removeListener(_onInbound);
    _subscribed = null;
    super.dispose();
  }

  /// Defers the attach handshake to after the frame so the cross-body emit it
  /// triggers can't land a setState mid-reconciliation.
  void _scheduleAttach() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onAttach();
    });
  }

  /// Pushes this body's canonical into the group. A no-op when unlinked or when
  /// the value already matches the group's canonical.
  void emitToLink() => linkChannel?.emit(currentCanonical());

  void _resubscribe() {
    _subscribed?.inbound.removeListener(_onInbound);
    _subscribed = linkChannel;
    _subscribed?.inbound.addListener(_onInbound);
  }

  /// On first attach a body that already holds a value seeds the group; an
  /// empty body instead pulls the existing canonical. So linking a fresh
  /// sibling onto a populated card shows the source's value in the sibling.
  void _onAttach() {
    final LinkChannel? link = linkChannel;
    if (link == null) return;
    if (currentCanonical().isNotEmpty) {
      link.emit(currentCanonical());
    } else {
      _onInbound();
    }
  }

  void _onInbound() {
    final LinkChannel? link = linkChannel;
    if (link == null) return;
    final String incoming = link.inbound.value;
    if (incoming == currentCanonical()) return;
    applyInbound(incoming);
  }
}
