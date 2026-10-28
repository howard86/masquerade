import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/link_group.dart';
import 'package:masquerade/widgets/tool_bodies/linkable_body.dart';

/// A bare linkable body: its canonical is [_value], and every inbound apply is
/// logged so a test can count re-projections.
class _Peer extends StatefulWidget {
  const _Peer({
    required this.link,
    required this.applied,
    this.initialValue = '',
  });

  final LinkChannel? link;
  final List<String> applied;
  final String initialValue;

  @override
  State<_Peer> createState() => _PeerState();
}

class _PeerState extends State<_Peer> with LinkableToolBody<_Peer> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  LinkChannel? get linkChannel => widget.link;

  @override
  String currentCanonical() => _value;

  @override
  void applyInbound(String canonical) {
    widget.applied.add(canonical);
    setState(() => _value = canonical);
  }

  @override
  Widget build(BuildContext context) =>
      Text(_value, textDirection: TextDirection.ltr);
}

void main() {
  testWidgets('inbound values apply on a later task, latest value wins', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<String> inbound = ValueNotifier<String>('');
    final List<String> applied = <String>[];
    await tester.pumpWidget(
      _Peer(
        link: LinkChannel(
          canonicalType: ContentType.text,
          inbound: inbound,
          onEmit: (String v) => inbound.value = v,
        ),
        applied: applied,
      ),
    );
    await tester.pump(Duration.zero); // attach handshake

    inbound.value = 'one';
    inbound.value = 'two';
    inbound.value = 'three';
    // Nothing runs inside the emitter's call stack or its frame.
    expect(applied, isEmpty);
    await tester.pump();
    expect(applied, isEmpty);

    await tester.pump(Duration.zero);
    expect(applied, <String>['three']);
    expect(find.text('three'), findsOneWidget);
  });

  testWidgets('a pending inbound apply is dropped on dispose', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<String> inbound = ValueNotifier<String>('');
    final List<String> applied = <String>[];
    await tester.pumpWidget(
      _Peer(
        link: LinkChannel(
          canonicalType: ContentType.text,
          inbound: inbound,
          onEmit: (String v) => inbound.value = v,
        ),
        applied: applied,
      ),
    );
    await tester.pump(Duration.zero);

    inbound.value = 'late';
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    expect(applied, isEmpty);
  });

  testWidgets('a restored canonical value wins over stale card seeds', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<String> inbound = ValueNotifier<String>(
      'persisted canonical',
    );
    final List<String> applied = <String>[];
    int emits = 0;

    await tester.pumpWidget(
      _Peer(
        link: LinkChannel(
          canonicalType: ContentType.text,
          inbound: inbound,
          seedOnAttach: false,
          onEmit: (String _) => emits++,
        ),
        initialValue: 'stale card seed',
        applied: applied,
      ),
    );
    await tester.pump(Duration.zero);

    expect(find.text('persisted canonical'), findsOneWidget);
    expect(applied, <String>['persisted canonical']);
    expect(emits, 0);
  });

  testWidgets('switching directly between groups pulls the new canonical', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<String> first = ValueNotifier<String>('first group');
    final ValueNotifier<String> second = ValueNotifier<String>('second group');
    final List<String> applied = <String>[];
    LinkChannel channel(ValueNotifier<String> inbound) => LinkChannel(
      canonicalType: ContentType.text,
      inbound: inbound,
      seedOnAttach: false,
      onEmit: (String _) {},
    );

    await tester.pumpWidget(_Peer(link: channel(first), applied: applied));
    await tester.pump(Duration.zero);
    expect(find.text('first group'), findsOneWidget);

    await tester.pumpWidget(_Peer(link: channel(second), applied: applied));
    await tester.pump(Duration.zero);

    expect(find.text('second group'), findsOneWidget);
    expect(applied, <String>['first group', 'second group']);
  });

  testWidgets('a queued value from the old group is canceled on a switch', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<String> first = ValueNotifier<String>('');
    final ValueNotifier<String> second = ValueNotifier<String>('current group');
    final List<String> applied = <String>[];
    LinkChannel channel(ValueNotifier<String> inbound) => LinkChannel(
      canonicalType: ContentType.text,
      inbound: inbound,
      seedOnAttach: false,
      onEmit: (String _) {},
    );

    await tester.pumpWidget(_Peer(link: channel(first), applied: applied));
    await tester.pump(Duration.zero);
    first.value = 'stale old group';
    await tester.pumpWidget(_Peer(link: channel(second), applied: applied));
    await tester.pump(Duration.zero);

    expect(find.text('current group'), findsOneWidget);
    expect(applied, isNot(contains('stale old group')));
  });

  testWidgets('unlinking removes the old group listener', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<String> inbound = ValueNotifier<String>('linked value');
    final List<String> applied = <String>[];
    LinkChannel channel() => LinkChannel(
      canonicalType: ContentType.text,
      inbound: inbound,
      seedOnAttach: false,
      onEmit: (String _) {},
    );

    await tester.pumpWidget(_Peer(link: channel(), applied: applied));
    await tester.pump(Duration.zero);
    await tester.pumpWidget(_Peer(link: null, applied: applied));

    inbound.value = 'stale unlinked value';
    await tester.pump(Duration.zero);

    expect(find.text('linked value'), findsOneWidget);
    expect(applied, <String>['linked value']);
  });
}
