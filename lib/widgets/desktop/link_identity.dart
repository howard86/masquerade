import 'package:flutter/widgets.dart';

import '../../state/link_group.dart';
import '../../theme/mq_colors.dart';

/// The visible identity of one [LinkGroup] on the desktop: a letter (A, B, …)
/// and a tint, shared by the window badge, outline, tether, hub chip, and the
/// Links window so two groups of the same content type stay distinguishable.
typedef LinkIdentity = ({String letter, Color color});

/// Ordered by group id so a group keeps its letter and color while other
/// groups come and go only when an earlier group dissolves.
Map<int, LinkIdentity> linkIdentities(
  Iterable<LinkGroup> groups,
  MqColors colors,
) {
  final List<Color> palette = <Color>[
    colors.warning,
    colors.info,
    colors.success,
    colors.monoKey,
    colors.monoString,
    colors.accent,
  ];
  final List<LinkGroup> ordered = groups.toList()
    ..sort((LinkGroup a, LinkGroup b) => a.id.compareTo(b.id));
  return <int, LinkIdentity>{
    for (int i = 0; i < ordered.length; i++)
      ordered[i].id: (letter: _letter(i), color: palette[i % palette.length]),
  };
}

String _letter(int index) {
  final String base = String.fromCharCode(0x41 + index % 26);
  return index < 26 ? base : '$base${index ~/ 26}';
}

/// Human label for a [ContentType], e.g. `JSON`, `Epoch`.
String contentTypeLabel(ContentType type) => switch (type) {
  ContentType.text => 'Text',
  ContentType.bytes => 'Bytes',
  ContentType.number => 'Number',
  ContentType.epoch => 'Epoch',
  ContentType.json => 'JSON',
  ContentType.color => 'Color',
  ContentType.lines => 'Lines',
};
