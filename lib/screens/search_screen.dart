import 'package:flutter/cupertino.dart';

import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../theme/mq_typography.dart';
import '../utility_catalog.dart';
import '../widgets/mq/mq_search_bar.dart';
import '../widgets/mq/mq_utility_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<UtilityDescriptor> _results() {
    if (_query.trim().isEmpty) return UtilityCatalog.all;
    final String q = _query.trim().toLowerCase();
    return UtilityCatalog.all.where((UtilityDescriptor u) {
      if (u.name.toLowerCase().contains(q)) return true;
      if (u.id.toLowerCase().contains(q)) return true;
      return u.synonyms.any((String s) => s.contains(q));
    }).toList();
  }

  void _open(BuildContext context, UtilityDescriptor u) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (BuildContext ctx) => u.builder(ctx),
        title: u.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    final List<UtilityDescriptor> results = _results();
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MqSpacing.lg,
                MqSpacing.md,
                MqSpacing.lg,
                MqSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Search',
                    style: MqTextStyles.largeTitle.copyWith(color: c.textPri),
                  ),
                  const SizedBox(height: MqSpacing.md),
                  MqSearchBar(
                    controller: _controller,
                    autofocus: true,
                    placeholder:
                        'Search utilities (try "epoch", "hex", "color")',
                    onChanged: (String v) => setState(() => _query = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  MqSpacing.lg,
                  0,
                  MqSpacing.lg,
                  120,
                ),
                itemCount: results.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: MqSpacing.sm),
                itemBuilder: (BuildContext context, int i) {
                  final UtilityDescriptor u = results[i];
                  return MqUtilityTile(
                    name: u.name,
                    icon: u.icon,
                    tint: u.tint,
                    onTap: () => _open(context, u),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
