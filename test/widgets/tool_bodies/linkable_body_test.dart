import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/state/link_group.dart';
import 'package:masquerade/widgets/tool_bodies/linkable_body.dart';

/// A bare linkable body: its canonical is [_value], and every inbound apply is
/// logged so a test can count re-projections.
class _Peer extends StatefulWidget {
  const _Peer({required this.link, required this.applied});

  final LinkChannel? link;
  final List<String> applied;

  @override
  State<_Peer> createState() => _PeerState();
}

class _PeerState extends State<_Peer> with LinkableToolBody<_Peer> {
  String _value = '';

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
}
