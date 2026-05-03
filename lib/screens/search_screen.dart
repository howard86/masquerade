import 'package:flutter/cupertino.dart';

import '../theme/mq_metrics.dart';
import '../theme/mq_theme.dart';
import '../theme/mq_typography.dart';
import '../utility_catalog.dart';
import '../widgets/mq/mq_icons.dart';
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
    u.push(context);
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
              child: results.isEmpty && _query.trim().isNotEmpty
                  ? _SearchEmptyState(query: _query.trim())
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        MqSpacing.lg,
                        0,
                        MqSpacing.lg,
                        MqLayout.tabBarClearance,
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
                          compact: true,
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

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final c = context.mq.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MqSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(MqIcons.search, size: 36, color: c.textTer),
            const SizedBox(height: MqSpacing.md),
            Text(
              'No matches',
              style: MqTextStyles.title3.copyWith(color: c.textPri),
            ),
            const SizedBox(height: MqSpacing.xs),
            Text(
              'Nothing matches "$query". Try a different keyword or check the synonyms list.',
              style: MqTextStyles.subhead.copyWith(color: c.textSec),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
