import 'package:flutter/cupertino.dart';

import '../theme/mb_metrics.dart';
import '../theme/mb_theme.dart';
import '../theme/mb_typography.dart';
import '../utility_catalog.dart';
import '../widgets/mb/mb_search_bar.dart';
import '../widgets/mb/mb_utility_tile.dart';

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
    Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: u.builder, title: u.name));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mb.colors;
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
                MBSpacing.lg,
                MBSpacing.md,
                MBSpacing.lg,
                MBSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Search',
                    style: MBTextStyles.largeTitle.copyWith(color: c.textPri),
                  ),
                  const SizedBox(height: MBSpacing.md),
                  MBSearchBar(
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
                  MBSpacing.lg,
                  0,
                  MBSpacing.lg,
                  120,
                ),
                itemCount: results.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: MBSpacing.sm),
                itemBuilder: (BuildContext context, int i) {
                  final UtilityDescriptor u = results[i];
                  return MBUtilityTile(
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
